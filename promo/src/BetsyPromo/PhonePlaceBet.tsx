import React from "react";
import { interpolate, spring, useVideoConfig } from "remotion";
import { T } from "./theme";
import { StatusBar } from "./PhoneFrame";

// Recreation of picking a market, selecting an odd, setting stake and confirming a bet.
export const PhonePlaceBet: React.FC<{ t: number }> = ({ t }) => {
  const { fps } = useVideoConfig();

  const headerIn = spring({ frame: t, fps, config: { damping: 16, stiffness: 110 } });
  const matchIn = spring({ frame: t - 8, fps, config: { damping: 15, stiffness: 100 } });

  // odd tap: the "1" odd gets selected around frame 40
  const selectProgress = spring({ frame: t - 40, fps, config: { damping: 14, stiffness: 200 } });
  const tapPulse = spring({ frame: t - 40, fps, config: { damping: 8, stiffness: 300 }, durationInFrames: 14 });

  const slipIn = spring({ frame: t - 58, fps, config: { damping: 16, stiffness: 110 } });
  // stake counts up
  const stakeProgress = spring({ frame: t - 74, fps, config: { damping: 200 }, durationInFrames: 40 });
  const stake = Math.round(stakeProgress * 100);
  const payout = (stake * 2.1).toFixed(0);

  const ctaIn = spring({ frame: t - 100, fps, config: { damping: 15, stiffness: 120 } });
  const ctaPulse = 1 + Math.sin(t / 8) * 0.02;

  const confirmFlash = interpolate(t, [116, 122, 132, 144], [0, 0.92, 0.92, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const oddBox = (label: string, value: string, selected: number): React.CSSProperties => ({
    flex: 1,
    borderRadius: 16,
    border: `2px solid ${selected > 0.3 ? T.lime : T.line}`,
    background: selected > 0.3 ? T.lime : T.bg2,
    padding: "16px 0",
    textAlign: "center",
    transform: `scale(${1 + (selected > 0.3 ? tapPulse * 0.08 : 0)})`,
  });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: T.bg,
        display: "flex",
        flexDirection: "column",
        padding: "68px 34px 40px",
        gap: 26,
        overflow: "hidden",
        position: "relative",
      }}
    >
      <StatusBar />

      <div
        style={{
          fontFamily: T.mono,
          fontWeight: 800,
          fontSize: 21,
          letterSpacing: 4,
          color: T.fg3,
          opacity: headerIn,
          transform: `translateY(${(1 - headerIn) * 20}px)`,
        }}
      >
        MUNDIAL · HOY
      </div>

      {/* match + market */}
      <div
        style={{
          borderRadius: 26,
          border: `2px solid ${T.line}`,
          background: T.bg1,
          padding: "26px 26px",
          display: "flex",
          flexDirection: "column",
          gap: 20,
          opacity: matchIn,
          transform: `translateY(${(1 - matchIn) * 30}px)`,
        }}
      >
        <div style={{ fontFamily: T.body, fontWeight: 800, fontSize: 32, color: T.fg }}>
          España <span style={{ color: T.fg3, fontWeight: 700 }}>vs</span> Brasil
        </div>
        <div style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 18, letterSpacing: 2, color: T.fg3 }}>
          GANADOR DEL PARTIDO
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          <div style={oddBox("1", "2.10", selectProgress)}>
            <div style={{ fontFamily: T.mono, fontSize: 16, color: selectProgress > 0.3 ? T.limeInk : T.fg3 }}>1</div>
            <div
              style={{
                fontFamily: T.body,
                fontWeight: 900,
                fontSize: 30,
                color: selectProgress > 0.3 ? T.limeInk : T.fg,
              }}
            >
              2.10
            </div>
          </div>
          <div style={oddBox("X", "3.40", 0)}>
            <div style={{ fontFamily: T.mono, fontSize: 16, color: T.fg3 }}>X</div>
            <div style={{ fontFamily: T.body, fontWeight: 900, fontSize: 30, color: T.fg }}>3.40</div>
          </div>
          <div style={oddBox("2", "3.10", 0)}>
            <div style={{ fontFamily: T.mono, fontSize: 16, color: T.fg3 }}>2</div>
            <div style={{ fontFamily: T.body, fontWeight: 900, fontSize: 30, color: T.fg }}>3.10</div>
          </div>
        </div>
      </div>

      <div style={{ flex: 1 }} />

      {/* bet slip */}
      <div
        style={{
          borderRadius: 28,
          border: "2px solid rgba(201,247,58,0.4)",
          background: "linear-gradient(170deg, rgba(201,247,58,0.1), rgba(18,18,17,0.95))",
          padding: "26px 28px",
          display: "flex",
          flexDirection: "column",
          gap: 18,
          opacity: slipIn,
          transform: `translateY(${(1 - slipIn) * 60}px)`,
          position: "relative",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 19, letterSpacing: 2, color: T.fg3 }}>
            TU APUESTA
          </span>
          <span style={{ fontFamily: T.body, fontWeight: 800, fontSize: 19, color: T.fg }}>
            España gana · 2.10
          </span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 19, letterSpacing: 2, color: T.fg3 }}>
            APUESTAS
          </span>
          <span style={{ fontFamily: T.display, fontSize: 48, color: T.fg }}>{stake} pts</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 19, letterSpacing: 2, color: T.fg3 }}>
            SI ACIERTAS
          </span>
          <span style={{ fontFamily: T.display, fontSize: 48, color: T.lime }}>+{payout} pts</span>
        </div>

        {confirmFlash > 0.01 && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 28,
              background: T.lime,
              opacity: confirmFlash,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <span style={{ fontFamily: T.display, fontSize: 46, color: T.limeInk }}>APOSTADO ✓</span>
          </div>
        )}
      </div>

      {/* CTA */}
      <div
        style={{
          transform: `translateY(${(1 - ctaIn) * 70}px) scale(${ctaPulse})`,
          opacity: ctaIn,
          borderRadius: 99,
          background: T.lime,
          padding: "26px 0",
          textAlign: "center",
          boxShadow: "0 18px 70px rgba(201,247,58,0.35)",
        }}
      >
        <span style={{ fontFamily: T.body, fontWeight: 900, fontSize: 32, color: T.limeInk }}>
          Confirmar apuesta →
        </span>
      </div>
    </div>
  );
};
