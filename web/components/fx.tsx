"use client";

import { ReactNode, useEffect, useRef, useState } from "react";
import { motion, useInView, useMotionValue, useSpring, useTransform } from "framer-motion";

/* Reveal on scroll */
export function Reveal({
  children,
  delay = 0,
  y = 28,
  className,
}: {
  children: ReactNode;
  delay?: number;
  y?: number;
  className?: string;
}) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.7, delay, ease: [0.21, 0.7, 0.18, 1] }}
    >
      {children}
    </motion.div>
  );
}

/* Animated counter (GSAP-free, springy) */
export function Counter({ to, suffix = "", className }: { to: number; suffix?: string; className?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true, margin: "-40px" });
  const mv = useMotionValue(0);
  const spring = useSpring(mv, { stiffness: 60, damping: 18 });
  const [val, setVal] = useState(0);
  useEffect(() => {
    if (inView) mv.set(to);
  }, [inView, mv, to]);
  useEffect(() => spring.on("change", (v) => setVal(Math.round(v))), [spring]);
  return (
    <span ref={ref} className={className}>
      {val.toLocaleString("es-ES")}
      {suffix}
    </span>
  );
}

/* 3D tilt card that follows the mouse */
export function Tilt({ children, max = 10, className }: { children: ReactNode; max?: number; className?: string }) {
  const x = useMotionValue(0.5);
  const y = useMotionValue(0.5);
  const rX = useSpring(useTransform(y, [0, 1], [max, -max]), { stiffness: 160, damping: 18 });
  const rY = useSpring(useTransform(x, [0, 1], [-max, max]), { stiffness: 160, damping: 18 });
  return (
    <motion.div
      className={className}
      style={{ rotateX: rX, rotateY: rY, transformStyle: "preserve-3d", perspective: 900 }}
      onMouseMove={(e) => {
        const r = e.currentTarget.getBoundingClientRect();
        x.set((e.clientX - r.left) / r.width);
        y.set((e.clientY - r.top) / r.height);
      }}
      onMouseLeave={() => {
        x.set(0.5);
        y.set(0.5);
      }}
    >
      {children}
    </motion.div>
  );
}

/* Stadium particles */
export function Particles({ count = 26 }: { count?: number }) {
  const [seeds, setSeeds] = useState<{ l: number; d: number; s: number; o: number }[]>([]);
  useEffect(() => {
    setSeeds(
      Array.from({ length: count }, () => ({
        l: Math.random() * 100,
        d: 9 + Math.random() * 16,
        s: Math.random() * 14,
        o: 0.2 + Math.random() * 0.5,
      }))
    );
  }, [count]);
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
      {seeds.map((p, i) => (
        <span
          key={i}
          className="particle"
          style={{
            left: `${p.l}%`,
            animationDuration: `${p.d}s`,
            animationDelay: `-${p.s}s`,
            ["--p-op" as never]: p.o,
          }}
        />
      ))}
    </div>
  );
}

/* Mouse-reactive glow spot */
export function GlowSpot({ className }: { className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const onMove = (e: MouseEvent) => {
      const r = el.getBoundingClientRect();
      el.style.setProperty("--mx", `${e.clientX - r.left}px`);
      el.style.setProperty("--my", `${e.clientY - r.top}px`);
    };
    el.addEventListener("mousemove", onMove);
    return () => el.removeEventListener("mousemove", onMove);
  }, []);
  return (
    <div
      ref={ref}
      aria-hidden
      className={`pointer-events-auto absolute inset-0 ${className ?? ""}`}
      style={{
        background:
          "radial-gradient(420px 420px at var(--mx, 50%) var(--my, 30%), rgba(201,247,58,0.07), transparent 70%)",
      }}
    />
  );
}
