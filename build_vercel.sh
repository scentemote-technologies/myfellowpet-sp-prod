#!/usr/bin/env bash
set -e

echo "🚀 Installing Flutter..."

# Clone Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

flutter --version
flutter config --enable-web
flutter doctor

echo "🏗️ Building Flutter Web..."

flutter build web --release \
  --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY \
  --dart-define=PLACES_API_KEY=$PLACES_API_KEY \
  --dart-define=FIREBASE_AUTH_DOMAIN=$FIREBASE_AUTH_DOMAIN \
  --dart-define=FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID \
  --dart-define=FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID \
  --dart-define=FIREBASE_APP_ID=$FIREBASE_APP_ID \
  --dart-define=RECAPTCHA_SITE_KEY=$RECAPTCHA_SITE_KEY
