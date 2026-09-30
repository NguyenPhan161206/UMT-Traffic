#!/usr/bin/env bash
# One-time setup for the .env write gate.
#
# You run this yourself, in your own terminal. An agent cannot run this for
# you: it reads the passphrase with `read -s`, and the agent's process has no
# controlling terminal (verified — opening /dev/tty from a tool call fails
# with "No such device or address"). That asymmetry IS the security model.
#
# What it does:
#   1. creates .env from .env.template if missing
#   2. asks you to type a passphrase of your choosing
#   3. writes it into PASSPHRASE= in .env            (git-ignored, agent-blocked)
#   4. writes sha256(passphrase) to .claude/.gate-passphrase  (git-ignored)
#
# Only the hash is ever read by the hook, so the hook never needs the plaintext
# and never touches .env.

set -euo pipefail

cd "$(dirname "$0")/.."

env_file=".env"
hash_file=".claude/.gate-passphrase"

if [ ! -f "$env_file" ]; then
  cp .env.template "$env_file"
  printf 'Created %s from .env.template\n' "$env_file"
fi

if [ -f "$hash_file" ]; then
  printf '%s already exists — gate already armed.\n' "$hash_file"
  printf 'Delete that file first if you want to choose a different passphrase.\n'
  exit 0
fi

printf '\nChoose a passphrase to gate .env writes.\n'
printf 'You type it here now, and once per unlock later. It is stored in %s,\n' "$env_file"
printf 'which is git-ignored and which the agent is forbidden to read.\n\n'

printf 'PASSPHRASE: '
IFS= read -r -s passphrase
printf '\n'

if [ -z "$passphrase" ]; then
  printf 'Empty passphrase rejected. Nothing written.\n' >&2
  exit 1
fi

hash="$(printf '%s' "$passphrase" | sha256sum | cut -d' ' -f1)"

if grep -q '^PASSPHRASE=' "$env_file"; then
  tmp="$(mktemp)"
  awk -v p="$passphrase" '/^PASSPHRASE=/ { print "PASSPHRASE=" p; next } { print }' \
    "$env_file" > "$tmp"
  mv "$tmp" "$env_file"
else
  printf 'PASSPHRASE=%s\n' "$passphrase" >> "$env_file"
fi

printf '%s' "$hash" > "$hash_file"
chmod 600 "$hash_file"
chmod 600 "$env_file" 2>/dev/null || true

printf '\nArmed.\n'
printf '  plaintext  %s (PASSPHRASE=, git-ignored, chmod 600)\n' "$env_file"
printf '  hash       %s (chmod 600, git-ignored)\n' "$hash_file"
printf '\nBefore any .env write, run:\n  scripts/env-unlock.sh\n'
printf 'The token it creates expires in 10 minutes.\n'