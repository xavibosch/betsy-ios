"use client";

import { createContext, ReactNode, useContext, useEffect, useState } from "react";

/* ============================================================
   Betsy · bilingual copy (ES base · EN mirror, typed 1:1)
   ============================================================ */

const es = {
  nav: {
    how: "Cómo funciona",
    product: "Producto",
    arena: "Arena",
    demo: "Demo",
    cta: "Únete a la beta",
  },
  hero: {
    badge: "Puntos virtuales · 0€ en riesgo",
    h1a: "Demuestra",
    h1b1: "quién",
    h1b2: "sabe más",
    h1c: "de deporte.",
    sub: "Ligas privadas con tus amigos: predice partidos reales, apuesta puntos virtuales y sube en el ranking.",
    sub2: " Sin dinero real — solo orgullo.",
    ctaPrimary: "Únete a la beta →",
    ctaSecondary: "▶ Demo interactiva",
    stats: [
      ["16+", "mercados por partido"],
      ["10", "picks por boleto"],
      ["1v1", "duelos Arena"],
    ],
    cardLeagueLabel: "Liga Mafia",
    cardLeagueRow: "👑 Xavi · 1º",
    cardBetLabel: "Apuesta ganada",
    cardBetRow: "México 1-0 ✓",
    scroll: "Scroll ↓",
    phoneAlt: "Pantalla de inicio de Betsy con saldo y partido del día",
  },
  problem: {
    eyebrow: "El problema",
    h2a: "Todo el mundo",
    h2verb: "dice",
    h2b: "que lo sabía.",
    h2c: " Nadie lo demuestra.",
    without: "Sin Betsy",
    bubbles: ["“Yo sabía que ganaría.”", "“Yo lo dije antes que tú.”", "“Eso no cuenta…”"],
    withoutCaption: "Cero pruebas. Discusión infinita.",
    with: "Con Betsy",
    withCaption: "El ranking no discute. Gana quien acierta.",
    rankingAlt: "Clasificación de la liga en Betsy",
  },
  equation: {
    eyebrow: "El concepto",
    h2: "Una mezcla que no existía.",
    terms: [
      { word: "FANTASY", caption: "la liga con tus amigos" },
      { word: "APUESTAS", caption: "la adrenalina de las cuotas reales" },
      { word: "DINERO", caption: "ni un euro real, nunca" },
    ],
    result: "BETSY",
    resultCaption: "el juego social de predicción",
  },
  how: {
    eyebrow: "Cómo funciona",
    h2a: "De cero a",
    h2lime: "campeón",
    h2b: "en 5 pasos.",
    hint: "Sigue haciendo scroll →",
    steps: [
      { n: "01", t: "Crea tu liga", d: "Nombre, deportes, saldo inicial. Listo en 30 segundos." },
      { n: "02", t: "Invita con un código", d: "Un código, cero fricción. Todos empiezan con los mismos puntos." },
      { n: "03", t: "Predice partidos reales", d: "Resultado, goles, córners, jugadores… cuotas reales de 25+ bookmakers." },
      { n: "04", t: "Los puntos vuelan", d: "El partido acaba, el resultado real llega y tu saldo se mueve solo." },
      { n: "05", t: "Conquista el ranking", d: "Una temporada. Un campeón. Pruebas para siempre." },
    ],
    stepVisuals: {
      newLeague: "Nueva liga",
      leagueName: "MAFIA FC",
      sports: ["⚽ Mundial", "⚽ LaLiga", "🏀 NBA"],
      codeLabel: "Código de liga",
      share: "Compartir →",
      settle: "resultados reales · settlement automático",
    },
  },
  product: {
    eyebrow: "Producto",
    h2a: "Todo lo divertido de apostar.",
    h2b: "Nada de lo tóxico.",
    terminal: {
      title: "Mercados como un terminal pro",
      desc: "Tablas densas estilo bet365: cuotas reales fusionadas de 25+ casas. Goleadores, remates, triples, córners…",
      alt: "Mercados de un partido en Betsy estilo terminal profesional",
    },
    live: {
      title: "Posiciones en directo",
      desc: "Cada acierto te sube. Cada fallo te expone.",
      league: "Liga Mafia · en vivo",
    },
    arena: {
      title: "Arena 1v1",
      desc: "Reta a un amigo al mismo partido. El que más acierta se lo lleva todo.",
    },
    props: {
      title: "Player props",
      desc: "Apuesta al detalle: goles, asistencias, remates, puntos NBA.",
      alt: "Props de jugadores en Betsy",
    },
    ticker: [
      "Resultado", "Goles totales", "Ambos marcan", "Hándicap", "Córners", "Tarjetas",
      "Goleadores", "Primer goleador", "Remates", "Remates a puerta", "Asistencias",
      "Puntos NBA", "Rebotes", "Triples", "Doble oportunidad", "Goles por equipo",
    ],
  },
  arena: {
    eyebrow: "Arena 1v1",
    h2a: "Tú. Tu rival.",
    h2b: "Un partido.",
    sub: "Un partido, los mismos puntos en juego para los dos. El que más acierte se lo lleva todo. Si empatáis en aciertos, gana la cuota más valiente.",
    inPlay: "En juego",
    winner: "El ganador se lo lleva todo",
    winnerDone: "Xavi se lo lleva todo 👑",
    simulate: "Simular duelo →",
    again: "↺ Otro duelo",
    p1: { name: "Xavi", picks: "México + Más 2.5" },
    p2: { name: "Marc", picks: "Empate + Menos 1.5" },
  },
  different: {
    eyebrow: "La diferencia",
    h2a: "Esto",
    h2not: "no",
    h2b: "es una casa de apuestas.",
    sub: "La emoción de las apuestas, lo social del fantasy, el riesgo de ninguno.",
    colBookies: "Bookies",
    colFantasy: "Fantasy",
    rows: [
      { label: "La adrenalina de las cuotas reales", bookies: true, fantasy: false, betsy: true },
      { label: "Dinero real en riesgo", bookies: true, fantasy: false, betsy: false, invert: true },
      { label: "Compites contra tus amigos", bookies: false, fantasy: true, betsy: true },
      { label: "Acción cada día, en cualquier deporte", bookies: true, fantasy: false, betsy: true },
      { label: "Sin plantillas ni mercado de fichajes", bookies: true, fantasy: false, betsy: true },
      { label: "Duelos 1v1 con tus rivales", bookies: false, fantasy: false, betsy: true },
    ],
  },
  demo: {
    eyebrow: "Demo interactiva",
    h2a: "Tócala.",
    h2b: "Es real.",
    sub: "Las pantallas clave de Betsy, capturadas tal cual en el iPhone.",
    swipe: "Desliza el teléfono ←→",
    screens: {
      home: "Inicio", jugar: "Partidos", mercados: "Mercados",
      arena: "Arena", ranking: "Ranking", betslip: "Apuesta",
    },
  },
  cta: {
    h2a: "La liga",
    h2b: "la haces",
    h2you: "tú.",
    sub: "Invita a tus amigos y descubre quién sabe realmente de deporte.",
    primary: "Únete a la beta →",
    secondary: "▶ Ver demo",
    smallprint: "Gratis · Sin dinero real · +17",
    stats: [
      ["16+", "mercados por partido"],
      ["25+", "bookmakers fusionados"],
      ["72", "partidos del Mundial"],
      ["0€", "en riesgo"],
    ],
  },
  footer: {
    disclaimer:
      "Betsy es un juego social con puntos virtuales. No es una plataforma de apuestas: no se puede depositar, apostar ni ganar dinero real. Para mayores de 17 años.",
    support: "Soporte",
    terms: "Términos",
    privacy: "Privacidad",
  },
};

