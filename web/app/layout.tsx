import type { Metadata } from "next";
import { Inter, Bebas_Neue, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import SmoothScroll from "@/components/smooth-scroll";
import { LangProvider } from "@/lib/i18n";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const bebas = Bebas_Neue({ weight: "400", subsets: ["latin"], variable: "--font-bebas" });
const jbmono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jbmono" });

export const metadata: Metadata = {
  title: "Betsy — Settle who knows sports for real",
  description:
    "Private leagues with your friends: bet virtual points on real matches, climb the ranking and duel 1v1 in the Arena. All the thrill of betting, zero real money. · Ligas privadas con puntos virtuales: predice partidos reales, sube en el ranking y reta 1v1. Sin dinero real.",
  openGraph: {
    title: "Betsy — Fantasy + Betting − Money",
    description:
      "The social prediction game. Private leagues, virtual points, real matches, 1v1 duels. No real money — just bragging rights.",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={`${inter.variable} ${bebas.variable} ${jbmono.variable}`}>
      <body>
        <LangProvider>
          <SmoothScroll>{children}</SmoothScroll>
        </LangProvider>
      </body>
    </html>
  );
}
