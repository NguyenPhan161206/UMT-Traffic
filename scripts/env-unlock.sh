#!/usr/bin/env bash
# Unlock .env writes for a limited window. YOU run this, in your own terminal.
#
# Why this is not something an agent can do on your behalf:
#   `read -s` needs a controlling terminal. The agent's tool calls have none —
#   opening /dev/tty returns "No such device or address". So the passphrase can
#   only ever be typed by a human sitting at the keyboard, which is the point.
#
# It writes .claude/.gate-token containing the sha256 of what you typed, plus
# the current epoch. .claude/hooks/block-forbidden.sh compares the same hash and
# enforces the TTL, so a stale token from earlier cannot be reused forever.

set -euo pipefail

cd "$(dirname "$0")/.."

env_file=".env"
hash_file=".claude/.gate-passphrase"
token_file=".claude/.gate-token"
ttl=600

if [ ! -f "$hash_file" ]; then
  printf 'Gate is not armed. Run scripts/env-setup.sh first.\n' >&2
  exit 1
fi

printf 'PASSPHRASE: '
IFS= read -r -s typed
printf '\n'

expected="$(cat "$hash_file")"
actual="$(printf '%s' "$typed" | sha256sum | cut -d' ' -f1)"

if [ "$actual" != "$expected" ]; then
  rm -f "$token_file"
  printf 'Passphrase does not match. Token cleared.\n' >&2
  exit 1
fi

printf '%s %s\n' "$actual" "$(date +%s)" > "$token_file"
chmod 600 "$token_file"

printf 'Unlocked for %s seconds (.env writes only).\n' "$ttl"
printf 'Token stored in %s — it is not a secret and expires on its own.\n' "$token_file"