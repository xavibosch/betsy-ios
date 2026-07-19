"use client";

import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useCopy } from "@/lib/i18n";

/* ---------- Frame ---------- */
export function PhoneFrame({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div
      className={`relative w-[290px] sm:w-[320px] rounded-[46px] border border-white/12 bg-[#050505] p-[10px] shadow-[0_60px_140px_rgba(0,0,0,0.7),inset_0_1px_0_rgba(255,255,255,0.1)] ${className ?? ""}`}
    >
      <div className="absolute left-1/2 top-[18px] z-20 h-[24px] w-[92px] -translate-x-1/2 rounded-full bg-black" />
      <div className="relative aspect-[9/19.4] w-full overflow-hidden rounded-[36px] bg-bg">
        {children}
      </div>
    </div>
  );
}

/* ---------- Real screenshot fill ---------- */
export function ScreenShot({ src, alt, priority = false }: { src: string; alt: string; priority?: boolean }) {
  // eslint-disable-next-line @next/next/no-img-element
  return (
    <img
      src={src}
      alt={alt}
      draggable={false}
      loading={priority ? "eager" : "lazy"}
      className="absolute inset-0 h-full w-full select-none object-cover object-top"
    />
  );
}

/* ---------- Interactive demo phone (real screens) ---------- */
const SCREEN_IDS = ["home", "jugar", "mercados", "arena", "ranking", "betslip"] as const;

export function DemoPhone() {
  const c = useCopy().demo;
  const [idx, setIdx] = useState(0);
  const go = (d: number) => setIdx((p) => (p + d + SCREEN_IDS.length) % SCREEN_IDS.length);
  const id = SCREEN_IDS[idx];
  return (
    <div className="flex flex-col items-center gap-5">
      <PhoneFrame>
        <AnimatePresence mode="popLayout" initial={false}>
          <motion.div
            key={id}
            className="absolute inset-0"
            initial={{ x: 80, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: -80, opacity: 0 }}
            transition={{ duration: 0.32, ease: [0.3, 0.8, 0.3, 1] }}
            drag="x"
            dragConstraints={{ left: 0, right: 0 }}
            dragElastic={0.25}
            onDragEnd={(_, info) => {
              if (info.offset.x < -60) go(1);
              else if (info.offset.x > 60) go(-1);
            }}
          >
            <ScreenShot src={`/screens/${id}.png`} alt={c.screens[id]} priority />
          </motion.div>
        </AnimatePresence>
      </PhoneFrame>
      <div className="flex flex-wrap justify-center gap-2">
        {SCREEN_IDS.map((s, i) => (
          <button
            key={s}
            onClick={() => setIdx(i)}
            className={`rounded-full px-4 py-2 text-[12px] font-bold transition ${
              i === idx ? "bg-lime text-lime-ink" : "border border-line bg-bg1 text-fg3 hover:text-fg"
            }`}
          >
            {c.screens[s]}
          </button>
        ))}
      </div>
      <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-fg3">{c.swipe}</p>
    </div>
  );
}
