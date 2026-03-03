#!/bin/bash

set -e

PROJECT_ID="caribtap"

echo "🚀 Starting Flutter Web deployment..."
echo ""

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install Flutter and try again."
    exit 1
fi

if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

echo "📋 Checking Firebase authentication..."
firebase projects:list > /dev/null 2>&1 || {
    echo "❌ Not logged in to Firebase. Please run:"
    echo "   firebase login"
    exit 1
}

echo "✅ Tooling and authentication checks passed"
echo ""

echo "🎯 Selecting Firebase project: ${PROJECT_ID}"
firebase use "${PROJECT_ID}"
echo ""

echo "📦 Fetching dependencies..."
flutter pub get
echo ""

echo "🔨 Building Flutter web release..."
flutter build web --release
echo ""

echo "☁️ Deploying to Firebase Hosting..."
firebase deploy --only hosting
echo ""

echo "✅ Web deployment complete"
echo "🌐 Your app is now live on Firebase Hosting using the same backend project (${PROJECT_ID})"
