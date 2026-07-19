import Nav from "@/components/nav";
import Hero from "@/components/sections/hero";
import Equation from "@/components/sections/equation";
import { Problem, HowItWorks } from "@/components/sections/story";
import { Product, Arena } from "@/components/sections/showcase";
import { Different, LiveDemo } from "@/components/sections/experience";
import { FinalCTA, Footer } from "@/components/sections/closing";

export default function Page() {
  return (
    <main>
      <Nav />
      <Hero />
      <Problem />
      <Equation />
      <HowItWorks />
      <Product />
      <Arena />
      <Different />
      <LiveDemo />
      <FinalCTA />
      <Footer />
    </main>
  );
}
