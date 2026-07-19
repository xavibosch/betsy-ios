/**
 * Betsy Cloud Functions
 * ─────────────────────
 * Server-side settlement so scores can't be faked client-side.
 *
 * What this does today:
 *   • scheduledArenaSettlement — every 30 min, reads ACTIVE Arena duels from
 *     Firestore, fetches real match scores from The Odds API, resolves the
 *     winner, and atomically adjusts both members' points.
 *
 * What still needs the client migrated first:
 *   • Ticket settlement. Tickets currently live in the device (UserDefaults
 *     `betsyTicketHistoryDataV2`), NOT Firestore. To settle them server-side,
 *     the client must first persist tickets to
 *     `leagues/{code}/members/{uid}/tickets/{ticketId}`.
 *     The settleTicket() helper below is ready for that day.
 *
 * Secrets:
 *   firebase functions:secrets:set ODDS_API_KEY
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions, logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAppCheck } from "firebase-admin/app-check";

initializeApp();
const db = getFirestore();

// maxInstances caps cost/blast-radius; concurrency lets each instance handle
// several simultaneous callable requests (adjustPoints) so a burst of users
// doesn't queue behind cold starts.
setGlobalOptions({ region: "europe-west1", maxInstances: 10, concurrency: 40 });

const ODDS_API_KEY = defineSecret("ODDS_API_KEY");
const ODDS_API_KEY_FALLBACK = defineSecret("ODDS_API_KEY_FALLBACK");
const RAPIDAPI_KEY = defineSecret("RAPIDAPI_KEY");
const FOOTBALLDATA_KEY = defineSecret("FOOTBALLDATA_KEY");
const APISPORTS_KEY = defineSecret("APISPORTS_KEY");

// ─────────────────────────────────────────────────────────────
// apiProxy — the ONLY way the app should reach paid sports APIs.
//
// Why: shipping API keys inside the iOS binary means anyone can extract them
// from the .ipa and drain your quota. This proxy keeps every key server-side
// (as Function secrets), verifies the caller is a genuine app instance via
// App Check, then forwards the request and injects the right key. The app
// never sees a key again.
//
// Contract (all query params in the request are forwarded upstream, minus the
// two control params below):
//   ?__u=odds|rapidlive|footballdata|apisports   which upstream
//   ?__p=/v4/sports/soccer_epl/odds/             the upstream path (URL-encoded)
//   X-Firebase-AppCheck: <token>                 required header
// ─────────────────────────────────────────────────────────────

const UPSTREAMS: Record<string, { host: string; keyMode: "query" | "header"; keyName: string; extraHeaders?: Record<string, string> }> = {
  odds: { host: "api.the-odds-api.com", keyMode: "query", keyName: "apiKey" },
  rapidlive: {
    host: "free-api-live-football-data.p.rapidapi.com",
    keyMode: "header",
    keyName: "x-rapidapi-key",
    extraHeaders: { "x-rapidapi-host": "free-api-live-football-data.p.rapidapi.com" },
  },
  footballdata: { host: "api.football-data.org", keyMode: "header", keyName: "X-Auth-Token" },
  apisports: {
    host: "v3.football.api-sports.io",
    keyMode: "header",
    keyName: "x-apisports-key",
  },
};

export const apiProxy = onRequest(
  {
    secrets: [ODDS_API_KEY, ODDS_API_KEY_FALLBACK, RAPIDAPI_KEY, FOOTBALLDATA_KEY, APISPORTS_KEY],
    // App Check is verified manually below (we need custom header handling), so no
    // consumeAppCheckToken here; keep CORS off — only the native app calls this.
  },
  async (req, res) => {
    // 1) Verify App Check — reject anything that isn't a real instance of the app.
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "App Check token required" });
      return;
    }
    try {
      await getAppCheck().verifyToken(appCheckToken);
    } catch {
      res.status(401).json({ error: "Invalid App Check token" });
      return;
    }

    // 2) Resolve upstream + path.
    const uKey = String(req.query.__u ?? "");
    const upstream = UPSTREAMS[uKey];
    const path = String(req.query.__p ?? "");
    if (!upstream || !path.startsWith("/")) {
      res.status(400).json({ error: "Bad __u/__p" });
      return;
    }

    // 3) Rebuild the upstream query from everything except our control params.
    const params = new URLSearchParams();
    for (const [k, v] of Object.entries(req.query)) {
      if (k === "__u" || k === "__p") continue;
      params.set(k, Array.isArray(v) ? String(v[0]) : String(v));
    }

    // 4) Pick the key. The Odds API drains a primary then a fallback on 401/403.
    const keyCandidates =
      uKey === "odds"
        ? [ODDS_API_KEY.value(), ODDS_API_KEY_FALLBACK.value()].filter(Boolean)
        : [
            uKey === "rapidlive"
              ? RAPIDAPI_KEY.value()
              : uKey === "footballdata"
              ? FOOTBALLDATA_KEY.value()
              : APISPORTS_KEY.value(),
          ].filter(Boolean);

    if (keyCandidates.length === 0) {
      res.status(500).json({ error: "No key configured for upstream" });
      return;
    }

    for (let i = 0; i < keyCandidates.length; i++) {
      const key = keyCandidates[i];
      const headers: Record<string, string> = { ...(upstream.extraHeaders ?? {}) };
      const qp = new URLSearchParams(params);
      if (upstream.keyMode === "query") qp.set(upstream.keyName, key);
      else headers[upstream.keyName] = key;

      const url = `https://${upstream.host}${path}${qp.toString() ? `?${qp.toString()}` : ""}`;
      let upstreamRes: Response;
      try {
        upstreamRes = await fetch(url, { headers });
      } catch (e) {
        logger.warn(`apiProxy fetch failed ${uKey}: ${String(e)}`);
        res.status(502).json({ error: "Upstream fetch failed" });
        return;
      }

      // Odds key exhausted/invalid → try the next key.
      if ((upstreamRes.status === 401 || upstreamRes.status === 403) && i < keyCandidates.length - 1) {
        continue;
      }

      // Pass through the credit-remaining header so the client budget guard still works.
      const remaining = upstreamRes.headers.get("x-requests-remaining");
      if (remaining) res.set("x-requests-remaining", remaining);
      res.status(upstreamRes.status);
      res.set("Content-Type", upstreamRes.headers.get("content-type") ?? "application/json");
      const body = await upstreamRes.text();
      res.send(body);
      return;
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Shared betting logic — MUST mirror the iOS client exactly.
// (canonicalPickCode + winnerCode from SportsModels.swift / BettingRules.swift)
// ─────────────────────────────────────────────────────────────

/** "1" home, "2" away, "X" draw — or null if unparseable. Mirrors canonicalPickCode. */
function canonicalPickCode(label: string): string | null {
  const n = label
    .toLowerCase()
    .replace("ganador ·", "")
    .replace("winner ·", "")
    .trim();
  if (n === "1" || n === "local" || n === "home") return "1";
  if (n === "2" || n === "visitante" || n === "away") return "2";
  if (n === "x" || n === "draw" || n === "empate" || n === "tie") return "X";
  if (n.endsWith("· 1")) return "1";
  if (n.endsWith("· 2")) return "2";
  if (n.endsWith("· x")) return "X";
  return null;
}

