"use client";

import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import { PhoneFrame, ScreenShot } from "@/components/phone";
import { Particles, GlowSpot } from "@/components/fx";
import { useCopy } from "@/lib/i18n";

export default function Hero() {
  const c = useCopy().hero;
  const mx = useMotionValue(0.5);
  const my = useMotionValue(0.5);
  const phoneX = useSpring(useTransform(mx, [0, 1], [-16, 16]), { stiffness: 60, damping: 16 });
  const phoneY = useSpring(useTransform(my, [0, 1], [-10, 10]), { stiffness: 60, damping: 16 });
  const phoneR = useSpring(useTransform(mx, [0, 1], [-4, 4]), { stiffness: 60, damping: 16 });
  const cardA = useSpring(useTransform(mx, [0, 1], [22, -22]), { stiffness: 40, damping: 16 });
  const cardB = useSpring(useTransform(mx, [0, 1], [-26, 26]), { stiffness: 40, damping: 16 });

  return (
    <section
      onMouseMove={(e) => {
        mx.set(e.clientX / window.innerWidth);
        my.set(e.clientY / window.innerHeight);
      }}
      className="stadium grain relative flex min-h-svh flex-col items-center overflow-hidden px-5 pt-32 pb-16"
    >
      <div className="pitch absolute inset-0" aria-hidden />
      <Particles />
      <GlowSpot />

      <div className="relative z-10 mx-auto grid w-full max-w-7xl items-center gap-14 lg:grid-cols-[1.15fr_1fr]">
        <div>
          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="mb-6 inline-flex items-center gap-2 rounded-full border border-lime/30 bg-lime/[0.08] px-4 py-2"
          >
            <span className="live-dot" />
            <span className="font-mono text-[11px] uppercase tracking-[0.2em] text-lime">
              {c.badge}
            </span>
          </motion.div>

          <h1 className="display text-[clamp(56px,9vw,124px)] text-fg">
            <Line d={0.05}>{c.h1a}</Line>
            <Line d={0.15}>
              {c.h1b1} <span className="text-lime">{c.h1b2}</span>
            </Line>
            <Line d={0.25}>{c.h1c}</Line>
          </h1>

          <motion.p
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.45, duration: 0.7 }}
            className="mt-6 max-w-xl text-lg text-fg2"
          >
            {c.sub}
            <span className="text-fg3">{c.sub2}</span>
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6, duration: 0.7 }}
            className="mt-9 flex flex-wrap gap-4"
          >
            <a href="mailto:betsy.support@gmail.com?subject=Betsy%20Beta" className="btn-primary">
              {c.ctaPrimary}
            </a>
            <a href="#demo" className="btn-ghost">{c.ctaSecondary}</a>
          </motion.div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.9 }}
            className="mt-12 flex flex-wrap gap-8"
          >
            {c.stats.map(([v, l]) => (
              <div key={l}>
                <div className="display text-[34px] text-fg">{v}</div>
                <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-fg3">{l}</div>
              </div>
            ))}
          </motion.div>
        </div>

        <div className="relative mx-auto" style={{ perspective: 1100 }}>
          <motion.div style={{ x: cardA, y: phoneY }} className="floaty-slow absolute -left-24 top-12 z-20 hidden lg:block">
            <div className="glass rounded-2xl p-4">
              <div className="font-mono text-[9px] uppercase tracking-widest text-fg3">{c.cardLeagueLabel}</div>
              <div className="mt-1 text-[13px] font-black text-fg">{c.cardLeagueRow}</div>
              <div className="font-mono text-[11px] font-black text-lime">1.480 pts</div>
            </div>
          </motion.div>
          <motion.div style={{ x: cardB, y: phoneX }} className="floaty absolute -right-20 bottom-24 z-20 hidden lg:block">
            <div className="glass rounded-2xl p-4">
              <div className="font-mono text-[9px] uppercase tracking-widest text-fg3">{c.cardBetLabel}</div>
              <div className="mt-1 text-[13px] font-black text-fg">{c.cardBetRow}</div>
              <div className="font-mono text-[11px] font-black text-lime">+144 pts</div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 60, rotate: -2 }}
            animate={{ opacity: 1, y: 0, rotate: 0 }}
            transition={{ delay: 0.35, duration: 0.9, ease: [0.2, 0.8, 0.2, 1] }}
            style={{ x: phoneX, y: phoneY, rotateY: phoneR }}
          >
            <PhoneFrame>
              <ScreenShot src="/screens/home.png" alt={c.phoneAlt} priority />
            </PhoneFrame>
          </motion.div>

          <div
            aria-hidden
            className="absolute -inset-10 -z-10 rounded-full opacity-60 blur-3xl"
            style={{ background: "radial-gradient(closest-side, rgba(201,247,58,0.16), transparent)" }}
          />
        </div>
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.4 }}
        className="absolute bottom-6 left-1/2 -translate-x-1/2 font-mono text-[10px] uppercase tracking-[0.3em] text-fg3"
      >
        {c.scroll}
      </motion.div>
    </section>
  );
}

function Line({ children, d }: { children: React.ReactNode; d: number }) {
  return (
    <span className="block overflow-hidden">
      <motion.span
        className="block"
        initial={{ y: "110%" }}
        animate={{ y: 0 }}
        transition={{ delay: d, duration: 0.8, ease: [0.2, 0.8, 0.2, 1] }}
      >
        {children}
      </motion.span>
    </span>
  );
}
