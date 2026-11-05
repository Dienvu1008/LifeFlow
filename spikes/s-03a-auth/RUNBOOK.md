# S-03a Runbook (auth + Windows flow + offline session)

- Status: Spike POC (throwaway). Branch `spike/s-03a`. Do not merge to `main` as a feature.
- Social provider: **GitHub** (Google is P04).
- Owner runs the device/OAuth steps; the agent wrote the code and this runbook.

## 0. What this proves (success criteria)
1. Email + GitHub sign-in work on **Windows** and **Android**.
2. The session is cached in secure storage and **survives an offline restart** (see §5 for the exact definition).
3. Windows uses PKCE **S256** (not plain) via a fixed loopback port.
4. No access/refresh token appears in logs.

If any fails or setup exceeds the sub-cap (see §7) → record Open + escalate.

## 1. Prerequisites
- Flutter stable (3.47.x confirmed present).
- A GitHub account.
- A Supabase project (free tier is fine).
- Android device/emulator; Windows desktop build enabled (`flutter config --enable-windows-desktop`).

## 2. Create the Supabase project (once)
1. Create a project at supabase.com; note the **Project URL** and the **anon/publishable key** (Project Settings → API). The anon key is a public client key, not a secret.
2. Authentication → Providers → **GitHub** → enable. It shows a **callback URL** like `https://<ref>.supabase.co/auth/v1/callback`.
3. On GitHub: Settings → Developer settings → **OAuth Apps** → New OAuth App.
   - Homepage URL: anything (e.g. `https://example.com`).
   - **Authorization callback URL**: the Supabase callback URL from step 2.
   - Copy the **Client ID** and generate a **Client secret**; paste both into Supabase's GitHub provider config. Save.

## 3. Configure redirect URLs in Supabase (once)
Authentication → URL Configuration → **Redirect URLs**, add both:
- `http://127.0.0.1:53682/callback`  (Windows desktop loopback, fixed port)
- `lifeflow://callback`  (Android deep link)

Fallback: if Supabase rejects the loopback URL for your project, use `lifeflow://callback` on desktop too and register the custom scheme on Windows; note this in the result. (The POC defaults to the loopback.)

## 4. Run
From `spikes/s-03a-auth`:

Windows:
```
flutter run -d windows --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```
Android (device/emulator attached):
```
flutter run -d <android-device-id> --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Then in the app:
- "Sign in (GitHub)": Windows opens the browser, you authorize, the loopback tab says "Signed in"; Android opens the browser and returns via the deep link.
- Enter an email+password and "Sign up (email)" then "Sign in (email)" for the email baseline (confirm email if your project requires it; for the spike you can disable email confirmation in Supabase Auth settings).

## 5. Offline-restart test (exact definition)
"Signed in offline" means: **turn off the network, kill the app, reopen it, and the app shows Status = signedIn without making any network call.** Steps:
1. Sign in (GitHub or email). Confirm Status = signedIn.
2. Turn off network (airplane mode / disable adapter).
3. Fully kill the app (close the window / swipe away).
4. Reopen the app (still offline).
5. Expected: Status = **signedIn** (session read from secure storage, no network).
6. Toggle the "Simulate offline" switch to see token-expiry behavior: if the cached access token is expired AND offline, Status = **signedInReadOnlyOffline** (the user stays signed in, read-only, until a refresh succeeds online). This read-only-on-expired-offline behavior is a success criterion.

## 6. Token-in-logs check
Run with `flutter run` and watch the console during sign-in and restart. Confirm no access/refresh token string is printed. (The POC does not log tokens; this check guards against the plugin/SDK doing so.)

## 7. Time-box and escalation
- Time-box 3–5 person-days. **Sub-cap: if provider setup (§2–§3) exceeds ~1 pd without a working OAuth flow, stop and escalate** (consider Firebase Auth or self-hosted GoTrue).
- If the box ends without a conclusion → record Open + escalate; do not extend into a feature.

## 8. Report back
Fill the S-03a entry in `../spike-results.md` with: what you ran, measured result per §0 criterion (pass/fail each), and any blocker. Then the human review gate decides: proceed to S-01, or escalate.
