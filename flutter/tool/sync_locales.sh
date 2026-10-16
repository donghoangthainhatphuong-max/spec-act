#!/usr/bin/env sh
# The Android app reuses the web app's translations and legal pages. Run after changing src/locales/*.json or src/locales/pages/*.json.
cd "$(dirname "$0")/.." && cp ../src/locales/*.json assets/locales/ && mkdir -p assets/locales/pages && cp ../src/locales/pages/*.json assets/locales/pages/ && echo "locales synced"
