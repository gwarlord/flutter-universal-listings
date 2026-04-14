#!/bin/bash

set -e

DEFINE_FILE="${1:-env/dart_defines.release.json}"

echo "🚀 Starting Android release bundle build..."
echo ""

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install Flutter and try again."
    exit 1
fi

if [ ! -f "$DEFINE_FILE" ]; then
    echo "❌ Dart define file not found: $DEFINE_FILE"
    echo ""
    echo "Create it from the example first:"
    echo "   cp env/dart_defines.example.json env/dart_defines.release.json"
    echo ""
    echo "Then fill in the values and rerun:"
    echo "   ./build_release_bundle.sh"
    exit 1
fi

echo "📋 Using dart-define file: $DEFINE_FILE"
echo "📦 Fetching dependencies..."
flutter pub get
echo ""

echo "🔨 Building Flutter Android App Bundle..."
flutter build appbundle \
  --release \
  --dart-define-from-file="$DEFINE_FILE"
echo ""

echo "✅ Release bundle complete"
echo "📍 Output: build/app/outputs/bundle/release/app-release.aab"