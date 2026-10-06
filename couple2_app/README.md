# couple2_app

Flutter client for Couple. Local runs talk to the API at `http://localhost:3000` with no extra flags. The base URL is `API_BASE_URL` in `lib/app/di.dart` (`String.fromEnvironment`, default `http://localhost:3000`).

## Local

```bash
flutter pub get
flutter run -d chrome
```

## Production web (Firebase Hosting)

Project: `couple42-f87b6`. Hosting config is `firebase.json` (`public`: `build/web`) and `.firebaserc`.

From `couple2_app`:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://couple2-api-production.up.railway.app
firebase deploy --only hosting
```

Or `./scripts/build_web_release.sh`, then `firebase deploy --only hosting`.

`API_BASE_URL` is a compile-time value. Changing the API host means rebuilding the web app. Do not commit secrets; this URL is the public API.
