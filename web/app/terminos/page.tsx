import LegalShell, { H } from "@/components/legal-shell";

export const metadata = { title: "Términos de uso — Betsy" };

export default function Terms() {
  return (
    <LegalShell title="Términos de uso" updated="junio 2026">
      <p>Al usar Betsy aceptas estos términos. Léelos con atención.</p>

      <H>Qué es Betsy</H>
      <p>Betsy es un juego social de predicción deportiva. Compites con amigos en ligas privadas usando <strong>puntos virtuales sin valor monetario</strong>. No es una casa de apuestas: no se puede depositar, apostar ni retirar dinero real, ni canjear puntos por nada de valor.</p>

      <H>Puntos virtuales</H>
      <p>Los puntos son ficticios, se otorgan gratis al unirte a una liga y solo sirven para competir dentro de la app. No se compran, no se venden y no tienen valor en el mundo real.</p>

      <H>Juego limpio</H>
      <p>Las predicciones se resuelven con resultados reales de los partidos cuando hay datos disponibles, y con un método determinista idéntico para todos los jugadores cuando no los hay. Está prohibido manipular la app o explotar errores.</p>

      <H>Edad mínima</H>
      <p>Debes tener 17 años o más para usar Betsy.</p>

      <H>Responsabilidad</H>
      <p>Las cuotas y resultados provienen de proveedores externos y pueden contener errores o retrasos. Betsy se ofrece «tal cual», sin garantía de disponibilidad continua.</p>

      <H>Contacto</H>
      <p><strong>betsy.support@gmail.com</strong></p>
    </LegalShell>
  );
}