/** Result code from final score. Null while not finished. */
function winnerCode(home: number | null, away: number | null): string | null {
  if (home === null || away === null) return null;
  if (home > away) return "1";
  if (away > home) return "2";
  return "X";
}

// ─────────────────────────────────────────────────────────────
// The Odds API — scores
// ─────────────────────────────────────────────────────────────

interface MatchScore {
  eventId: string;
  home: string;
  away: string;
  homeScore: number | null;
  awayScore: number | null;
  completed: boolean;
}

/** Fetch completed scores for a sport key from The Odds API. */
async function fetchScores(sport: string, apiKey: string): Promise<Map<string, MatchScore>> {
  const url = `https://api.the-odds-api.com/v4/sports/${sport}/scores/?apiKey=${apiKey}&daysFrom=3`;
  const res = await fetch(url);
  if (!res.ok) {
    logger.warn(`scores fetch failed for ${sport}: ${res.status}`);
    return new Map();
  }
  const data = (await res.json()) as any[];
  const map = new Map<string, MatchScore>();
  for (const ev of data) {
    const scores: any[] = ev.scores ?? [];
    const homeName = ev.home_team as string;
    const awayName = ev.away_team as string;
    const homeScore = scores.find((s) => s.name === homeName)?.score;
    const awayScore = scores.find((s) => s.name === awayName)?.score;
    map.set(ev.id, {
      eventId: ev.id,
      home: homeName,
      away: awayName,
      homeScore: homeScore != null ? Number(homeScore) : null,
      awayScore: awayScore != null ? Number(awayScore) : null,
      completed: ev.completed === true,
    });
  }
  return map;
}

