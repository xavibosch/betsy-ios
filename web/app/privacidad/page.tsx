import LegalShell, { H } from "@/components/legal-shell";

export const metadata = { title: "Política de privacidad — Betsy" };

export default function Privacy() {
  return (
    <LegalShell title="Política de privacidad" updated="junio 2026">
      <p>Betsy es un juego social de predicción deportiva con puntos virtuales. No se puede depositar, apostar ni ganar dinero real. Esta política explica qué datos tratamos y por qué.</p>

      <H>Qué datos recogemos</H>
      <p><strong>Cuenta:</strong> email y nombre que eliges al registrarte (a través de Firebase Authentication).</p>
      <p><strong>Juego:</strong> ligas a las que perteneces, tu saldo de puntos virtuales, tus predicciones y tu posición en la clasificación. Se guardan en Firebase Firestore.</p>
      <p><strong>Foto de perfil:</strong> opcional, si decides añadir una. Se guarda en tu dispositivo.</p>
      <p><strong>Uso (opcional):</strong> solo si das consentimiento explícito de analítica, eventos anónimos de uso para mejorar la app. Puedes rechazarlo y la app funciona igual.</p>

      <H>Qué NO recogemos</H>
      <p>No recogemos datos de pago, ubicación precisa, contactos ni datos sensibles. No hay transacciones de dinero real en ningún punto de la app.</p>

      <H>Proveedores</H>
      <p>Usamos <strong>Firebase</strong> (Google) para autenticación y base de datos, y APIs deportivas (The Odds API, football-data.org) para cuotas y resultados de partidos reales. Estas APIs reciben únicamente identificadores de partido, nunca tus datos personales.</p>

      <H>Tus derechos (RGPD)</H>
      <p>Puedes acceder, rectificar y eliminar tus datos en cualquier momento. La opción <strong>«Eliminar cuenta»</strong> dentro de Perfil borra tu cuenta y todos tus datos asociados de forma permanente.</p>

      <H>Edad</H>
      <p>Betsy es para mayores de 17 años. Comprobamos la edad en el registro.</p>

      <H>Contacto</H>
      <p>Para cualquier duda sobre privacidad: <strong>betsy.support@gmail.com</strong></p>
    </LegalShell>
  );
}
