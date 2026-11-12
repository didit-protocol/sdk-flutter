## 0.1.0

First release of Didit Authentication for Flutter.

- Hosted sign-in and sign-up on your application's Didit page with PKCE (`signIn`).
- Passkeys: `signInWithPasskey` and `registerPasskey`.
- `currentSession` (cached for 30 seconds, `force` asks Didit now), `getToken` and `signOut`.
- `reauthenticate` asks the signed-in person to sign in again (`DiditReauthMethod.hosted` or `passkey`) and returns the new session; a different person signing in throws `step_up_user_mismatch`.
- Step-ups before sensitive actions: `stepUp` with `DiditPayoutStepUp`, `DiditBankStepUp` and `DiditContactStepUp`.
- One typed `DiditAuthException` with the stable `code` values of native DiditAuth, plus `status`, `fields` and `retryAfter`.
- Android and iOS, on native DiditAuth 4.15.0 (`me.didit:didit-auth` and `DiditSDK/Auth`, or the `DiditAuth` Swift package product).
