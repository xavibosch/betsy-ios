import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";

// Betsy home screen, recreated as animatable markup (not a screenshot).
// `t` = local frame within the phone-demo scene.

const Row: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({
  children,
  style,
}) => (
  <div style={{ display: "flex", alignItems: "center", ...style }}>{children}</div>
);

const MatchCard: React.FC<{
  tag: string;
  time: string;
  home: string;
  away: string;
  odds: [string, string][];
  enter: number; // 0..1 spring
}> = ({ tag, time, home, away, odds, enter }) => (
  <div
    style={{
      flexShrink: 0,
      width: 340,
      borderRadius: 26,
      border: `2px solid ${T.line}`,
      background: T.bg1,
      padding: "22px 24px",
      display: "flex",
      flexDirection: "column",
      gap: 14,
      transform: `translateX(${(1 - enter) * 420}px)`,
      opacity: enter,
    }}
  >
    <Row style={{ justifyContent: "space-between" }}>
      <span style={{ fontFamily: T.mono, fontSize: 20, fontWeight: 800, color: T.fg3, letterSpacing: 2 }}>
        {time}
      </span>
      <span
        style={{
          fontFamily: T.mono,
          fontSize: 19,
          fontWeight: 800,
          color: T.lime,
          letterSpacing: 2,
        }}
      >
        {tag}
      </span>
    </Row>
    <div style={{ fontFamily: T.body, fontWeight: 800, fontSize: 27, color: T.fg }}>
      {home} <span style={{ color: T.fg3, fontWeight: 700 }}>vs</span> {away}
    </div>
    <Row style={{ gap: 10 }}>
      {odds.map(([l, v]) => (
        <div
          key={l}
          style={{
            flex: 1,
            borderRadius: 14,
            border: `2px solid ${T.line}`,
            background: T.bg2,
            padding: "10px 0",
            textAlign: "center",
          }}
        >
          <div style={{ fontFamily: T.mono, fontSize: 16, color: T.fg3 }}>{l}</div>
          <div style={{ fontFamily: T.body, fontWeight: 900, fontSize: 24, color: T.fg }}>{v}</div>
        </div>
      ))}
    </Row>
  </div>
);

