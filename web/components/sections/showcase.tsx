"use client";

import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Reveal, Tilt } from "@/components/fx";
import { PhoneFrame, ScreenShot } from "@/components/phone";
import { useCopy } from "@/lib/i18n";

/* ---------- Product bento ---------- */
const BASE = [
  { n: "Marc", p: 1320 },
  { n: "Xavi", p: 1240, me: true },
  { n: "Júlia", p: 1185 },
  { n: "Pau", p: 990 },
];

function LiveStandings() {
  const c = useCopy().product.live;
  const [rows, setRows] = useState(BASE);
  useEffect(() => {
    const id = setInterval(() => {
      setRows((prev) => {
        // restart the race once the runaway leader kills the drama
        if (prev[0].p > 2400) return BASE;
        const next = prev.map((r) => ({ ...r, p: r.p + (r.me ? 90 + Math.random() * 60 : Math.random() * 55) }));
        return [...next].sort((a, b) => b.p - a.p);
      });
    }, 2200);
    return () => clearInterval(id);
  }, []);

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <span className="eyebrow">{c.league}</span>
        <span className="live-dot" />
      </div>
      <div className="flex flex-col gap-2">
        {rows.map((r, i) => (
          <motion.div
            layout
            key={r.n}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className={`flex items-center gap-3 rounded-xl border px-4 py-2.5 ${
              r.me ? "border-lime/50 bg-lime/10" : "border-line bg-bg1"
            }`}
          >
            <span className={`display w-6 text-[20px] ${i === 0 ? "text-lime" : "text-fg3"}`}>{i + 1}</span>
            <span className="text-[13px] font-bold text-fg">{r.n} {i === 0 ? "👑" : ""}</span>
            <span className="ml-auto font-mono text-[12px] font-black text-fg">
              {Math.round(r.p).toLocaleString("es-ES")}
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

export function Product() {
  const c = useCopy().product;
  return (
    <section id="producto" className="relative mx-auto max-w-7xl px-5 py-28 md:py-36">
      <Reveal>
        <p className="eyebrow mb-4">{c.eyebrow}</p>
        <h2 className="display text-[clamp(40px,6vw,84px)] text-fg">
          {c.h2a}<br />
          <span className="text-lime">{c.h2b}</span>
        </h2>
      </Reveal>

      <div className="mt-16 grid gap-4 lg:grid-cols-3">
        {/* Terminal — tall cell with real phone */}
        <Reveal className="lg:row-span-2">
          <Tilt max={5} className="h-full">
            <div className="glass group flex h-full flex-col overflow-hidden rounded-3xl p-7 transition-colors hover:border-lime/30">
              <h3 className="text-[19px] font-extrabold text-fg">{c.terminal.title}</h3>
              <p className="mt-2 text-[13px] leading-relaxed text-fg3 group-hover:text-fg2">{c.terminal.desc}</p>
              <div className="relative mx-auto mt-8 w-[240px] flex-1">
                <div className="rounded-[36px] border border-white/12 bg-[#050505] p-[8px] shadow-[0_40px_90px_rgba(0,0,0,0.6)]">
                  <div className="relative aspect-[9/17] w-full overflow-hidden rounded-[28px]">
                    <ScreenShot src="/screens/mercados.png" alt={c.terminal.alt} />
                  </div>
                </div>
              </div>
            </div>
          </Tilt>
        </Reveal>

        {/* Live standings — wide cell */}
        <Reveal delay={0.08} className="lg:col-span-2">
          <div className="glass group h-full rounded-3xl p-7 transition-colors hover:border-lime/30">
            <div className="grid items-center gap-8 md:grid-cols-2">
              <div>
                <h3 className="text-[19px] font-extrabold text-fg">{c.live.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-fg3 group-hover:text-fg2">{c.live.desc}</p>
              </div>
              <LiveStandings />
            </div>
          </div>
        </Reveal>

        {/* Arena mini */}
        <Reveal delay={0.14}>
          <div className="glass group h-full rounded-3xl border-arena/15 p-7 transition-colors hover:border-arena/40">
            <h3 className="text-[19px] font-extrabold text-fg">{c.arena.title}</h3>
            <p className="mt-2 text-[13px] leading-relaxed text-fg3 group-hover:text-fg2">{c.arena.desc}</p>
            <div className="mt-6 flex items-center justify-center gap-5">
              <span className="flex h-14 w-14 items-center justify-center rounded-full border border-line bg-bg2 text-[13px] font-black text-fg">XB</span>
              <motion.span
                animate={{ scale: [1, 1.12, 1] }}
                transition={{ repeat: Infinity, duration: 1.8 }}
                className="display text-[34px] text-arena"
              >
                VS
              </motion.span>
              <span className="flex h-14 w-14 items-center justify-center rounded-full border border-line bg-bg2 text-[13px] font-black text-fg">MA</span>
            </div>
          </div>
        </Reveal>

        {/* Player props */}
        <Reveal delay={0.2}>
          <div className="glass group h-full rounded-3xl p-7 transition-colors hover:border-lime/30">
            <h3 className="text-[19px] font-extrabold text-fg">{c.props.title}</h3>
            <p className="mt-2 text-[13px] leading-relaxed text-fg3 group-hover:text-fg2">{c.props.desc}</p>
            <div className="mt-6 flex flex-wrap gap-2">
              {c.ticker.slice(6, 14).map((t) => (
                <span key={t} className="rounded-full border border-line bg-bg2 px-3 py-1.5 text-[11px] font-bold text-fg2">
                  {t}
                </span>
              ))}
            </div>
          </div>
        </Reveal>
      </div>

      {/* Markets ticker */}
      <Reveal delay={0.1} className="mt-14 -mx-5">
        <div className="relative overflow-hidden border-y border-line bg-bg1/60 py-5 backdrop-blur">
          <div className="marquee flex w-max gap-3 pr-3">
            {[...c.ticker, ...c.ticker].map((t, i) => (
              <span key={i} className="whitespace-nowrap rounded-full border border-line bg-bg2 px-5 py-2 text-[13px] font-bold text-fg2">
                {t}
              </span>
            ))}
          </div>
        </div>
      </Reveal>
    </section>
  );
}

/* ---------- Arena · interactive ---------- */
export function Arena() {
  const c = useCopy().arena;
  const [fight, setFight] = useState(false);
  return (
    <section id="arena" className="relative overflow-hidden py-28 md:py-40">
      <div
        aria-hidden
        className="absolute inset-0"
        style={{ background: "radial-gradient(900px 500px at 50% 20%, rgba(255,77,90,0.10), transparent 65%)" }}
      />
      <div className="relative mx-auto max-w-5xl px-5 text-center">
        <Reveal>
          <p className="eyebrow mb-4 text-arena">{c.eyebrow}</p>
          <h2 className="display text-[clamp(48px,7vw,100px)] text-fg">
            {c.h2a}<br /><span className="text-arena">{c.h2b}</span>
          </h2>
          <p className="mx-auto mt-6 max-w-xl text-lg text-fg2">{c.sub}</p>
        </Reveal>

        <Reveal delay={0.15}>
          <div className="glass-deep mx-auto mt-14 max-w-2xl rounded-[32px] p-8 md:p-12">
            <div className="flex items-center justify-between">
              <Fighter initials="XB" name={c.p1.name} picks={c.p1.picks} win={fight} />
              <motion.div
                animate={fight ? { scale: [1, 1.6, 1], rotate: [0, -6, 6, 0] } : { scale: [1, 1.08, 1] }}
                transition={fight ? { duration: 0.7 } : { repeat: Infinity, duration: 1.8 }}
                className="display text-[clamp(40px,7vw,72px)] text-arena"
              >
                VS
              </motion.div>
              <Fighter initials="MA" name={c.p2.name} picks={c.p2.picks} lose={fight} />
            </div>

            <div className="mx-auto mt-8 max-w-xs rounded-2xl border border-arena/40 bg-arena/[0.08] p-5">
              <div className="eyebrow">{c.inPlay}</div>
              <div className="display text-[54px] text-arena">
                <AnimatePresence mode="popLayout">
                  <motion.span
                    key={fight ? "win" : "pot"}
                    initial={{ y: 24, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={{ y: -24, opacity: 0 }}
                    className="inline-block"
                  >
                    {fight ? "+200" : "200"}
                  </motion.span>
                </AnimatePresence>
                <span className="text-[22px]"> pts</span>
              </div>
              <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-fg3">
                {fight ? c.winnerDone : c.winner}
              </div>
            </div>

            <button
              onClick={() => setFight((f) => !f)}
              className="btn-primary mt-8"
              style={{ background: "var(--arena)", color: "#fff" }}
            >
              {fight ? c.again : c.simulate}
            </button>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

function Fighter({ initials, name, picks, win, lose }: { initials: string; name: string; picks: string; win?: boolean; lose?: boolean }) {
  return (
    <motion.div
      animate={win ? { scale: 1.08, y: -6 } : lose ? { scale: 0.92, opacity: 0.45 } : { scale: 1, y: 0, opacity: 1 }}
      transition={{ type: "spring", stiffness: 200, damping: 16 }}
      className="flex w-[120px] flex-col items-center gap-2"
    >
      <span
        className={`flex h-16 w-16 items-center justify-center rounded-full border text-[16px] font-black md:h-20 md:w-20 ${
          win ? "border-lime bg-lime/15 text-lime" : "border-line bg-bg2 text-fg"
        }`}
      >
        {initials}
      </span>
      <span className="text-[15px] font-extrabold text-fg">{name} {win ? "🏆" : ""}</span>
      <span className="text-center font-mono text-[9px] uppercase tracking-wide text-fg3">{picks}</span>
    </motion.div>
  );
}