// ─────────────────────────────────────────────────────────────
// Arena settlement
// ─────────────────────────────────────────────────────────────

interface ArenaSelection {
  matchId: string;
  home: string;
  away: string;
  oddLabel: string;
  oddValue: number;
}

/** How many of a player's picks were correct given the score map. Null if any match unresolved. */
function correctCount(
  selections: ArenaSelection[],
  scores: Map<string, MatchScore>
): number | null {
  let correct = 0;
  for (const sel of selections) {
    const score = scores.get(sel.matchId);
    if (!score || !score.completed) return null; // not all finished yet
    const expected = canonicalPickCode(sel.oddLabel);
    const actual = winnerCode(score.homeScore, score.awayScore);
    if (expected === null || actual === null) return null;
    if (expected === actual) correct += 1;
  }
  return correct;
}

function combinedOdds(sels: ArenaSelection[]): number {
  return sels.reduce((acc, s) => acc * (s.oddValue || 1), 1);
}

/**
 * Resolve every ACTIVE Arena duel whose matches have all finished.
 * Winner gets stake * combinedOdds (their own pick). Draw → both keep nothing extra
 * beyond the standard payout rule. Mirrors LeagueService+Arena resolution.
 */
export const scheduledArenaSettlement = onSchedule(
  { schedule: "every 30 minutes", secrets: [ODDS_API_KEY] },
  async () => {
    const apiKey = ODDS_API_KEY.value();

    // Scale: query ONLY active duels across every league in one collectionGroup
    // read instead of scanning every league doc. Paginated so a large backlog
    // can't blow the function timeout in a single pass.
    const PAGE = 200;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    // Cache scores per sport key for the whole run so we hit The Odds API once
    // per sport, not once per league.
    const scoreCache = new Map<string, Map<string, MatchScore>>();
    async function scoresForSport(key: string): Promise<Map<string, MatchScore>> {
      const hit = scoreCache.get(key);
      if (hit) return hit;
      const m = await fetchScores(key, apiKey);
      scoreCache.set(key, m);
      return m;
    }
    // Per-league settings cache (sportKeys) so we read each league doc at most once.
    const leagueSportKeys = new Map<string, string[]>();
    async function sportKeysFor(leagueRef: FirebaseFirestore.DocumentReference): Promise<string[]> {
      const cached = leagueSportKeys.get(leagueRef.id);
      if (cached) return cached;
      const snap = await leagueRef.get();
      const settings = snap.data()?.settings ?? {};
      const keys: string[] = settings.sportKeys ?? settings.allowedSportKeys ?? [];
      leagueSportKeys.set(leagueRef.id, keys);
      return keys;
    }

    for (;;) {
      let q = db.collectionGroup("arenas")
        .where("status", "==", "active")
        .orderBy("__name__")
        .limit(PAGE);
      if (cursor) q = q.startAfter(cursor);
      const activeSnap = await q.get();
      if (activeSnap.empty) break;

      for (const duelDoc of activeSnap.docs) {
        // parent = arenas collection, parent.parent = the league doc.
        const leagueRef = duelDoc.ref.parent.parent;
        if (!leagueRef) continue;
        const leagueId = leagueRef.id;

        const sportKeys = await sportKeysFor(leagueRef);
        const scoreMap = new Map<string, MatchScore>();
        for (const key of sportKeys) {
          const m = await scoresForSport(key);
          m.forEach((v, k) => scoreMap.set(k, v));
        }
        if (scoreMap.size === 0) continue;

        const duel = duelDoc.data();
        const cSel: ArenaSelection[] = duel.challengerSelections ?? [];
        const oSel: ArenaSelection[] = duel.opponentSelections ?? [];
        if (cSel.length === 0 || oSel.length === 0) continue;

        const cCorrect = correctCount(cSel, scoreMap);
        const oCorrect = correctCount(oSel, scoreMap);
        if (cCorrect === null || oCorrect === null) continue; // wait — not all matches done

        const cOdds = combinedOdds(cSel);
        const oOdds = combinedOdds(oSel);
        const wager: number = duel.wager ?? 0;

        let winnerId: string | null = null;
        let loserId: string | null = null;
        if (cCorrect > oCorrect || (cCorrect === oCorrect && cOdds > oOdds)) {
          winnerId = duel.challengerId;
          loserId = duel.opponentId;
        } else if (oCorrect > cCorrect || (oCorrect === cCorrect && oOdds > cOdds)) {
          winnerId = duel.opponentId;
          loserId = duel.challengerId;
        }
        // Exact tie (same correct + same odds) → no winner, both refunded their wager.

        await db.runTransaction(async (tx) => {
          const membersRef = leagueRef.collection("members");
          if (winnerId && loserId) {
            // Winner gets back stake + opponent stake (pot). Loser already paid stake on accept.
            const winnerRef = membersRef.doc(winnerId);
            const winSnap = await tx.get(winnerRef);
            const winPts = (winSnap.data()?.points as number) ?? 0;
            tx.update(winnerRef, { points: winPts + wager * 2 });
          } else {
            // Tie — refund both their wager.
            for (const uid of [duel.challengerId, duel.opponentId]) {
              const ref = membersRef.doc(uid);
              const snap = await tx.get(ref);
              const pts = (snap.data()?.points as number) ?? 0;
              tx.update(ref, { points: pts + wager });
            }
          }
          tx.update(duelDoc.ref, {
            status: "resolved",
            winnerId: winnerId ?? null,
            loserId: loserId ?? null,
            resolvedAt: FieldValue.serverTimestamp(),
          });
        });

        logger.info(`Arena resolved ${leagueId}/${duelDoc.id} winner=${winnerId ?? "tie"}`);
      }

      // Advance pagination. A short page means we've drained the backlog.
      if (activeSnap.size < PAGE) break;
      cursor = activeSnap.docs[activeSnap.docs.length - 1];
    }
  }
);

