"use client";

import { Reveal, Counter, Particles } from "@/components/fx";
import { useCopy } from "@/lib/i18n";

/* ---------- Final CTA ---------- */
export function FinalCTA() {
  const c = useCopy().cta;
  return (
    <section id="cta" className="relative overflow-hidden py-32 md:py-48">
      <div
        aria-hidden
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(700px 420px at 20% 0%, rgba(201,247,58,0.10), transparent 60%), radial-gradient(700px 420px at 80% 0%, rgba(201,247,58,0.10), transparent 60%), radial-gradient(1000px 600px at 50% 110%, rgba(201,247,58,0.07), transparent 60%)",
        }}
      />
      <div className="pitch absolute inset-0" aria-hidden />
      <Particles count={18} />

      <div className="relative mx-auto max-w-5xl px-5 text-center">
        <Reveal>
          <h2 className="display text-[clamp(56px,11vw,160px)] text-fg">
            {c.h2a}<br />{c.h2b} <span className="text-lime">{c.h2you}</span>
          </h2>
          <p className="mx-auto mt-6 max-w-xl text-lg text-fg2">{c.sub}</p>
        </Reveal>
        <Reveal delay={0.15}>
          <div className="mt-10 flex flex-wrap justify-center gap-4">
            <a href="mailto:betsy.support@gmail.com?subject=Betsy%20Beta" className="btn-primary text-lg">
              {c.primary}
            </a>
            <a href="#demo" className="btn-ghost text-lg">{c.secondary}</a>
          </div>
          <p className="mt-8 font-mono text-[11px] uppercase tracking-[0.25em] text-fg3">
            {c.smallprint}
          </p>
        </Reveal>

        <Reveal delay={0.2}>
          <div className="glass-deep mt-16 grid grid-cols-2 gap-6 rounded-3xl p-8 md:grid-cols-4">
            {c.stats.map(([v, l]) => {
              const num = parseInt(v, 10);
              const suffix = v.replace(String(num), "");
              return (
                <div key={l} className="text-center">
                  <div className="display text-[clamp(36px,5vw,56px)] text-lime">
                    {Number.isNaN(num) ? v : <Counter to={num} suffix={suffix} />}
                  </div>
                  <div className="eyebrow mt-1">{l}</div>
                </div>
              );
            })}
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ---------- Footer ---------- */
export function Footer() {
  const c = useCopy().footer;
  return (
    <footer className="border-t border-line px-5 py-12">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-6 md:flex-row">
        <div className="flex flex-col items-center gap-4 md:items-start">
          <span className="display text-[24px] text-fg">
            BET<span className="text-lime">SY</span>
          </span>
          <div className="flex gap-5 text-[12px] font-semibold text-fg3">
            <a href="/soporte" className="transition hover:text-fg">{c.support}</a>
            <a href="/terminos" className="transition hover:text-fg">{c.terms}</a>
            <a href="/privacidad" className="transition hover:text-fg">{c.privacy}</a>
          </div>
        </div>
        <p className="max-w-md text-center text-[12px] leading-relaxed text-fg3 md:text-right">
          {c.disclaimer}
        </p>
      </div>
    </footer>
  );
}
