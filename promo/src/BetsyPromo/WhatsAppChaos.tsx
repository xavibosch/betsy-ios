import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";

// The "tired of this?" hook — a chaotic group chat where everyone claims they called it.
const MESSAGES: { text: string; who: string; mine?: boolean; delay: number }[] = [
  { text: "Yo sabía que ganaría el Madrid 😏", who: "Marc", delay: 6 },
  { text: "JAJA siempre lo dices DESPUÉS", who: "Xavi", mine: true, delay: 22 },
  { text: "te lo dije ayer bro", who: "Marc", delay: 38 },
  { text: "no hay pruebas de nada 🤡", who: "Pau", delay: 52 },
  { text: "eso no cuenta y lo sabes", who: "Júlia", delay: 66 },
  { text: "SIEMPRE igual...", who: "Xavi", mine: true, delay: 80 },
];

export const WhatsAppChaos: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  const headerIn = spring({ frame, fps, config: { damping: 16, stiffness: 120 } });
  const overlayIn = spring({ frame: frame - 96, fps, config: { damping: 12, stiffness: 110 } });
  const shake = frame > 96 ? Math.sin(frame * 2.2) * interpolate(frame, [96, 110], [6, 0], { extrapolateRight: "clamp" }) : 0;

  return (
    <AbsoluteFill style={{ background: "#0b0f0c" }}>
      {/* dim chat backdrop */}
      <AbsoluteFill
        style={{
          background: "radial-gradient(1000px 600px at 50% 0%, rgba(37,49,40,0.9), rgba(11,15,12,1) 70%)",
          transform: `translateX(${shake}px)`,
          padding: "150px 60px 0",
        }}
      >
        {/* chat header */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 20,
            paddingBottom: 30,
            borderBottom: "2px solid rgba(255,255,255,0.08)",
            opacity: headerIn,
          }}
        >
          <div
            style={{
              width: 76,
              height: 76,
              borderRadius: 99,
              background: "linear-gradient(140deg, #2d3a31, #1a231d)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 38,
            }}
          >
            ⚽
          </div>
          <div>
            <div style={{ fontFamily: T.body, fontWeight: 900, fontSize: 36, color: "#e9edea" }}>
              FÚTBOL 🍺
            </div>
            <div style={{ fontFamily: T.body, fontSize: 24, color: "#8fa397" }}>
              Marc, Pau, Júlia, tú
            </div>
          </div>
        </div>

        {/* messages */}
        <div style={{ display: "flex", flexDirection: "column", gap: 22, paddingTop: 40 }}>
          {MESSAGES.map((m, i) => {
            const s = spring({ frame: frame - m.delay, fps, config: { damping: 15, stiffness: 140 } });
            return (
              <div
                key={i}
                style={{
                  alignSelf: m.mine ? "flex-end" : "flex-start",
                  maxWidth: "76%",
                  borderRadius: 26,
                  borderBottomRightRadius: m.mine ? 8 : 26,
                  borderBottomLeftRadius: m.mine ? 26 : 8,
                  background: m.mine ? "#1f4d3a" : "#1c2420",
                  padding: "20px 28px",
                  transform: `translateY(${(1 - s) * 50}px) scale(${0.9 + s * 0.1})`,
                  opacity: s,
                }}
              >
                {!m.mine && (
                  <div style={{ fontFamily: T.body, fontWeight: 800, fontSize: 21, color: "#7fd4a3", marginBottom: 4 }}>
                    {m.who}
                  </div>
                )}
                <div style={{ fontFamily: T.body, fontWeight: 600, fontSize: 29, color: "#e9edea", lineHeight: 1.25 }}>
                  {m.text}
                </div>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>

      {/* darkening + big overlay question */}
      <AbsoluteFill
        style={{
          background: `rgba(6,6,5,${overlayIn * 0.72})`,
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <div
          style={{
            transform: `scale(${0.7 + overlayIn * 0.3}) rotate(${(1 - overlayIn) * -4}deg)`,
            opacity: overlayIn,
            textAlign: "center",
            padding: "0 70px",
          }}
        >
          <div
            style={{
              fontFamily: T.display,
              fontSize: 150,
              lineHeight: 0.95,
              color: T.fg,
              textShadow: "0 30px 90px rgba(0,0,0,0.8)",
            }}
          >
            ¿CANSADO
            <br />
            DE <span style={{ color: T.arena }}>ESTO?</span>
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// Hard-cut answer card: "AHORA CON BETSY…"
export const NowWithBetsy: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const inS = spring({ frame, fps, config: { damping: 13, stiffness: 120 } });
  const subIn = spring({ frame: frame - 14, fps, config: { damping: 15, stiffness: 120 } });
  return (
    <AbsoluteFill style={{ background: T.lime, alignItems: "center", justifyContent: "center" }}>
      <div style={{ textAlign: "center", transform: `scale(${0.8 + inS * 0.2})`, opacity: inS }}>
        <div style={{ fontFamily: T.display, fontSize: 96, color: "rgba(19,24,0,0.55)", letterSpacing: 2 }}>
          AHORA CON
        </div>
        <div
          style={{
            fontFamily: T.display,
            fontSize: 330,
            lineHeight: 0.9,
            color: T.limeInk,
          }}
        >
          BETSY
        </div>
        <div
          style={{
            fontFamily: T.mono,
            fontWeight: 800,
            fontSize: 30,
            letterSpacing: 6,
            color: "rgba(19,24,0,0.7)",
            marginTop: 20,
            opacity: subIn,
            transform: `translateY(${(1 - subIn) * 30}px)`,
          }}
        >
          LAS EXCUSAS SE ACABAN
        </div>
      </div>
    </AbsoluteFill>
  );
};
