import React from "react";
import { AbsoluteFill, Sequence, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";
import { Stadium, Particles } from "./Stadium";
import { PhoneFrame } from "./PhoneFrame";
import { PhoneRanking } from "./PhoneRanking";
import { FloatingReactions, CommentBubbles } from "./SocialOverlay";

// Short punchy loop: POV hook → ranking overtake → logo. ~9s.
export const POV_TOTAL = 270;

const PovHook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const line1 = spring({ frame, fps, config: { damping: 15, stiffness: 110 } });
  const bubble = spring({ frame: frame - 20, fps, config: { damping: 13, stiffness: 130 } });
  const line2 = spring({ frame: frame - 42, fps, config: { damping: 13, stiffness: 120 } });
  return (
    <AbsoluteFill>
      <Stadium glow={0.15} />
      <Particles count={16} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 40, padding: 70 }}>
        <div
          style={{
            fontFamily: T.display,
            fontSize: 100,
            lineHeight: 1,
            color: T.fg,
            textAlign: "center",
            opacity: line1,
            transform: `translateY(${(1 - line1) * 60}px)`,
          }}
        >
          POV: TU COLEGA
          <br />
          DICE QUE <span style={{ color: T.arena }}>LO SABÍA</span>
        </div>

        <div
          style={{
            borderRadius: 30,
            borderBottomLeftRadius: 10,
            background: "#1c2420",
            padding: "26px 38px",
            transform: `scale(${bubble}) rotate(${(1 - bubble) * -6}deg)`,
            opacity: bubble,
          }}
        >
          <span style={{ fontFamily: T.body, fontWeight: 700, fontSize: 40, color: "#e9edea" }}>
            "yo lo dije eh 😏"
          </span>
        </div>

        <div
          style={{
            fontFamily: T.display,
            fontSize: 130,
            color: T.lime,
            textAlign: "center",
            opacity: line2,
            transform: `scale(${0.7 + line2 * 0.3})`,
            textShadow: "0 0 80px rgba(201,247,58,0.4)",
          }}
        >
          QUE LO DEMUESTRE.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const PovRanking: React.FC = () => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();
  return (
    <AbsoluteFill>
      <Stadium glow={0.11} />
      <Particles count={12} />
      <div
        style={{
          position: "absolute",
          top: 96,
          width: "100%",
          textAlign: "center",
          fontFamily: T.display,
          fontSize: 84,
          color: T.fg,
          opacity: interpolate(frame, [4, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        EN <span style={{ color: T.lime }}>BETSY</span> SE VE TODO.
      </div>
      <PhoneFrame
        style={{ transform: `translateY(${interpolate(frame, [0, 16], [110, 0], { extrapolateRight: "clamp" })}px)` }}
      >
        <PhoneRanking t={frame - 6} />
      </PhoneFrame>
      <FloatingReactions from={50} count={12} />
      <CommentBubbles
        comments={[
          { name: "marc", text: "vale... lo demuestro 😤", at: 55 },
          { name: "júlia", text: "esto acaba MAL jajaja", at: 115 },
        ]}
      />
    </AbsoluteFill>
  );
};

const PovLogo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const inS = spring({ frame, fps, config: { damping: 12, stiffness: 100 } });
  const sub = spring({ frame: frame - 12, fps, config: { damping: 15, stiffness: 120 } });
  return (
    <AbsoluteFill>
      <Stadium glow={0.16} />
      <Particles count={16} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 20 }}>
        <div
          style={{
            fontFamily: T.display,
            fontSize: 300,
            lineHeight: 0.9,
            color: T.lime,
            transform: `scale(${0.7 + inS * 0.3})`,
            opacity: inS,
            textShadow: "0 0 110px rgba(201,247,58,0.5)",
          }}
        >
          BETSY
        </div>
        <div
          style={{
            fontFamily: T.mono,
            fontWeight: 800,
            fontSize: 28,
            letterSpacing: 8,
            color: T.fg2,
            opacity: sub,
            transform: `translateY(${(1 - sub) * 30}px)`,
          }}
        >
          MUY PRONTO · SIN DINERO REAL
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const CrossFade: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [at - 6, at], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

export const BetsyPov: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#0a0a09" }}>
      <Sequence durationInFrames={80}>
        <PovHook />
      </Sequence>
      <Sequence from={80 - 6} durationInFrames={210 - 80 + 6}>
        <CrossFade at={6}>
          <PovRanking />
        </CrossFade>
      </Sequence>
      <Sequence from={210 - 6}>
        <CrossFade at={6}>
          <PovLogo />
        </CrossFade>
      </Sequence>
    </AbsoluteFill>
  );
};
