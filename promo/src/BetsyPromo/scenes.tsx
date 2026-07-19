import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { T } from "./theme";
import { Stadium, Particles } from "./Stadium";
import { PhoneHome } from "./PhoneHome";

// ————————————————————————————————— Scene 1 · Hook
// "EL FÚTBOL NO SE MIRA." → strike → "SE JUEGA."

export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const line1 = spring({ frame, fps, config: { damping: 16, stiffness: 100 } });
  const strike = spring({ frame: frame - 22, fps, config: { damping: 30, stiffness: 200 } });
  const line2 = spring({ frame: frame - 34, fps, config: { damping: 13, stiffness: 120 } });
  const flash = interpolate(frame, [34, 37, 46], [0, 0.5, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill>
      <Stadium glow={0.16} />
      <Particles count={18} />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "column",
          gap: 30,
          padding: 80,
        }}
      >
        <div style={{ overflow: "hidden" }}>
          <div
            style={{
              fontFamily: T.display,
              fontSize: 108,
              lineHeight: 1,
              color: T.fg,
              letterSpacing: 1,
              textAlign: "center",
              transform: `translateY(${(1 - line1) * 120}%)`,
            }}
          >
            EL FÚTBOL{" "}
            <span style={{ position: "relative", color: T.fg2 }}>
              NO SE MIRA.
              <span
                style={{
                  position: "absolute",
                  left: "-3%",
                  top: "54%",
                  width: "106%",
                  height: 10,
                  borderRadius: 99,
                  background: T.arena,
                  transform: `scaleX(${strike})`,
                  transformOrigin: "left center",
                }}
              />
            </span>
          </div>
        </div>
        <div style={{ overflow: "hidden", padding: "10px 0" }}>
          <div
            style={{
              fontFamily: T.display,
              fontSize: 300,
              lineHeight: 0.9,
              color: T.lime,
              textAlign: "center",
              transform: `translateY(${(1 - line2) * 115}%)`,
              textShadow: "0 0 90px rgba(201,247,58,0.45)",
            }}
          >
            SE JUEGA.
          </div>
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ background: T.lime, opacity: flash }} />
    </AbsoluteFill>
  );
};

// ————————————————————————————————— Scene 2 · Phone demo

const FloatCard: React.FC<{
  label: string;
  main: string;
  accent: string;
  enter: number;
  x: number;
  y: number;
  drift: number;
}> = ({ label, main, accent, enter, x, y, drift }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      borderRadius: 24,
      border: "2px solid rgba(255,255,255,0.14)",
      background: "linear-gradient(160deg, rgba(40,40,36,0.92), rgba(18,18,17,0.95))",
      boxShadow: "0 30px 80px rgba(0,0,0,0.55)",
      padding: "22px 28px",
      transform: `translateY(${(1 - enter) * 90 + drift}px) scale(${0.7 + enter * 0.3})`,
      opacity: enter,
      zIndex: 3,
    }}
  >
    <div style={{ fontFamily: T.mono, fontSize: 17, fontWeight: 800, letterSpacing: 3, color: T.fg3 }}>
      {label}
    </div>
    <div style={{ fontFamily: T.body, fontWeight: 900, fontSize: 30, color: T.fg, marginTop: 6 }}>
      {main}
    </div>
    <div style={{ fontFamily: T.mono, fontSize: 24, fontWeight: 800, color: T.lime, marginTop: 2 }}>
      {accent}
    </div>
  </div>
);

