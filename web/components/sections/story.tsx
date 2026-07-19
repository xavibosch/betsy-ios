"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { Reveal } from "@/components/fx";
import { ScreenShot } from "@/components/phone";
import { useCopy, Copy } from "@/lib/i18n";

/* ---------- The problem ---------- */
export function Problem() {
  const c = useCopy().problem;
  return (
    <section className="relative mx-auto max-w-7xl px-5 py-28 md:py-40">
      <Reveal>
        <p className="eyebrow mb-4">{c.eyebrow}</p>
        <h2 className="display max-w-4xl text-[clamp(40px,6vw,84px)] text-fg">
          {c.h2a} <span className="outline-text">{c.h2verb}</span> {c.h2b}
          <span className="text-lime">{c.h2c}</span>
        </h2>
      </Reveal>

      <div className="mt-16 grid gap-6 md:grid-cols-2">
        <Reveal delay={0.05}>
          <div className="glass-deep relative h-full overflow-hidden rounded-3xl p-8">
            <p className="eyebrow mb-6 text-arena">{c.without}</p>
            <div className="flex flex-col gap-4">
              {c.bubbles.map((q, i) => (
                <motion.div
                  key={q}
                  initial={{ opacity: 0, x: i % 2 ? 30 : -30 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.15 * i, duration: 0.5 }}
                  className={`max-w-[80%] rounded-2xl border border-line bg-bg2 px-5 py-3 text-[15px] font-semibold text-fg2 ${
                    i % 2 ? "self-end rounded-br-md" : "self-start rounded-bl-md"
                  }`}
                >
                  {q}
                </motion.div>
              ))}
            </div>
            <p className="mt-8 font-mono text-[11px] uppercase tracking-[0.25em] text-fg3">
              {c.withoutCaption}
            </p>
          </div>
        </Reveal>

        <Reveal delay={0.15}>
          <div className="glass relative h-full overflow-hidden rounded-3xl border-lime/20 p-8">
            <p className="eyebrow mb-6 text-lime">{c.with}</p>
            <div className="mx-auto w-[230px] scale-[0.97]">
              <div className="rounded-3xl border border-line bg-bg p-2">
                <div className="relative h-[360px] overflow-hidden rounded-2xl">
                  <ScreenShot src="/screens/ranking.png" alt={c.rankingAlt} />
                </div>
              </div>
            </div>
            <p className="mt-6 text-center font-mono text-[11px] uppercase tracking-[0.25em] text-lime">
              {c.withCaption}
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------- How it works · horizontal scroll-driven ---------- */
function StepVisual({ n, v }: { n: string; v: Copy["how"]["stepVisuals"] }) {
  switch (n) {
    case "01":
      return (
        <div className="glass rounded-2xl p-5">
          <div className="eyebrow mb-3">{v.newLeague}</div>
          <div className="rounded-xl border border-line bg-bg2 px-4 py-3 text-[15px] font-black text-fg">{v.leagueName}</div>
          <div className="mt-3 flex flex-wrap gap-2">
            {v.sports.map((s) => (
              <span key={s} className="rounded-full border border-lime/40 bg-lime/10 px-3 py-1 text-[11px] font-bold text-lime">{s}</span>
            ))}
          </div>
        </div>
      );
    case "02":
      return (
        <div className="glass rounded-2xl p-5 text-center">
          <div className="eyebrow mb-2">{v.codeLabel}</div>
          <div className="display text-[52px] tracking-[0.2em] text-lime">6V227F</div>
          <div className="font-mono text-[10px] uppercase tracking-widest text-fg3">{v.share}</div>
        </div>
      );
    case "03":
      return (
        <div className="glass rounded-2xl p-5">
          <div className="flex items-center justify-between text-[14px] font-black text-fg">
            <span>MEX</span><span className="rounded bg-lime/15 px-2 text-[10px] text-lime">VS</span><span>RSA</span>
          </div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            {([["1", "1.44", true], ["X", "4.50", false], ["2", "8.60", false]] as const).map(([l, val, on]) => (
              <div key={l} className={`rounded-lg border py-2 text-center ${on ? "border-fg bg-fg text-bg" : "border-line bg-bg2 text-fg"}`}>
                <div className="text-[9px] opacity-60">{l}</div>
                <div className="text-[13px] font-black">{val}</div>
              </div>
            ))}
          </div>
        </div>
      );
    case "04":
      return (
        <div className="glass relative overflow-hidden rounded-2xl p-5 text-center">
          {["+144", "+62", "+210"].map((p, i) => (
            <motion.span
              key={p}
              initial={{ y: 40, opacity: 0 }}
              whileInView={{ y: -8 * i, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.25 * i, type: "spring", stiffness: 120 }}
              className="display mx-2 inline-block text-[40px] text-lime"
            >
              {p}
            </motion.span>
          ))}
          <div className="font-mono text-[10px] uppercase tracking-widest text-fg3">{v.settle}</div>
        </div>
      );
    default:
      return (
        <div className="glass rounded-2xl p-5">
          {([["1", "Xavi", "1.480", true], ["2", "Marc", "1.320", false]] as const).map(([n2, name, pts, me]) => (
            <div
              key={name}
              className={`mb-2 flex items-center gap-3 rounded-xl border px-4 py-2.5 ${me ? "border-lime/50 bg-lime/10" : "border-line bg-bg2"}`}
            >
              <span className="display text-[18px] text-fg3">{n2}</span>
              <span className="text-[13px] font-bold text-fg">{name} {me ? "👑" : ""}</span>
              <span className="ml-auto font-mono text-[12px] font-black text-fg">{pts}</span>
            </div>
          ))}
        </div>
      );
  }
}

function StepCard({ step, v, i }: { step: Copy["how"]["steps"][number]; v: Copy["how"]["stepVisuals"]; i: number }) {
  return (
    <div className="glass-deep relative flex w-[min(560px,86vw)] shrink-0 flex-col justify-between overflow-hidden rounded-[32px] p-8 md:p-10">
      <div
        aria-hidden
        className="absolute -right-8 -top-10 select-none"
      >
        <span className="display text-[180px] leading-none outline-text opacity-60">{step.n}</span>
      </div>
      <div className="relative">
        <span className="font-mono text-[11px] uppercase tracking-[0.3em] text-lime">{step.n} / 05</span>
        <h3 className="display mt-3 text-[clamp(34px,4vw,48px)] text-fg">{step.t}</h3>
        <p className="mt-3 max-w-sm text-[15px] leading-relaxed text-fg2">{step.d}</p>
      </div>
      <motion.div
        whileHover={{ y: -6, rotate: i % 2 ? 0.6 : -0.6 }}
        transition={{ type: "spring", stiffness: 200 }}
        className="relative mt-8"
      >
        <StepVisual n={step.n} v={v} />
      </motion.div>
    </div>
  );
}

export function HowItWorks() {
  const c = useCopy().how;
  const trackRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: trackRef });
  // Translate the track so its end lines up with the viewport's end.
  const x = useTransform(scrollYProgress, (v) => `calc(${v} * (100vw - 100% - 96px))`);
  const progress = useTransform(scrollYProgress, [0, 1], ["0%", "100%"]);

  return (
    <section id="como" className="relative">
      <div className="mx-auto max-w-7xl px-5 pt-28 md:pt-40">
        <Reveal>
          <p className="eyebrow mb-4">{c.eyebrow}</p>
          <h2 className="display text-[clamp(40px,6vw,84px)] text-fg">
            {c.h2a} <span className="text-lime">{c.h2lime}</span><br />{c.h2b}
          </h2>
        </Reveal>
      </div>

      {/* Desktop: vertical scroll drives horizontal track */}
      <div ref={trackRef} className="relative hidden h-[340vh] md:block">
        <div className="sticky top-0 flex h-screen flex-col justify-center overflow-hidden">
          <motion.div style={{ x }} className="flex w-max items-stretch gap-8 pl-12">
            {c.steps.map((s, i) => (
              <StepCard key={s.n} step={s} v={c.stepVisuals} i={i} />
            ))}
          </motion.div>
          <div className="mx-auto mt-10 flex w-full max-w-7xl items-center gap-5 px-5">
            <div className="h-[3px] flex-1 overflow-hidden rounded-full bg-line">
              <motion.div style={{ width: progress }} className="h-full rounded-full bg-lime" />
            </div>
            <span className="font-mono text-[10px] uppercase tracking-[0.25em] text-fg3">{c.hint}</span>
          </div>
        </div>
      </div>

      {/* Mobile: simple vertical stack */}
      <div className="mx-auto flex max-w-7xl flex-col gap-6 px-5 pt-14 pb-10 md:hidden">
        {c.steps.map((s, i) => (
          <Reveal key={s.n} delay={0.05 * i}>
            <StepCard step={s} v={c.stepVisuals} i={i} />
          </Reveal>
        ))}
      </div>
    </section>
  );
}
