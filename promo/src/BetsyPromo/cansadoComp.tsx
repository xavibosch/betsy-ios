import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";
import { Stadium, Particles } from "./Stadium";
import { PhoneFrame, Callout } from "./PhoneFrame";
import { WhatsAppChaos, NowWithBetsy } from "./WhatsAppChaos";
import { PhonePlaceBet } from "./PhonePlaceBet";
import { PhoneRanking } from "./PhoneRanking";
import { FloatingReactions, CommentBubbles } from "./SocialOverlay";
import { Outro } from "./scenes";

// "¿Cansado de esto?" explainer — problem → answer → bet → ranking → outro.
// 0-130 chat chaos · 130-190 AHORA CON BETSY · 190-340 place bet · 340-490 ranking · 490-590 outro
export const CANSADO_TOTAL = 590;

const CrossFade: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [at - 6, at], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

const BetScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();
  const c1 = interpolate(frame, [26, 44], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const c2 = interpolate(frame, [64, 82], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
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
          fontSize: 78,
          color: T.fg,
          opacity: interpolate(frame, [4, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        APUESTA <span style={{ color: T.lime }}>DE VERDAD.</span>
      </div>
      <PhoneFrame
        style={{ transform: `translateY(${interpolate(frame, [0, 16], [110, 0], { extrapolateRight: "clamp" })}px)` }}
      >
        <PhonePlaceBet t={frame - 8} />
      </PhoneFrame>
      <Callout text="Cuotas reales" x={40} y={700} enter={c1} align="left" />
      <Callout text="Puntos, no dinero" x={width - 430} y={1130} enter={c2} align="right" />
    </AbsoluteFill>
  );
};

const RankingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();
  const c1 = interpolate(frame, [70, 88], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
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
          fontSize: 78,
          color: T.fg,
          opacity: interpolate(frame, [4, 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        EL RANKING <span style={{ color: T.lime }}>NO DISCUTE.</span>
      </div>
      <PhoneFrame
        style={{ transform: `translateY(${interpolate(frame, [0, 16], [110, 0], { extrapolateRight: "clamp" })}px)` }}
      >
        <PhoneRanking t={frame - 8} />
      </PhoneFrame>
      <Callout text="Gana quien acierta" x={width - 470} y={300} enter={c1} align="right" />
      <FloatingReactions from={60} count={10} />
    </AbsoluteFill>
  );
};

export const BetsyCansado: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#0a0a09" }}>
      <Sequence durationInFrames={130}>
        <WhatsAppChaos />
      </Sequence>
      <Sequence from={130} durationInFrames={60}>
        <NowWithBetsy />
      </Sequence>
      <Sequence from={190 - 6} durationInFrames={340 - 190 + 6}>
        <CrossFade at={6}>
          <BetScene />
        </CrossFade>
      </Sequence>
      <Sequence from={340 - 6} durationInFrames={490 - 340 + 6}>
        <CrossFade at={6}>
          <RankingScene />
        </CrossFade>
      </Sequence>
      <Sequence from={490 - 6}>
        <CrossFade at={6}>
          <Outro />
        </CrossFade>
      </Sequence>
      {/* social proof layer across the app scenes */}
      <Sequence from={200} durationInFrames={290}>
        <CommentBubbles
          comments={[
            { name: "dani", text: "mi grupo NECESITA esto 😭", at: 20 },
            { name: "alba", text: "¿dónde se descarga? 👀", at: 130 },
            { name: "leo", text: "por fin sin dinero real 🙌", at: 240 },
          ]}
        />
      </Sequence>
    </AbsoluteFill>
  );
};
