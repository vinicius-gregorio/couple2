#!/usr/bin/env bash
# Production Flutter web build for Firebase Hosting (project couple42-f87b6).
# Dev builds keep http://localhost:3000 when API_BASE_URL is not passed.
set -euo pipefail

cd "$(dirname "$0")/.."

API_BASE_URL="${API_BASE_URL:-https://couple2-api-production.up.railway.app}"

flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"

echo
echo "Web build: build/web"
echo "Deploy from couple2_app: firebase deploy --only hosting"