export const PhoneDemo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  const phoneIn = spring({ frame, fps, config: { damping: 15, stiffness: 70 }, durationInFrames: 45 });
  const rotate = interpolate(phoneIn, [0, 1], [-7, 0]);
  const drift = Math.sin(frame / 38) * 8;

  const cardA = spring({ frame: frame - 62, fps, config: { damping: 13, stiffness: 100 } });
  const cardB = spring({ frame: frame - 76, fps, config: { damping: 13, stiffness: 100 } });

  const phoneW = 660;
  const phoneH = 1345;

  return (
    <AbsoluteFill>
      <Stadium glow={0.1} />
      <Particles count={14} />

      {/* headline above phone */}
      <div
        style={{
          position: "absolute",
          top: 96,
          width: "100%",
          textAlign: "center",
          fontFamily: T.display,
          fontSize: 84,
          color: T.fg,
          letterSpacing: 1,
          opacity: interpolate(frame, [8, 26], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        TU LIGA. <span style={{ color: T.lime }}>TUS REGLAS.</span>
      </div>

      {/* glow behind phone */}
      <div
        style={{
          position: "absolute",
          left: width / 2 - 450,
          top: 330,
          width: 900,
          height: 1300,
          borderRadius: 999,
          background: "radial-gradient(closest-side, rgba(201,247,58,0.17), transparent)",
          filter: "blur(30px)",
        }}
      />

      {/* phone */}
      <div
        style={{
          position: "absolute",
          left: width / 2 - phoneW / 2,
          top: 250,
          width: phoneW,
          height: phoneH,
          borderRadius: 92,
          border: "3px solid rgba(255,255,255,0.16)",
          background: "#050505",
          padding: 20,
          boxShadow: "0 80px 200px rgba(0,0,0,0.75), inset 0 2px 0 rgba(255,255,255,0.12)",
          transform: `translateY(${(1 - phoneIn) * 900 + drift}px) rotate(${rotate}deg)`,
          zIndex: 2,
        }}
      >
        {/* dynamic island */}
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: 36,
            transform: "translateX(-50%)",
            width: 180,
            height: 46,
            borderRadius: 99,
            background: "#000",
            zIndex: 10,
          }}
        />
        <div style={{ width: "100%", height: "100%", borderRadius: 72, overflow: "hidden" }}>
          <PhoneHome t={frame - 14} />
        </div>
      </div>

      <FloatCard
        label="LIGA MAFIA"
        main="👑 Xavi · 1º"
        accent="1.240 pts"
        enter={cardA}
        x={44}
        y={430}
        drift={Math.sin(frame / 30) * 10}
      />
      <FloatCard
        label="APUESTA GANADA"
        main="España 2-0 ✓"
        accent="+144 pts"
        enter={cardB}
        x={width - 380}
        y={1180}
        drift={Math.cos(frame / 34) * 10}
      />
    </AbsoluteFill>
  );
};

// ————————————————————————————————— Scene 3 · Equation outro

export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const term = (d: number) => spring({ frame: frame - d, fps, config: { damping: 14, stiffness: 120 } });
  const t1 = term(0);
  const t2 = term(10);
  const t3 = term(20);
  const strike = spring({ frame: frame - 30, fps, config: { damping: 28, stiffness: 210 } });
  const result = spring({ frame: frame - 40, fps, config: { damping: 12, stiffness: 90 } });
  const cta = spring({ frame: frame - 58, fps, config: { damping: 16, stiffness: 110 } });

  const termStyle: React.CSSProperties = {
    fontFamily: T.display,
    fontSize: 120,
    lineHeight: 1,
    color: T.fg,
  };

  return (
    <AbsoluteFill>
      <Stadium glow={0.14} />
      <Particles count={16} />
      <AbsoluteFill
        style={{ alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 44 }}
      >
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26 }}>
          <div style={{ ...termStyle, transform: `scale(${t1})`, opacity: t1 }}>FANTASY</div>
          <div style={{ ...termStyle, fontSize: 76, color: T.lime, transform: `scale(${t2})`, opacity: t2 }}>
            +
          </div>
          <div style={{ ...termStyle, transform: `scale(${t2})`, opacity: t2 }}>APUESTAS</div>
          <div style={{ ...termStyle, fontSize: 76, color: T.arena, transform: `scale(${t3})`, opacity: t3 }}>
            −
          </div>
          <div style={{ position: "relative", transform: `scale(${t3})`, opacity: t3 }}>
            <div style={{ ...termStyle, color: T.fg3 }}>DINERO</div>
            <div
              style={{
                position: "absolute",
                left: "-4%",
                top: "50%",
                width: "108%",
                height: 12,
                borderRadius: 99,
                background: T.arena,
                transform: `scaleX(${strike})`,
                transformOrigin: "left center",
              }}
            />
          </div>
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 6,
            transform: `scale(${0.6 + result * 0.4})`,
            opacity: result,
          }}
        >
          <div
            style={{
              fontFamily: T.display,
              fontSize: 290,
              lineHeight: 0.95,
              color: T.lime,
              textShadow: "0 0 110px rgba(201,247,58,0.5)",
            }}
          >
            = BETSY
          </div>
          <div
            style={{
              fontFamily: T.mono,
              fontSize: 27,
              fontWeight: 800,
              letterSpacing: 8,
              color: T.fg2,
            }}
          >
            EL JUEGO SOCIAL DE PREDICCIÓN
          </div>
        </div>

        <div
          style={{
            transform: `translateY(${(1 - cta) * 60}px)`,
            opacity: cta,
            borderRadius: 99,
            background: T.lime,
            padding: "28px 74px",
            boxShadow: "0 20px 90px rgba(201,247,58,0.4)",
          }}
        >
          <span style={{ fontFamily: T.body, fontWeight: 900, fontSize: 40, color: T.limeInk }}>
            Muy pronto
          </span>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
