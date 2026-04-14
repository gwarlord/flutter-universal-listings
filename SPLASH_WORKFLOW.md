Splash Stability Workflow

Problem
- Running flutter_native_splash directly can overwrite platform-specific fixes, causing iOS and Android to regress alternately.

Single Source of Truth
- Use pubspec splash config as base.
- Always apply platform guardrails immediately after regeneration.

Use This Command Only
- ./tools/splash_sync.sh

What the script enforces
- Regenerates splash assets with flutter_native_splash.
- Android launch image gravity stays non-stretched and centered vertically.
- Android NormalTheme window background stays launch_background to avoid black transition flash.
- iOS LaunchImage content mode stays scaleAspectFit to avoid stretching.

Recommended update flow
1. Make logo/color changes in pubspec.yaml.
2. Run ./tools/splash_sync.sh.
3. Validate both platforms before additional splash edits.

Quick validation checklist
1. Android 12+: first system splash uses icon; second stage is non-stretched brand splash.
2. Android transition to Flutter does not flash a black frame.
3. iOS launch logo keeps aspect ratio and does not stretch.
