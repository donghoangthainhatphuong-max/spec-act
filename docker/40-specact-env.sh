#!/bin/sh
# Turns every VITE_* environment variable of the container into /env-config.js so the
# configuration can be changed with `docker compose up -d` — no image rebuild needed.
set -eu
dir=/tmp/specact
mkdir -p "$dir"
out=$dir/env-config.js
{
  echo "/* generated at container start */"
  echo "window.__SPECACT_ENV__ = {"
  env | grep '^VITE_' | sort | while IFS='=' read -r key value; do
    esc=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/</\\u003c/g')
    printf '  "%s": "%s",\n' "$key" "$esc"
  done
  echo "};"
} > "$out"
echo "specact: wrote $out"
