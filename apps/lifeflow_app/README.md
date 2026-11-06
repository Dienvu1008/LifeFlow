# lifeflow_app

The LifeFlow Flutter app (Windows + Android). It is the **composition root**: the
only place that wires `infrastructure` (Drift store, command gateway,
authorization) into the `ui` ports. See
[repository-structure.md](../../docs/architecture/repository-structure.md).

## Run
```powershell
flutter run -d windows
flutter run -d <android-device-id>   # list devices with: flutter devices
```

## Test (headless)
```powershell
flutter analyze
flutter test
```

## Storage
- The local database lives in the app-private support directory
  (Windows: `%APPDATA%\app.lifeflow\lifeflow_app\lifeflow.sqlite`).
- At-rest encryption follows [ADR-0021](../../docs/adr/0021-encryption-at-rest-platform-posture.md).
  In P01 T6a the database is **plain on every platform** and the startup
  self-check shows a banner saying so. Android encryption is wired in T6b.
