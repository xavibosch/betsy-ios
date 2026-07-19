"use client";

import { Reveal } from "@/components/fx";
import { DemoPhone } from "@/components/phone";
import { useCopy } from "@/lib/i18n";

/* ---------- Why different · Bookies vs Fantasy vs Betsy ---------- */
function Mark({ on, invert }: { on: boolean; invert?: boolean }) {
  // invert: a "true" here is bad (e.g. real money at risk)
  const good = invert ? !on : on;
  return (
    <span className={`text-[17px] ${good ? "" : "opacity-45"}`}>
      {on ? (invert ? "⚠️" : "✅") : good ? "🚫" : "—"}
    </span>
  );
}

export function Different() {
  const c = useCopy().different;
  return (
    <section className="relative mx-auto max-w-6xl px-5 py-28 md:py-36">
      <Reveal>
        <p className="eyebrow mb-4">{c.eyebrow}</p>
        <h2 className="display text-[clamp(40px,6vw,84px)] text-fg">
          {c.h2a} <span className="text-lime">{c.h2not}</span> {c.h2b}
        </h2>
        <p className="mt-5 max-w-xl text-lg text-fg2">{c.sub}</p>
      </Reveal>

      <Reveal delay={0.1}>
        <div className="mt-14 overflow-x-auto">
          <div className="glass-deep min-w-[640px] overflow-hidden rounded-3xl">
            <div className="grid grid-cols-[1.6fr_repeat(3,1fr)] items-center gap-4 border-b border-line px-6 py-4 md:px-8">
              <span />
              <span className="display text-center text-[18px] text-fg3">{c.colBookies}</span>
              <span className="display text-center text-[18px] text-fg3">{c.colFantasy}</span>
              <span className="display rounded-xl border border-lime/40 bg-lime/10 py-1.5 text-center text-[20px] text-lime">
                BETSY
              </span>
            </div>
            {c.rows.map((r, i) => (
              <Reveal key={r.label} delay={0.04 * i}>
                <div className="grid grid-cols-[1.6fr_repeat(3,1fr)] items-center gap-4 border-b border-line/60 px-6 py-4 last:border-0 md:px-8">
                  <span className="text-[14px] font-bold text-fg md:text-[15px]">{r.label}</span>
                  <span className="text-center"><Mark on={r.bookies} invert={r.invert} /></span>
                  <span className="text-center"><Mark on={r.fantasy} invert={r.invert} /></span>
                  <span className="text-center"><Mark on={r.betsy} invert={r.invert} /></span>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </Reveal>
    </section>
  );
}

/* ---------- Live demo ---------- */
export function LiveDemo() {
  const c = useCopy().demo;
  return (
    <section id="demo" className="stadium grain relative overflow-hidden py-28 md:py-40">
      <div className="relative mx-auto max-w-5xl px-5 text-center">
        <Reveal>
          <p className="eyebrow mb-4">{c.eyebrow}</p>
          <h2 className="display text-[clamp(44px,6vw,90px)] text-fg">
            {c.h2a} <span className="text-lime">{c.h2b}</span>
          </h2>
          <p className="mx-auto mt-5 max-w-lg text-lg text-fg2">{c.sub}</p>
        </Reveal>
        <Reveal delay={0.15} className="mt-14">
          <DemoPhone />
        </Reveal>
      </div>
    </section>
  );
}
