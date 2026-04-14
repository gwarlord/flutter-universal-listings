# Dart Define Release Setup

This repo now supports `--dart-define` values for Dart-side runtime keys, with `.env` still available as a fallback.

## What This Solves

This lets release builds stop depending on a bundled `.env` file for Dart runtime configuration.

## Files

- `env/dart_defines.example.json` - checked-in template with no secrets
- `env/dart_defines.release.json` - your local release config file (gitignored)
- `build_release_bundle.sh` - helper script for Android release builds

## Setup

1. Create your local release config:

```bash
cp env/dart_defines.example.json env/dart_defines.release.json
```

2. Fill in the values you actually use.

3. Build the release bundle:

```bash
./build_release_bundle.sh
```

## Notes

- Android native Maps SDK key still comes from `android/local.properties`.
- iOS native Maps SDK key still comes from `ios/Flutter/LocalSecrets.xcconfig`.
- Dart-side values can now come from `--dart-define-from-file`.
- `.env` is still currently supported as a fallback for local/dev use.

## Next Step

After confirming release builds work with `env/dart_defines.release.json`, you can remove `.env` from Flutter assets in `pubspec.yaml`.