// BetsyLeagueService.swift — MIGRADO
//
// La clase y todas sus extensiones han sido movidas a APP/Core/Services/:
//
//   LeagueService.swift            → Clase base: @Published, init, previewMock, resetSession
//   LeagueService+Auth.swift       → registerAccount, signInAccount, sendPasswordReset, auth helpers
//   LeagueService+Dev.swift        → Perfiles dev, reset de datos, eliminación de cuentas
//   LeagueService+Leagues.swift    → CRUD ligas, join/leave, loadMembers, listener
//   LeagueService+Challenges.swift → Retos 1v1 sobre partido
//   LeagueService+Points.swift     → transferPoints, addPoints, adjustPoints, claimRecoveryBoost
//   LeagueService+PowerUps.swift   → listenForPowerUps, consumePowerUp, grantDailyPowerUpIfNeeded
//   LeagueService+Arena.swift      → Duelos Arena completos (crear, aceptar, resolver, parsear)
//   LeagueService+Helpers.swift    → generateCode, normalizedSettings, parseLeagueSettings, leagueSettingsData
//
// Este archivo puede eliminarse cuando se confirme que la build compila sin errores.
