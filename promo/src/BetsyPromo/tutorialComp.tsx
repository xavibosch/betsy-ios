import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from "remotion";
import { Hook, Outro } from "./scenes";
import { CreateLeagueScene, PlaceBetScene } from "./HowItWorks";

// "How it works" explanatory TikTok cut — vertical, ~16.7s @30fps.
// Hook 0-70 · Create league 70-220 · Place bet 220-370 · Outro 370-500
export const TUT_HOOK_END = 70;
export const TUT_CREATE_END = 220;
export const TUT_BET_END = 370;
export const TUT_TOTAL = 500;

const CrossFade: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [at - 6, at], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

export const BetsyTutorial: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#0a0a09" }}>
      <Sequence durationInFrames={TUT_HOOK_END}>
        <Hook />
      </Sequence>
      <Sequence from={TUT_HOOK_END - 6} durationInFrames={TUT_CREATE_END - TUT_HOOK_END + 6}>
        <CrossFade at={6}>
          <CreateLeagueScene />
        </CrossFade>
      </Sequence>
      <Sequence from={TUT_CREATE_END - 6} durationInFrames={TUT_BET_END - TUT_CREATE_END + 6}>
        <CrossFade at={6}>
          <PlaceBetScene />
        </CrossFade>
      </Sequence>
      <Sequence from={TUT_BET_END - 6}>
        <CrossFade at={6}>
          <Outro />
        </CrossFade>
      </Sequence>
    </AbsoluteFill>
  );
};
