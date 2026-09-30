#!/usr/bin/env bash
# Fill .env from the running local Supabase stack. YOU run this, in your own
# terminal — it writes .env, which rule 2.3 keeps the agent out of and rule 2.6
# gates behind scripts/env-unlock.sh.
#
# Why this exists instead of having the agent write .env: the values are public
# constants (the local issuer is literally `supabase-demo`), so there is nothing
# secret to protect. But `.env` is still a file the agent is not allowed to
# write, and keeping the rule absolute is worth more than the convenience.
#
# GOTCHA, and the reason this script exists rather than a two-line paste:
# `supabase status -o env` wraps every value in DOUBLE QUOTES:
#     PUBLISHABLE_KEY="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
# Feeding that verbatim to createClient() sends `apikey: "sb_publishable_..."`
# — quotes included — and PostgREST answers:
#     PGRST301  Expected 3 parts in JWT; got 1
# which reads like a broken key or a broken client, and is neither.

set -euo pipefail

cd "$(dirname "$0")/.."

env_file=".env"

# Prefer a global `supabase` binary; fall back to npx so the script works on a
# fresh machine where only the npm dependency exists.
if command -v supabase >/dev/null 2>&1; then
  sb() { supabase "$@"; }
else
  sb() { npx --yes supabase@latest "$@"; }
fi

if ! sb status >/dev/null 2>&1; then
  printf 'Local Supabase is not running. Start it first:\n  npx supabase start\n' >&2
  exit 1
fi

# Strip the surrounding quotes. tr -d removes them from anywhere, which is safe
# here because these values are base64-ish and never contain a quote themselves.
url="$(sb status -o env | grep '^API_URL=' | cut -d= -f2- | tr -d '"')"
puk="$(sb status -o env | grep '^PUBLISHABLE_KEY=' | cut -d= -f2- | tr -d '"')"

if [ -z "$url" ] || [ -z "$puk" ]; then
  printf 'Could not read API_URL / PUBLISHABLE_KEY from `supabase status -o env`.\n' >&2
  exit 1
fi

case "$puk" in
  sb_publishable_*) ;;
  *) printf 'PUBLISHABLE_KEY does not start with sb_publishable_ — refusing.\n' >&2; exit 1 ;;
esac
case "$url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) printf 'API_URL %s is not a local address — refusing to write it.\n' "$url" >&2; exit 1 ;;
esac

# Rule 2.6 — writing .env requires a live unlock token.
if [ ! -f .claude/.gate-token ]; then
  printf '\nThis script writes .env, so run scripts/env-unlock.sh first.\n' >&2
  exit 1
fi

if [ ! -f "$env_file" ]; then
  cp .env.template "$env_file"
fi

tmp="$(mktemp)"
awk -v url="$url" -v puk="$puk" '
  /^VITE_SUPABASE_URL=/            { print "VITE_SUPABASE_URL=" url; next }
  /^VITE_SUPABASE_PUBLISHABLE_KEY=/ { print "VITE_SUPABASE_PUBLISHABLE_KEY=" puk; next }
  { print }
' "$env_file" > "$tmp"
mv "$tmp" "$env_file"
chmod 600 "$env_file"

printf '\nWrote local values to %s\n' "$env_file"
printf '  VITE_SUPABASE_URL             %s\n' "$url"
printf '  VITE_SUPABASE_PUBLISHABLE_KEY sb_publishable_...%s (quotes stripped)\n' "${puk: -4}"
printf '\nThen run: npm run dev\n'