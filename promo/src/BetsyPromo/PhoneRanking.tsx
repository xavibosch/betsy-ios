import React from "react";
import { interpolate, spring, useVideoConfig } from "remotion";
import { T } from "./theme";
import { StatusBar } from "./PhoneFrame";

// League ranking screen — "you" overtake first place mid-scene.
// Before swap: Marc 1st / Xavi 2nd. After swap (t=SWAP): Xavi 1st.
const SWAP = 55;
const ROW_H = 118;

type Row = { name: string; pts: number; me?: boolean };
const BEFORE: Row[] = [
  { name: "Marc", pts: 1180 },
  { name: "Xavi", pts: 1140, me: true },
  { name: "Júlia", pts: 990 },
  { name: "Pau", pts: 870 },
];

export const PhoneRanking: React.FC<{ t: number }> = ({ t }) => {
  const { fps } = useVideoConfig();
  const headerIn = spring({ frame: t, fps, config: { damping: 16, stiffness: 110 } });
  const rowIn = (i: number) => spring({ frame: t - 8 - i * 7, fps, config: { damping: 15, stiffness: 120 } });
  const swap = spring({ frame: t - SWAP, fps, config: { damping: 15, stiffness: 90 } });

  // my points tick up as I overtake
  const myPts = Math.round(interpolate(swap, [0, 1], [1140, 1252]));
  const crownPop = spring({ frame: t - SWAP - 14, fps, config: { damping: 10, stiffness: 200 } });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: T.bg,
        display: "flex",
        flexDirection: "column",
        padding: "68px 34px 40px",
        gap: 28,
        overflow: "hidden",
      }}
    >
      <StatusBar />

      <div style={{ opacity: headerIn, transform: `translateY(${(1 - headerIn) * 20}px)` }}>
        <div style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 21, letterSpacing: 4, color: T.fg3 }}>
          LIGA MAFIA
        </div>
        <div style={{ fontFamily: T.display, fontSize: 64, color: T.fg, marginTop: 4 }}>RANKING</div>
      </div>

      <div style={{ position: "relative", height: BEFORE.length * ROW_H }}>
        {BEFORE.map((r, i) => {
          const s = rowIn(i);
          // position index after the swap animation
          let pos = i;
          if (r.me) pos = interpolate(swap, [0, 1], [1, 0]);
          else if (i === 0) pos = interpolate(swap, [0, 1], [0, 1]);
          const isFirst = r.me ? swap > 0.5 : i === 0 && swap <= 0.5;
          const pts = r.me ? myPts : r.pts;
          return (
            <div
              key={r.name}
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                top: pos * ROW_H,
                height: ROW_H - 14,
                display: "flex",
                alignItems: "center",
                gap: 18,
                borderRadius: 22,
                border: `2px solid ${r.me ? "rgba(201,247,58,0.55)" : T.line}`,
                background: r.me ? "rgba(201,247,58,0.1)" : T.bg1,
                padding: "0 24px",
                opacity: s,
                transform: `translateX(${(1 - s) * 60}px)`,
              }}
            >
              <span
                style={{
                  fontFamily: T.display,
                  fontSize: 40,
                  width: 44,
                  color: isFirst ? T.lime : T.fg3,
                }}
              >
                {Math.round(pos) + 1}
              </span>
              <span
                style={{
                  width: 58,
                  height: 58,
                  borderRadius: 99,
                  background: T.bg2,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontFamily: T.body,
                  fontWeight: 900,
                  fontSize: 22,
                  color: T.fg,
                }}
              >
                {r.name.slice(0, 2).toUpperCase()}
              </span>
              <span style={{ fontFamily: T.body, fontWeight: 800, fontSize: 30, color: T.fg }}>
                {r.name}
                {r.me && swap > 0.5 && (
                  <span style={{ display: "inline-block", transform: `scale(${crownPop})`, marginLeft: 10 }}>
                    👑
                  </span>
                )}
              </span>
              <span style={{ marginLeft: "auto", fontFamily: T.mono, fontWeight: 800, fontSize: 30, color: r.me ? T.lime : T.fg }}>
                {pts.toLocaleString("es-ES")}
              </span>
            </div>
          );
        })}
      </div>

      <div style={{ flex: 1 }} />

      <div
        style={{
          borderRadius: 22,
          border: `2px solid ${T.line}`,
          background: T.bg1,
          padding: "22px 26px",
          textAlign: "center",
          fontFamily: T.mono,
          fontWeight: 800,
          fontSize: 22,
          letterSpacing: 3,
          color: T.fg2,
        }}
      >
        TEMPORADA · JORNADA 12
      </div>
    </div>
  );
};
