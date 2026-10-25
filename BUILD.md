# Build

Requires the Flutter SDK (Dart SDK ^3.12.0) and the Android SDK.

```
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The release APK lands in `app/build/app/outputs/flutter-apk/`. Prebuilt APKs are in `release/`.

No computer with Flutter? Push the repository to GitHub and run the "Build APK" workflow on the Actions
tab; the APK appears under the run's Artifacts.

Open Food Facts credentials, if used for barcode lookup, are passed at build time with
`--dart-define=OFF_USER=... --dart-define=OFF_PASSWORD=...` (in CI they come from repository secrets).
They are never committed.
