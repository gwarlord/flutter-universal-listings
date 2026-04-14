#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[splash] Generating native splash assets..."
flutter pub run flutter_native_splash:create

echo "[splash] Enforcing Android non-stretch launch layout..."
for file in \
  "android/app/src/main/res/drawable/launch_background.xml" \
  "android/app/src/main/res/drawable-night/launch_background.xml" \
  "android/app/src/main/res/drawable-v21/launch_background.xml" \
  "android/app/src/main/res/drawable-night-v21/launch_background.xml"; do
  cat > "$file" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <bitmap android:gravity="fill" android:src="@drawable/background"/>
    </item>
    <item>
        <bitmap android:gravity="fill_horizontal|center_vertical" android:src="@drawable/splash"/>
    </item>
</layer-list>
EOF
done

echo "[splash] Enforcing Android transition background..."
for file in \
  "android/app/src/main/res/values/styles.xml" \
  "android/app/src/main/res/values-night/styles.xml" \
  "android/app/src/main/res/values-v31/styles.xml" \
  "android/app/src/main/res/values-night-v31/styles.xml"; do
  perl -0777 -i '' -pe 's#(<style name="NormalTheme"[^>]*>\s*<item name="android:windowBackground">)[^<]+(</item>)#$1@drawable/launch_background$2#g' "$file"
done

echo "[splash] Enforcing iOS aspect-fit launch logo..."
perl -0777 -i '' -pe 's/contentMode="[^"]*" image="LaunchImage"/contentMode="scaleAspectFit" image="LaunchImage"/g' "ios/Runner/Base.lproj/LaunchScreen.storyboard"

echo "[splash] Done."
