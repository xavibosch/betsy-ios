"use client";

import { motion, useScroll, useTransform } from "framer-motion";
import { useCopy, useLang, Lang } from "@/lib/i18n";

function LangToggle() {
  const { lang, setLang } = useLang();
  const opts: Lang[] = ["es", "en"];
  return (
    <div className="flex items-center rounded-full border border-line bg-bg1/80 p-1" role="group" aria-label="Language">
      {opts.map((l) => (
        <button
          key={l}
          onClick={() => setLang(l)}
          aria-pressed={lang === l}
          className={`rounded-full px-3 py-1 font-mono text-[11px] font-bold uppercase tracking-wider transition ${
            lang === l ? "bg-lime text-lime-ink" : "text-fg3 hover:text-fg"
          }`}
        >
          {l}
        </button>
      ))}
    </div>
  );
}

export default function Nav() {
  const c = useCopy();
  const { scrollY } = useScroll();
  const bg = useTransform(scrollY, [0, 120], ["rgba(10,10,9,0)", "rgba(10,10,9,0.75)"]);
  const border = useTransform(scrollY, [0, 120], ["rgba(42,42,39,0)", "rgba(42,42,39,1)"]);
  return (
    <motion.header
      style={{ backgroundColor: bg, borderColor: border }}
      className="fixed inset-x-0 top-0 z-50 border-b backdrop-blur-xl"
    >
      <nav className="mx-auto flex max-w-7xl items-center justify-between gap-3 px-5 py-4">
        <a href="#" className="display text-[26px] text-fg">
          BET<span className="text-lime">SY</span>
        </a>
        <div className="hidden items-center gap-7 text-[13px] font-semibold text-fg2 lg:flex">
          <a href="#como" className="transition hover:text-fg">{c.nav.how}</a>
          <a href="#producto" className="transition hover:text-fg">{c.nav.product}</a>
          <a href="#arena" className="transition hover:text-fg">{c.nav.arena}</a>
          <a href="#demo" className="transition hover:text-fg">{c.nav.demo}</a>
        </div>
        <div className="flex items-center gap-3">
          <LangToggle />
          <a
            href="mailto:betsy.support@gmail.com?subject=Betsy%20Beta"
            className="hidden rounded-full bg-lime px-5 py-2.5 text-[13px] font-extrabold text-lime-ink transition hover:shadow-[0_8px_30px_rgba(201,247,58,0.4)] sm:block"
          >
            {c.nav.cta}
          </a>
        </div>
      </nav>
    </motion.header>
  );
}
