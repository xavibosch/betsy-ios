import React from "react";
import { AbsoluteFill, interpolate, random, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";

// Stadium backdrop — pitch grid + top floodlight glow, mirrors betsy-web `.stadium/.pitch`.
export const Stadium: React.FC<{ glow?: number }> = ({ glow = 0.12 }) => {
  return (
    <AbsoluteFill style={{ background: T.bg }}>
      <AbsoluteFill
        style={{
          backgroundImage: `linear-gradient(rgba(201,247,58,0.05) 2px, transparent 2px),
            linear-gradient(90deg, rgba(201,247,58,0.05) 2px, transparent 2px)`,
          backgroundSize: "108px 108px",
          maskImage:
            "radial-gradient(ellipse 80% 55% at 50% 42%, black 30%, transparent 78%)",
          WebkitMaskImage:
            "radial-gradient(ellipse 80% 55% at 50% 42%, black 30%, transparent 78%)",
        }}
      />
      <AbsoluteFill
        style={{
          background: `radial-gradient(1400px 700px at 50% -10%, rgba(201,247,58,${glow}), transparent 62%),
            radial-gradient(900px 500px at 12% 6%, rgba(255,255,255,0.05), transparent 55%),
            radial-gradient(900px 500px at 88% 6%, rgba(255,255,255,0.05), transparent 55%)`,
        }}
      />
    </AbsoluteFill>
  );
};

// Rising lime particles, deterministic via remotion random().
export const Particles: React.FC<{ count?: number }> = ({ count = 22 }) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  return (
    <AbsoluteFill>
      {Array.from({ length: count }).map((_, i) => {
        const seed = `p-${i}`;
        const x = random(seed) * width;
        const speed = 2 + random(seed + "s") * 4;
        const size = 3 + random(seed + "z") * 5;
        const phase = random(seed + "o") * height;
        const y = ((phase - frame * speed) % (height + 200)) + 100;
        const opacity =
          (0.15 + random(seed + "a") * 0.45) *
          interpolate(y, [0, height * 0.25, height * 0.8, height], [0, 1, 1, 0.3]);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y < -100 ? y + height + 200 : y,
              width: size,
              height: size,
              borderRadius: 99,
              background: T.lime,
              filter: "blur(0.5px)",
              opacity,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};
