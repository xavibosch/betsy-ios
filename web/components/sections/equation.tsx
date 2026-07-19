"use client";

import { motion } from "framer-motion";
import { Reveal } from "@/components/fx";
import { useCopy } from "@/lib/i18n";

/* ---------- The differential, in 5 seconds ---------- */
export default function Equation() {
  const c = useCopy().equation;

  return (
    <section className="relative overflow-hidden py-28 md:py-40">
      <div
        aria-hidden
        className="absolute inset-0"
        style={{ background: "radial-gradient(900px 500px at 50% 50%, rgba(201,247,58,0.06), transparent 65%)" }}
      />
      <div className="relative mx-auto max-w-6xl px-5 text-center">
        <Reveal>
          <p className="eyebrow mb-3">{c.eyebrow}</p>
          <h2 className="display text-[clamp(32px,4.5vw,56px)] text-fg2">{c.h2}</h2>
        </Reveal>

        <div className="mt-14 flex flex-col items-center justify-center gap-2 md:flex-row md:gap-6">
          <Term word={c.terms[0].word} caption={c.terms[0].caption} delay={0.1} />
          <Operator sign="+" delay={0.3} />
          <Term word={c.terms[1].word} caption={c.terms[1].caption} delay={0.45} />
          <Operator sign="−" delay={0.65} tone="arena" />
          <Term word={c.terms[2].word} caption={c.terms[2].caption} delay={0.8} struck />
        </div>

        <Reveal delay={0.2}>
          <div className="mt-10 flex flex-col items-center gap-2 md:mt-14">
            <motion.span
              initial={{ scaleY: 0 }}
              whileInView={{ scaleY: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.9, duration: 0.4 }}
              className="hidden h-10 w-px bg-line md:block"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.85 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 1.0, duration: 0.6, type: "spring", stiffness: 90 }}
            >
              <span className="display block text-[clamp(72px,12vw,150px)] leading-none text-lime drop-shadow-[0_0_40px_rgba(201,247,58,0.35)]">
                = {c.result}
              </span>
              <span className="font-mono text-[12px] uppercase tracking-[0.3em] text-fg2">
                {c.resultCaption}
              </span>
            </motion.div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

function Term({ word, caption, delay, struck }: { word: string; caption: string; delay: number; struck?: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay, duration: 0.55, ease: [0.2, 0.8, 0.2, 1] }}
      className="group flex flex-col items-center"
    >
      <span className={`display relative text-[clamp(44px,6.5vw,84px)] leading-none ${struck ? "text-fg3" : "text-fg"}`}>
        {word}
        {struck && (
          <motion.span
            aria-hidden
            initial={{ scaleX: 0 }}
            whileInView={{ scaleX: 1 }}
            viewport={{ once: true }}
            transition={{ delay: delay + 0.35, duration: 0.35 }}
            className="absolute left-[-4%] top-1/2 h-[5px] w-[108%] origin-left -translate-y-1/2 rounded-full bg-arena"
          />
        )}
      </span>
      <span className="mt-2 font-mono text-[10px] uppercase tracking-[0.2em] text-fg3 transition group-hover:text-fg2">
        {caption}
      </span>
    </motion.div>
  );
}

function Operator({ sign, delay, tone }: { sign: string; delay: number; tone?: "arena" }) {
  return (
    <motion.span
      initial={{ opacity: 0, scale: 0.4 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true }}
      transition={{ delay, type: "spring", stiffness: 200 }}
      className={`display text-[clamp(36px,5vw,64px)] leading-none ${tone === "arena" ? "text-arena" : "text-lime"}`}
    >
      {sign}
    </motion.span>
  );
}
