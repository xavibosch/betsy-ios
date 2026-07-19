import LegalShell, { H } from "@/components/legal-shell";

export const metadata = { title: "Soporte — Betsy" };

export default function Support() {
  return (
    <LegalShell title="Soporte" updated="junio 2026">
      <p>¿Necesitas ayuda con Betsy? Aquí tienes lo esencial.</p>

      <H>Contacto directo</H>
      <p>Escríbenos a <strong>betsy.support@gmail.com</strong> y te respondemos lo antes posible.</p>

      <H>Preguntas frecuentes</H>
      <p><strong>¿Se juega con dinero real?</strong> No. Betsy usa solo puntos virtuales sin valor monetario.</p>
      <p><strong>¿Cómo creo una liga?</strong> En la pestaña Liga → Crear nueva liga. Comparte el código con tus amigos.</p>
      <p><strong>¿Cómo se resuelven mis apuestas?</strong> Automáticamente cuando el partido acaba, con el resultado real.</p>
      <p><strong>¿Cómo elimino mi cuenta?</strong> Perfil → Eliminar cuenta. Borra todos tus datos de forma permanente.</p>

      <H>Juego responsable</H>
      <p>Aunque no hay dinero real, Betsy promueve un uso sano: límites de apuestas por día y un reto por día en Arena. Juega por diversión.</p>
    </LegalShell>
  );
}
