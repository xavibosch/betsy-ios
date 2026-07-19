import Foundation
import Combine
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// Central AdMob controller: GDPR consent (UMP) → SDK start → preload + present rewarded and
/// interstitial ads. Single shared instance. Test ad-unit ids in DEBUG, real ids in Release.
///
/// Usage:
///  - `AdsManager.shared.start()` once after the ATT prompt resolves (see _xApp).
///  - `AdsManager.shared.showRewarded { /* grant points */ }` from a user-tapped button.
///  - `AdsManager.shared.maybeShowInterstitial()` at natural breaks (cooldown-gated).
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var rewardedReady = false
    @Published private(set) var interstitialReady = false

    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var started = false

    /// Interstitials show on a fixed ~3-minute cadence (driven by `interstitialTimer`), but
    /// only when the user is NOT mid bet. Views set `suppressInterstitial = true` while a bet
    /// is being built/confirmed; the next tick after they finish shows the ad.
    private var lastInterstitialShown = Date.distantPast
    private let interstitialCooldown: TimeInterval = 180   // 3 minutes
    private var interstitialTimer: Timer?

    /// Active reasons to block the interstitial (e.g. "bet", "arenaCreate", "arenaPick").
    /// Each flow toggles its own reason, so overlapping modals compose without races.
    private var interstitialSuppressors = Set<String>()
    private var interstitialSuppressed: Bool { !interstitialSuppressors.isEmpty }
    func setInterstitialSuppressed(_ suppressed: Bool, reason: String) {
        if suppressed { interstitialSuppressors.insert(reason) }
        else { interstitialSuppressors.remove(reason) }
    }

    // Google's public TEST unit ids in DEBUG (always fill, never risk the account).
    // Replace the Release ids with your real AdMob unit ids before App Store submission.
    #if DEBUG
    private let rewardedUnitID     = "ca-app-pub-3940256099942544/1712485313"
    private let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let rewardedUnitID     = "ca-app-pub-3129215645602773/9708366998"  // Betsy Rewarded
    private let interstitialUnitID = "ca-app-pub-3129215645602773/1857797134"  // Betsy Interstitial
    #endif

    private override init() { super.init() }

    // MARK: Start

    /// Idempotent. Requests UMP consent, starts the SDK once consent allows, then preloads both ads.
    func start() {
        guard !started else { return }
        started = true

        let params = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let vc = Self.rootViewController {
                    ConsentForm.loadAndPresentIfRequired(from: vc) { [weak self] _ in
                        self?.startSDKIfAllowed()
                    }
                } else {
                    self.startSDKIfAllowed()
                }
            }
        }
    }

    private func startSDKIfAllowed() {
        guard ConsentInformation.shared.canRequestAds else { return }
        MobileAds.shared.start { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadRewarded()
                self?.loadInterstitial()
                self?.startInterstitialTimer()
            }
        }
    }

    /// Ticks every 30s; `maybeShowInterstitial` only actually presents when ≥3 min have passed
    /// AND the user isn't mid-bet — so a tick blocked mid-bet retries soon after they finish.
    private func startInterstitialTimer() {
        interstitialTimer?.invalidate()
        // Start the 3-min clock now so the FIRST interstitial lands ~3 min after launch,
        // not ~30s in (which would feel like an app-open ad and risks AdMob policy).
        lastInterstitialShown = Date()
        interstitialTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.maybeShowInterstitial()
        }
    }

    // MARK: Rewarded

    func loadRewarded() {
        RewardedAd.load(with: rewardedUnitID, request: Request()) { [weak self] ad, _ in
            guard let self else { return }
            self.rewarded = ad
            ad?.fullScreenContentDelegate = self
            self.rewardedReady = (ad != nil)
        }
    }

    /// Presents the rewarded ad. `onReward` fires only if the user earns the reward (watched enough).
    /// Grants a fixed in-app amount decided by the caller — independent of the ad's own reward value.
    func showRewarded(onReward: @escaping () -> Void) {
        guard let ad = rewarded, let vc = Self.rootViewController else {
            loadRewarded()   // not ready — warm one up for next tap
            return
        }
        rewardedReady = false
        ad.present(from: vc) { onReward() }
    }

    // MARK: Interstitial

    func loadInterstitial() {
        InterstitialAd.load(with: interstitialUnitID, request: Request()) { [weak self] ad, _ in
            guard let self else { return }
            self.interstitial = ad
            ad?.fullScreenContentDelegate = self
            self.interstitialReady = (ad != nil)
        }
    }

    /// Shows an interstitial only if one is loaded and the cooldown has elapsed. No-op otherwise —
    /// safe to call from any tab change / natural break. Never call mid bet-placement flow.
    func maybeShowInterstitial() {
        guard !interstitialSuppressed,                     // never mid bet/reto flow
              interstitialReady,
              let ad = interstitial,
              let vc = Self.rootViewController,
              Date().timeIntervalSince(lastInterstitialShown) > interstitialCooldown
        else { return }
        lastInterstitialShown = Date()
        interstitialReady = false
        ad.present(from: vc)
    }

    // MARK: Helpers

    private static var rootViewController: UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - FullScreenContentDelegate (reload after each presentation)

extension AdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        reloadAfter(ad)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        reloadAfter(ad)
    }

    private func reloadAfter(_ ad: FullScreenPresentingAd) {
        if ad is RewardedAd {
            rewarded = nil
            rewardedReady = false
            loadRewarded()
        } else if ad is InterstitialAd {
            interstitial = nil
            interstitialReady = false
            loadInterstitial()
        }
    }
}
