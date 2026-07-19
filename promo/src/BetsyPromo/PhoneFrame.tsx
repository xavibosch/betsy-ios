import React from "react";
import { useVideoConfig } from "remotion";
import { T } from "./theme";

// Shared iPhone chrome used by every phone-demo scene.
export const PhoneFrame: React.FC<{ children: React.ReactNode; style?: React.CSSProperties }> = ({
  children,
  style,
}) => {
  const { width } = useVideoConfig();
  const phoneW = 660;
  const phoneH = 1345;
  return (
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
        zIndex: 2,
        ...style,
      }}
    >
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
        {children}
      </div>
    </div>
  );
};

// Status bar reused across every screen recreation.
export const StatusBar: React.FC<{ fg?: string; fg3?: string; lime?: string }> = ({
  fg = "#f4f4ee",
  fg3 = "#8a8a85",
  lime = "#c9f73a",
}) => (
  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
    <span style={{ fontFamily: "inherit", fontWeight: 800, fontSize: 26, color: fg }}>18:59</span>
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <span style={{ fontWeight: 800, fontSize: 22, color: fg3, letterSpacing: 2 }}>●●●</span>
      <span
        style={{
          width: 46,
          height: 22,
          borderRadius: 7,
          border: `2px solid ${fg3}`,
          display: "inline-block",
          position: "relative",
        }}
      >
        <span
          style={{
            position: "absolute",
            left: 3,
            top: 3,
            bottom: 3,
            width: "70%",
            borderRadius: 3,
            background: lime,
          }}
        />
      </span>
    </div>
  </div>
);

// A callout label that points at part of the phone — the "explanatory" layer.
export const Callout: React.FC<{
  text: string;
  x: number;
  y: number;
  enter: number;
  align?: "left" | "right";
  accent?: string;
}> = ({ text, x, y, enter, align = "left", accent = "#c9f73a" }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      maxWidth: 360,
      transform: `translateX(${align === "left" ? (1 - enter) * -60 : (1 - enter) * 60}px)`,
      opacity: enter,
      zIndex: 5,
    }}
  >
    <div
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 12,
        background: "rgba(10,10,9,0.92)",
        border: `2px solid ${accent}`,
        borderRadius: 20,
        padding: "16px 26px",
        boxShadow: `0 20px 60px rgba(0,0,0,0.5), 0 0 40px ${accent}33`,
      }}
    >
      <span style={{ color: accent, fontSize: 26 }}>●</span>
      <span style={{ fontFamily: T.body, fontWeight: 800, fontSize: 28, color: "#f4f4ee" }}>
        {text}
      </span>
    </div>
  </div>
);
