import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from "remotion";
import { Hook, PhoneDemo, Outro } from "./scenes";

// ~10.7s vertical promo @30fps = 320 frames (extended slightly to fit the VO take)
// Hook 0-70 · PhoneDemo 70-220 · Outro 220-320
export const HOOK_END = 70;
export const DEMO_END = 220;
export const TOTAL = 320;

const CrossFade: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [at - 6, at], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

export const BetsyPromo: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#0a0a09" }}>
      <Sequence durationInFrames={HOOK_END}>
        <Hook />
      </Sequence>
      <Sequence from={HOOK_END - 6} durationInFrames={DEMO_END - HOOK_END + 6}>
        <CrossFade at={6}>
          <PhoneDemo />
        </CrossFade>
      </Sequence>
      <Sequence from={DEMO_END - 6}>
        <CrossFade at={6}>
          <Outro />
        </CrossFade>
      </Sequence>
    </AbsoluteFill>
  );
};
