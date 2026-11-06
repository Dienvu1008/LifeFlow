# lifeflow_app

The LifeFlow Flutter app (Windows + Android). It is the **composition root**: the
only place that wires `infrastructure` (Drift store, command gateway,
authorization, identity provider) into the `ui` ports. See
[repository-structure.md](../../docs/architecture/repository-structure.md).

## Run
Without sign-in (guest only, works fully offline):
```powershell
flutter run -d windows
flutter run -d <android-device-id>   # list devices with: flutter devices
```

With sign-in (Supabase Auth, ADR-0003). The anon key is a public client key;
pass it at build time, never commit it:
```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```
The Supabase project must allow these redirect URLs:
- `http://127.0.0.1:53682/callback` (Windows, GitHub)
- `lifeflow://callback` (Android, GitHub)

## Test (headless)
```powershell
flutter analyze
flutter test
```

## Storage
- The local database lives in the app-private support directory
  (Windows: `%APPDATA%\app.lifeflow\lifeflow_app\lifeflow.sqlite`).
- SQLite3MultipleCiphers is linked on every platform. Per
  [ADR-0022](../../docs/adr/0022-windows-encryption-at-rest.md),
  **Android and Windows are both encrypted** (random 256-bit key in secure
  storage).
- An existing plain database is encrypted in place on first launch of an
  encrypting build. If the key is ever missing, the app explains and leaves
  the file untouched.
- Fallback (ADR-0021 option B, kept under control): build with
  `--dart-define=LIFEFLOW_WINDOWS_PLAIN_DB=true` to keep a plain database on
  Windows; the app then shows it as a tracked exception. Fresh installs only:
  an encrypted database is never downgraded.
