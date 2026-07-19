import React from "react";
import { spring, useVideoConfig } from "remotion";
import { T } from "./theme";
import { StatusBar } from "./PhoneFrame";

// Recreation of the "create a league" flow: name it, pick sports, set balance, get a code.
export const PhoneCreateLeague: React.FC<{ t: number }> = ({ t }) => {
  const { fps } = useVideoConfig();

  const titleIn = spring({ frame: t, fps, config: { damping: 16, stiffness: 110 } });
  const nameIn = spring({ frame: t - 10, fps, config: { damping: 16, stiffness: 110 } });
  // "typing" reveal of the league name
  const fullName = "MAFIA FC";
  const typedChars = Math.max(0, Math.min(fullName.length, Math.floor((t - 20) / 2.6)));
  const typed = fullName.slice(0, typedChars);
  const caretOn = Math.floor(t / 9) % 2 === 0 && typedChars < fullName.length;

  const chip = (delay: number) => spring({ frame: t - delay, fps, config: { damping: 15, stiffness: 130 } });
  const chip1 = chip(46);
  const chip2 = chip(53);
  const chip3 = chip(60);

  const balanceIn = spring({ frame: t - 74, fps, config: { damping: 16, stiffness: 110 } });
  const ctaIn = spring({ frame: t - 92, fps, config: { damping: 15, stiffness: 120 } });
  const ctaPulse = 1 + Math.sin(t / 8) * 0.02;

  const chipStyle = (active: number): React.CSSProperties => ({
    borderRadius: 18,
    border: `2px solid ${active > 0.5 ? "rgba(201,247,58,0.55)" : T.line}`,
    background: active > 0.5 ? "rgba(201,247,58,0.1)" : T.bg2,
    padding: "16px 22px",
    fontFamily: T.body,
    fontWeight: 800,
    fontSize: 24,
    color: active > 0.5 ? T.lime : T.fg2,
    transform: `scale(${0.85 + Math.min(active, 1) * 0.15})`,
    opacity: Math.max(active, 0.35),
  });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: T.bg,
        display: "flex",
        flexDirection: "column",
        padding: "68px 34px 40px",
        gap: 30,
        overflow: "hidden",
      }}
    >
      <StatusBar />

      <div
        style={{
          fontFamily: T.mono,
          fontWeight: 800,
          fontSize: 21,
          letterSpacing: 4,
          color: T.fg3,
          opacity: titleIn,
          transform: `translateY(${(1 - titleIn) * 20}px)`,
        }}
      >
        NUEVA LIGA
      </div>

      {/* name input */}
      <div
        style={{
          borderRadius: 24,
          border: `2px solid ${typedChars > 0 ? "rgba(201,247,58,0.5)" : T.line}`,
          background: T.bg1,
          padding: "26px 28px",
          opacity: nameIn,
          transform: `translateY(${(1 - nameIn) * 30}px)`,
        }}
      >
        <span style={{ fontFamily: T.display, fontSize: 46, letterSpacing: 1, color: T.fg }}>
          {typed}
          <span style={{ opacity: caretOn ? 1 : 0, color: T.lime }}>|</span>
        </span>
      </div>

      {/* sport chips */}
      <div style={{ display: "flex", gap: 14, marginTop: 36 }}>
        <div style={chipStyle(chip1)}>⚽ Mundial</div>
        <div style={chipStyle(chip2)}>⚽ LaLiga</div>
        <div style={chipStyle(chip3)}>🏀 NBA</div>
      </div>

      {/* starting balance */}
      <div
        style={{
          borderRadius: 24,
          border: `2px solid ${T.line}`,
          background: T.bg1,
          padding: "24px 28px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          opacity: balanceIn,
          transform: `translateY(${(1 - balanceIn) * 30}px)`,
        }}
      >
        <span style={{ fontFamily: T.mono, fontWeight: 800, fontSize: 20, letterSpacing: 2, color: T.fg3 }}>
          SALDO INICIAL
        </span>
        <span style={{ fontFamily: T.display, fontSize: 44, color: T.lime }}>1.000 pts</span>
      </div>

      <div style={{ flex: 1 }} />

      {/* CTA */}
      <div
        style={{
          transform: `translateY(${(1 - ctaIn) * 70}px) scale(${ctaPulse})`,
          opacity: ctaIn,
          borderRadius: 99,
          background: T.lime,
          padding: "26px 0",
          textAlign: "center",
          boxShadow: "0 18px 70px rgba(201,247,58,0.35)",
        }}
      >
        <span style={{ fontFamily: T.body, fontWeight: 900, fontSize: 32, color: T.limeInk }}>
          Crear liga →
        </span>
      </div>
    </div>
  );
};
