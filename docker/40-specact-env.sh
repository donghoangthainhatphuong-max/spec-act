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

# Content-Security-Policy: Google only, plus the origin of the link-preview service when VITE_LINK_PREVIEW_URL is set (https only).
extra=""
case "${VITE_LINK_PREVIEW_URL:-}" in
  https://*) origin=$(printf '%s' "$VITE_LINK_PREVIEW_URL" | sed -n 's#^\(https://[A-Za-z0-9._:-]*\)\([/?#].*\)\{0,1\}$#\1#p'); [ -n "$origin" ] && extra=" $origin" ;;
esac
sed "s#__CONNECT_EXTRA__#$extra#" /etc/nginx/security-headers.conf.tpl > "$dir/security-headers.conf"
echo "specact: wrote $dir/security-headers.conf"
