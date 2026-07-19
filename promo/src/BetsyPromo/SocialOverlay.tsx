import React from "react";
import { AbsoluteFill, interpolate, random, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { T } from "./theme";

// Floating reaction emojis drifting up the right edge (TikTok-live vibe).
export const FloatingReactions: React.FC<{ from?: number; count?: number }> = ({
  from = 0,
  count = 14,
}) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const EMOJI = ["🔥", "😂", "👑", "⚽", "💚", "🙌"];
  return (
    <AbsoluteFill style={{ pointerEvents: "none", zIndex: 30 }}>
      {Array.from({ length: count }).map((_, i) => {
        const seed = `r-${i}`;
        const start = from + i * 14 + random(seed) * 10;
        const life = frame - start;
        if (life < 0) return null;
        const dur = 90;
        const p = Math.min(1, life / dur);
        if (p >= 1) return null;
        const x = width - 130 - random(seed + "x") * 110 + Math.sin(life / 11 + i) * 28;
        const y = height - 320 - p * (height * 0.62);
        const scale = 0.8 + random(seed + "s") * 0.6;
        const opacity = interpolate(p, [0, 0.12, 0.75, 1], [0, 1, 1, 0]);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y,
              fontSize: 64 * scale,
              opacity,
              transform: `rotate(${Math.sin(life / 14 + i) * 12}deg)`,
            }}
          >
            {EMOJI[i % EMOJI.length]}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// Social-style comment bubbles sliding in bottom-left, one at a time.
export const CommentBubbles: React.FC<{
  comments: { name: string; text: string; at: number }[];
  y?: number;
}> = ({ comments, y = 1500 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill style={{ pointerEvents: "none", zIndex: 30 }}>
      {comments.map((c, i) => {
        const s = spring({ frame: frame - c.at, fps, config: { damping: 14, stiffness: 130 } });
        // each new comment pushes the previous one up
        const lift = comments
          .slice(i + 1)
          .filter((n) => frame >= n.at)
          .reduce((acc, n) => {
            const ns = spring({ frame: frame - n.at, fps, config: { damping: 14, stiffness: 130 } });
            return acc + ns * 120;
          }, 0);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 44,
              top: y - lift,
              display: "flex",
              alignItems: "center",
              gap: 16,
              maxWidth: 640,
              borderRadius: 99,
              background: "rgba(10,10,9,0.88)",
              border: "2px solid rgba(255,255,255,0.14)",
              padding: "14px 28px 14px 14px",
              boxShadow: "0 18px 60px rgba(0,0,0,0.5)",
              opacity: s * interpolate(frame - c.at, [80, 110], [1, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              transform: `translateX(${(1 - s) * -80}px)`,
            }}
          >
            <span
              style={{
                width: 56,
                height: 56,
                borderRadius: 99,
                background: `linear-gradient(140deg, ${T.lime}, #86b31c)`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontFamily: T.body,
                fontWeight: 900,
                fontSize: 22,
                color: T.limeInk,
                flexShrink: 0,
              }}
            >
              {c.name.slice(0, 1).toUpperCase()}
            </span>
            <span style={{ fontFamily: T.body, fontWeight: 700, fontSize: 26, color: T.fg, lineHeight: 1.2 }}>
              <span style={{ color: T.fg3, fontWeight: 800 }}>{c.name}</span> {c.text}
            </span>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