const en: typeof es = {
  nav: {
    how: "How it works",
    product: "Product",
    arena: "Arena",
    demo: "Demo",
    cta: "Join the beta",
  },
  hero: {
    badge: "Virtual points · 0€ at risk",
    h1a: "Settle",
    h1b1: "who",
    h1b2: "knows sports",
    h1c: "for real.",
    sub: "Private leagues with your friends: predict real matches, bet virtual points and climb the ranking.",
    sub2: " No real money — just bragging rights.",
    ctaPrimary: "Join the beta →",
    ctaSecondary: "▶ Interactive demo",
    stats: [
      ["16+", "markets per match"],
      ["10", "picks per slip"],
      ["1v1", "Arena duels"],
    ],
    cardLeagueLabel: "Mafia League",
    cardLeagueRow: "👑 Xavi · 1st",
    cardBetLabel: "Bet won",
    cardBetRow: "Mexico 1-0 ✓",
    scroll: "Scroll ↓",
    phoneAlt: "Betsy home screen with balance and match of the day",
  },
  problem: {
    eyebrow: "The problem",
    h2a: "Everyone",
    h2verb: "says",
    h2b: "they called it.",
    h2c: " Nobody proves it.",
    without: "Without Betsy",
    bubbles: ["“I knew they'd win.”", "“I called it before you.”", "“That doesn't count…”"],
    withoutCaption: "Zero proof. Endless arguing.",
    with: "With Betsy",
    withCaption: "The ranking doesn't argue. Whoever's right, wins.",
    rankingAlt: "League standings in Betsy",
  },
  equation: {
    eyebrow: "The concept",
    h2: "A mix that didn't exist.",
    terms: [
      { word: "FANTASY", caption: "the league with your friends" },
      { word: "BETTING", caption: "the thrill of real odds" },
      { word: "MONEY", caption: "not one real euro, ever" },
    ],
    result: "BETSY",
    resultCaption: "the social prediction game",
  },
  how: {
    eyebrow: "How it works",
    h2a: "From zero to",
    h2lime: "champion",
    h2b: "in 5 steps.",
    hint: "Keep scrolling →",
    steps: [
      { n: "01", t: "Create your league", d: "Name, sports, starting balance. Done in 30 seconds." },
      { n: "02", t: "Invite with a code", d: "One code, zero friction. Everyone starts with the same points." },
      { n: "03", t: "Predict real matches", d: "Result, goals, corners, players… real odds from 25+ bookmakers." },
      { n: "04", t: "Points fly", d: "The match ends, the real result lands, your balance moves on its own." },
      { n: "05", t: "Conquer the ranking", d: "One season. One champion. Proof, forever." },
    ],
    stepVisuals: {
      newLeague: "New league",
      leagueName: "MAFIA FC",
      sports: ["⚽ World Cup", "⚽ LaLiga", "🏀 NBA"],
      codeLabel: "League code",
      share: "Share →",
      settle: "real results · automatic settlement",
    },
  },
  product: {
    eyebrow: "Product",
    h2a: "Everything fun about betting.",
    h2b: "None of the toxic.",
    terminal: {
      title: "Markets like a pro terminal",
      desc: "Dense bet365-style tables: real odds merged from 25+ books. Scorers, shots, threes, corners…",
      alt: "Match markets in Betsy, pro-terminal style",
    },
    live: {
      title: "Live standings",
      desc: "Every hit lifts you. Every miss exposes you.",
      league: "Mafia League · live",
    },
    arena: {
      title: "Arena 1v1",
      desc: "Challenge a friend on the same match. Most hits takes it all.",
    },
    props: {
      title: "Player props",
      desc: "Bet the details: goals, assists, shots, NBA points.",
      alt: "Player props in Betsy",
    },
    ticker: [
      "Match result", "Total goals", "Both teams score", "Handicap", "Corners", "Cards",
      "Goalscorers", "First scorer", "Shots", "Shots on target", "Assists",
      "NBA points", "Rebounds", "Threes", "Double chance", "Team goals",
    ],
  },
  arena: {
    eyebrow: "Arena 1v1",
    h2a: "You. Your rival.",
    h2b: "One match.",
    sub: "One match, same points at stake for both. Most correct picks takes it all. Tie on hits? The braver odds win.",
    inPlay: "At stake",
    winner: "Winner takes it all",
    winnerDone: "Xavi takes it all 👑",
    simulate: "Simulate duel →",
    again: "↺ Another duel",
    p1: { name: "Xavi", picks: "Mexico + Over 2.5" },
    p2: { name: "Marc", picks: "Draw + Under 1.5" },
  },
  different: {
    eyebrow: "The difference",
    h2a: "This is",
    h2not: "not",
    h2b: "a sportsbook.",
    sub: "The thrill of betting, the social of fantasy, the risk of neither.",
    colBookies: "Bookies",
    colFantasy: "Fantasy",
    rows: [
      { label: "The thrill of real odds", bookies: true, fantasy: false, betsy: true },
      { label: "Real money at risk", bookies: true, fantasy: false, betsy: false, invert: true },
      { label: "You compete against friends", bookies: false, fantasy: true, betsy: true },
      { label: "Action every day, any sport", bookies: true, fantasy: false, betsy: true },
      { label: "No rosters, no transfer market", bookies: true, fantasy: false, betsy: true },
      { label: "1v1 duels with your rivals", bookies: false, fantasy: false, betsy: true },
    ],
  },
  demo: {
    eyebrow: "Interactive demo",
    h2a: "Touch it.",
    h2b: "It's real.",
    sub: "Betsy's key screens, captured straight from the iPhone.",
    swipe: "Swipe the phone ←→",
    screens: {
      home: "Home", jugar: "Matches", mercados: "Markets",
      arena: "Arena", ranking: "Ranking", betslip: "Bet slip",
    },
  },
  cta: {
    h2a: "The league",
    h2b: "is made by",
    h2you: "you.",
    sub: "Invite your friends and find out who really knows sports.",
    primary: "Join the beta →",
    secondary: "▶ Watch demo",
    smallprint: "Free · No real money · 17+",
    stats: [
      ["16+", "markets per match"],
      ["25+", "bookmakers merged"],
      ["72", "World Cup matches"],
      ["0€", "at risk"],
    ],
  },
  footer: {
    disclaimer:
      "Betsy is a social game with virtual points. It is not a betting platform: you cannot deposit, wager or win real money. For ages 17+.",
    support: "Support",
    terms: "Terms",
    privacy: "Privacy",
  },
};

export const COPY = { es, en };
export type Lang = keyof typeof COPY;
export type Copy = typeof es;

/* ============================================================
   Provider
   ============================================================ */

const LangCtx = createContext<{ lang: Lang; setLang: (l: Lang) => void }>({
  lang: "es",
  setLang: () => {},
});

export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>("es");

  useEffect(() => {
    const saved = localStorage.getItem("betsy-lang");
    if (saved === "es" || saved === "en") setLangState(saved);
    else if (!navigator.language?.toLowerCase().startsWith("es")) setLangState("en");
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const setLang = (l: Lang) => {
    setLangState(l);
    localStorage.setItem("betsy-lang", l);
  };

  return <LangCtx.Provider value={{ lang, setLang }}>{children}</LangCtx.Provider>;
}

export function useLang() {
  return useContext(LangCtx);
}

export function useCopy(): Copy {
  return COPY[useContext(LangCtx).lang];
}
