import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";
import { Stadium, Particles } from "./Stadium";
import { PhoneFrame, Callout } from "./PhoneFrame";
import { PhoneCreateLeague } from "./PhoneCreateLeague";
import { PhonePlaceBet } from "./PhonePlaceBet";

const SceneTitle: React.FC<{ step: string; title: string }> = ({ step, title }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const in1 = spring({ frame, fps, config: { damping: 16, stiffness: 100 } });
  return (
    <div
      style={{
        position: "absolute",
        top: 96,
        width: "100%",
        textAlign: "center",
        opacity: in1,
        transform: `translateY(${(1 - in1) * -30}px)`,
      }}
    >
      <div
        style={{
          fontFamily: T.mono,
          fontWeight: 800,
          fontSize: 30,
          letterSpacing: 8,
          color: T.lime,
        }}
      >
        {step}
      </div>
      <div style={{ fontFamily: T.display, fontSize: 74, color: T.fg, marginTop: 6 }}>{title}</div>
    </div>
  );
};

// ————————————————————————————————— Scene: Create a league (explanatory)
export const CreateLeagueScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();

  const c1 = interpolate(frame, [16, 34], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const c2 = interpolate(frame, [56, 74], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const c3 = interpolate(frame, [96, 114], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill>
      <Stadium glow={0.11} />
      <Particles count={14} />
      <SceneTitle step="PASO 1" title="Crea tu liga" />

      <div
        style={{
          position: "absolute",
          left: width / 2 - 450,
          top: 330,
          width: 900,
          height: 1300,
          borderRadius: 999,
          background: "radial-gradient(closest-side, rgba(201,247,58,0.15), transparent)",
          filter: "blur(30px)",
        }}
      />

      <PhoneFrame style={{ transform: `translateY(${interpolate(frame, [0, 14], [90, 0], { extrapolateRight: "clamp" })}px)` }}>
        <PhoneCreateLeague t={frame - 6} />
      </PhoneFrame>

      <Callout text="Ponle nombre" x={width - 360} y={430} enter={c1} align="right" />
      <Callout text="Elige tus deportes" x={40} y={604} enter={c2} align="left" />
      <Callout text="Todos empiezan igual" x={width - 400} y={1020} enter={c3} align="right" />
    </AbsoluteFill>
  );
};

// ————————————————————————————————— Scene: Place a bet (explanatory)
export const PlaceBetScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();

  const c1 = interpolate(frame, [16, 34], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const c2 = interpolate(frame, [42, 60], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const c3 = interpolate(frame, [78, 96], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill>
      <Stadium glow={0.11} />
      <Particles count={14} />
      <SceneTitle step="PASO 2" title="Haz tu apuesta" />

      <div
        style={{
          position: "absolute",
          left: width / 2 - 450,
          top: 330,
          width: 900,
          height: 1300,
          borderRadius: 999,
          background: "radial-gradient(closest-side, rgba(201,247,58,0.15), transparent)",
          filter: "blur(30px)",
        }}
      />

      <PhoneFrame style={{ transform: `translateY(${interpolate(frame, [0, 14], [90, 0], { extrapolateRight: "clamp" })}px)` }}>
        <PhonePlaceBet t={frame - 6} />
      </PhoneFrame>

      <Callout text="Elige el partido real" x={40} y={356} enter={c1} align="left" accent={T.arena} />
      <Callout text="Toca una cuota" x={40} y={780} enter={c2} align="left" accent={T.arena} />
      <Callout text="Puntos, no dinero" x={40} y={1130} enter={c3} align="left" accent={T.arena} />
    </AbsoluteFill>
  );
};
