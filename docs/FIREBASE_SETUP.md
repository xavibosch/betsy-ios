# Firebase Setup

## Current expected app identity

Based on the local project files, Betsy currently expects:
- Firebase project id: `betsy-9b8cf`
- iOS bundle id: `com.pau.Betsy`

Check this in:
- `APP/GoogleService-Info.plist`
- `3x.xcodeproj`

## Minimum Firebase setup

### 1. Authentication
In Firebase Console:

`Authentication -> Método de acceso -> Correo electrónico/contraseña -> Habilitar`

If this is disabled, account creation and sign in will fail even if the form is correct.

### 2. Firestore
The app expects Firestore for:
- users
- leagues
- members
- arenas
- challenges

### 3. iOS app registration
The Firebase project must contain an iOS app with:
- bundle id `com.pau.Betsy`

If the app points to a different Firebase project or different iOS app registration, auth behavior can look inconsistent.

## Common debugging checklist

### "The provider is disabled"
Usually means one of these:
- Email/Password is not enabled in Firebase Auth
- the app is using a different `GoogleService-Info.plist` than the Firebase project you are checking
- the installed app is an older build still carrying old config

### If auth still fails after enabling Email/Password
1. Confirm the Firebase project id matches the plist.
2. Confirm the bundle id registered in Firebase matches Xcode.
3. Delete the app from simulator/device.
4. Rebuild from Xcode.
5. Try sign up again.

## Recommended next Firebase steps

- enable Email/Password
- verify Firestore rules and structure
- verify account creation under `Authentication -> Usuarios`
- later connect real sports data and notifications more deeply