export const PhoneHome: React.FC<{ t: number }> = ({ t }) => {
  const { fps } = useVideoConfig();
  const frame = useCurrentFrame();

  // Balance counts up 0 → 1240 with spring easing
  const balanceProgress = spring({ frame: t - 8, fps, config: { damping: 200 }, durationInFrames: 55 });
  const balance = Math.round(balanceProgress * 1240);

  const statIn = (delay: number) =>
    spring({ frame: t - delay, fps, config: { damping: 16, stiffness: 120 } });

  const card1 = spring({ frame: t - 46, fps, config: { damping: 17, stiffness: 90 } });
  const card2 = spring({ frame: t - 56, fps, config: { damping: 17, stiffness: 90 } });

  const ctaIn = spring({ frame: t - 34, fps, config: { damping: 14, stiffness: 110 } });
  const ctaPulse = 1 + Math.sin(frame / 9) * 0.018;

  const formPct = interpolate(t, [26, 80], [0, 0.62], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

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
      {/* status bar */}
      <Row style={{ justifyContent: "space-between" }}>
        <span style={{ fontFamily: T.body, fontWeight: 800, fontSize: 26, color: T.fg }}>18:59</span>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <span style={{ fontFamily: T.body, fontWeight: 800, fontSize: 22, color: T.fg2, letterSpacing: 2 }}>
            ●●●
          </span>
          <span
            style={{
              width: 46,
              height: 22,
              borderRadius: 7,
              border: `2px solid ${T.fg3}`,
              display: "inline-block",
              position: "relative",
            }}
          >
            <span
              style={{
                position: "absolute",
                left: 3,
                top: 3,
                bottom: 3,
                width: "70%",
                borderRadius: 3,
                background: T.lime,
              }}
            />
          </span>
        </div>
      </Row>

      {/* league header */}
      <Row style={{ gap: 14 }}>
        <div
          style={{
            width: 52,
            height: 52,
            borderRadius: 14,
            background: `linear-gradient(140deg, ${T.lime}, #9ed11f)`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily: T.display,
            fontSize: 30,
            color: T.limeInk,
          }}
        >
          B
        </div>
        <span style={{ fontFamily: T.display, fontSize: 44, color: T.fg, letterSpacing: 1 }}>
          MAFIA <span style={{ color: T.fg3, fontSize: 32 }}>▾</span>
        </span>
      </Row>

      {/* balance card */}
      <div
        style={{
          borderRadius: 30,
          border: `2px solid ${T.line}`,
          background: `linear-gradient(170deg, ${T.bg2}, ${T.bg1})`,
          padding: "30px 32px 26px",
          display: "flex",
          flexDirection: "column",
          gap: 14,
        }}
      >
        <Row style={{ justifyContent: "space-between" }}>
          <span style={{ fontFamily: T.mono, fontSize: 21, fontWeight: 800, letterSpacing: 4, color: T.fg3 }}>
            TU SALDO
          </span>
          <span
            style={{
              fontFamily: T.mono,
              fontSize: 19,
              fontWeight: 800,
              color: T.lime,
              background: "rgba(201,247,58,0.1)",
              border: `2px solid rgba(201,247,58,0.35)`,
              borderRadius: 99,
              padding: "6px 16px",
            }}
          >
            +140 hoy
          </span>
        </Row>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
          <span style={{ fontFamily: T.display, fontSize: 118, lineHeight: 0.9, color: T.fg }}>
            {balance.toLocaleString("es-ES")}
          </span>
          <span style={{ fontFamily: T.body, fontWeight: 700, fontSize: 34, color: T.fg3 }}>pts</span>
        </div>
        {/* form bar */}
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <span style={{ fontFamily: T.mono, fontSize: 17, fontWeight: 800, letterSpacing: 3, color: T.fg3 }}>
            FORMA <span style={{ color: T.lime }}>●</span>
          </span>
          <div style={{ height: 10, borderRadius: 99, background: T.bg, overflow: "hidden" }}>
            <div
              style={{
                width: `${formPct * 100}%`,
                height: "100%",
                borderRadius: 99,
                background: T.lime,
              }}
            />
          </div>
        </div>
      </div>

      {/* stat tiles */}
      <Row style={{ gap: 16 }}>
        {[
          ["POSICIÓN", "1º", "de 5", 20],
          ["ACIERTO", "64%", "racha ✓", 26],
          ["HOY", "3", "bets disp.", 32],
        ].map(([label, big, sub, d], i) => {
          const s = statIn(d as number);
          const hot = i === 2;
          return (
            <div
              key={label as string}
              style={{
                flex: 1,
                borderRadius: 22,
                border: `2px solid ${hot ? "rgba(201,247,58,0.5)" : T.line}`,
                background: hot ? "rgba(201,247,58,0.09)" : T.bg1,
                padding: "18px 18px 16px",
                transform: `translateY(${(1 - s) * 60}px)`,
                opacity: s,
              }}
            >
              <div style={{ fontFamily: T.mono, fontSize: 15, fontWeight: 800, letterSpacing: 2, color: T.fg3 }}>
                {label}
              </div>
              <div style={{ fontFamily: T.display, fontSize: 52, color: hot ? T.lime : T.fg, marginTop: 4 }}>
                {big}
              </div>
              <div style={{ fontFamily: T.body, fontSize: 17, color: T.fg3 }}>{sub}</div>
            </div>
          );
        })}
      </Row>

      {/* CTA */}
      <div
        style={{
          transform: `translateY(${(1 - ctaIn) * 80}px) scale(${ctaPulse})`,
          opacity: ctaIn,
          borderRadius: 99,
          background: T.lime,
          padding: "26px 0",
          textAlign: "center",
          boxShadow: "0 18px 70px rgba(201,247,58,0.35)",
        }}
      >
        <span style={{ fontFamily: T.body, fontWeight: 900, fontSize: 34, color: T.limeInk }}>
          Apostar →
        </span>
      </div>

      {/* today's matches */}
      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        <Row style={{ justifyContent: "space-between" }}>
          <span style={{ fontFamily: T.mono, fontSize: 19, fontWeight: 800, letterSpacing: 3, color: T.fg3 }}>
            HOY EN TU LIGA
          </span>
          <span style={{ fontFamily: T.body, fontSize: 19, fontWeight: 700, color: T.fg2 }}>Ver todo</span>
        </Row>
        <Row style={{ gap: 18 }}>
          <MatchCard
            tag="MUNDIAL"
            time="21:00"
            home="España"
            away="Brasil"
            odds={[["1", "2.10"], ["X", "3.40"], ["2", "3.10"]]}
            enter={card1}
          />
          <MatchCard
            tag="NBA"
            time="02:30"
            home="Lakers"
            away="Celtics"
            odds={[["1", "1.88"], ["2", "1.95"], ["+", "212.5"]]}
            enter={card2}
          />
        </Row>
      </div>
    </div>
  );
};
