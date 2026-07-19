import Link from "next/link";
import { ReactNode } from "react";

export default function LegalShell({ title, updated, children }: { title: string; updated: string; children: ReactNode }) {
  return (
    <main className="mx-auto max-w-3xl px-5 py-20">
      <Link href="/" className="display text-[22px] text-fg">BET<span className="text-lime">SY</span></Link>
      <h1 className="display mt-10 text-[clamp(40px,7vw,68px)] text-fg">{title}</h1>
      <p className="eyebrow mt-3">Última actualización · {updated}</p>
      <div className="legal mt-10 flex flex-col gap-6 text-[15px] leading-relaxed text-fg2">
        {children}
      </div>
      <Link href="/" className="btn-ghost mt-14">← Volver a Betsy</Link>
    </main>
  );
}

export function H({ children }: { children: ReactNode }) {
  return <h2 className="display mt-6 text-[26px] text-fg">{children}</h2>;
}
