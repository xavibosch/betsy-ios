import { loadFont as loadBebas } from "@remotion/google-fonts/BebasNeue";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";

const bebas = loadBebas("normal", { weights: ["400"] });
const inter = loadInter("normal", { weights: ["400", "700", "800", "900"] });
const mono = loadMono("normal", { weights: ["700", "800"] });

// Betsy brand — mirrors betsy-web globals.css
export const T = {
  bg: "#0a0a09",
  bg1: "#121211",
  bg2: "#1a1a18",
  line: "#2a2a27",
  fg: "#f4f4ee",
  fg2: "#b9b9b2",
  fg3: "#8a8a85",
  lime: "#c9f73a",
  limeInk: "#131800",
  arena: "#ff4d5a",
  display: bebas.fontFamily,
  body: inter.fontFamily,
  mono: mono.fontFamily,
} as const;