// ─────────────────────────────────────────────────────────────
// Ticket settlement — READY for when tickets move to Firestore.
// Path expected: leagues/{code}/members/{uid}/tickets/{ticketId}
// ─────────────────────────────────────────────────────────────

interface TicketSelection {
  eventId?: string;
  home: string;
  away: string;
  oddLabel: string;
  oddValue: number;
}

/**
 * Settle a single ticket against the score map. Returns the points delta to
 * apply (payout if all picks win, else 0) and whether it's now resolved.
 * Wire this into a scheduledTicketSettlement once tickets are in Firestore.
 */
export function settleTicket(
  ticket: { selections: TicketSelection[]; stake: number; potentialPayout: number },
  scores: Map<string, MatchScore>
): { resolved: boolean; won: boolean; delta: number } {
  let allDone = true;
  let allWon = true;
  for (const sel of ticket.selections) {
    const score = sel.eventId ? scores.get(sel.eventId) : undefined;
    if (!score || !score.completed) { allDone = false; break; }
    const expected = canonicalPickCode(sel.oddLabel);
    const actual = winnerCode(score.homeScore, score.awayScore);
    if (expected === null || actual === null) { allDone = false; break; }
    if (expected !== actual) allWon = false;
  }
  if (!allDone) return { resolved: false, won: false, delta: 0 };
  return { resolved: true, won: allWon, delta: allWon ? ticket.potentialPayout : 0 };
}

// ─────────────────────────────────────────────────────────────
// Callable: secure points adjust (placeholder for future hardening).
// Once Firestore rules lock member point writes to server-only, the client
// calls this instead of writing points directly.
// ─────────────────────────────────────────────────────────────

export const adjustPoints = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  const { leagueId, delta } = req.data as { leagueId?: string; delta?: number };
  if (!leagueId || typeof delta !== "number") {
    throw new HttpsError("invalid-argument", "leagueId and numeric delta required.");
  }
  const uid = req.auth.uid;
  const ref = db.collection("leagues").doc(leagueId).collection("members").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Not a member of this league.");
    const pts = (snap.data()?.points as number) ?? 0;
    tx.update(ref, { points: Math.max(0, pts + delta) });
  });
  return { ok: true };
});
