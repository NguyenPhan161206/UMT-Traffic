#!/usr/bin/env bash
# PreToolUse deny-guard for UMT-Traffic.
# Exit 0 -> allow. Exit 2 -> block; stderr is fed back to the model.
#
# Scope: hard denials only. "Ask" decisions live in .claude/settings.json
# permissions so the user is prompted by Claude Code itself.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"

if [ -z "$payload" ]; then
  exit 0
fi

extract() {
  # $1 = json key path (tool_name | command | file_path | path | notebook_path)
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -c '
import json, sys
key = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
value = data.get("tool_name", "")
if key != "tool_name":
    ti = data.get("tool_input") or {}
    if isinstance(ti, dict):
        value = ti.get(key) or ""
        if isinstance(value, list):
            value = " ".join(str(v) for v in value)
print(str(value))
' "$1" 2>/dev/null
    return
  fi
  # Fallback: crude extraction, still catches the common cases.
  printf '%s' "$payload" | tr ',' '\n' | grep -F "\"$1\"" | head -n1 | sed 's/.*: *"\(.*\)".*/\1/'
}

tool_name="$(extract tool_name)"
command_str="$(extract command)"
path_str="$(extract file_path)$(extract path)$(extract notebook_path)"
# The body of a Write/Edit lands here. Without it, `Write src/config.ts` whose
# CONTENT is a service_role key sails straight through the path checks.
content_str="$(extract content)$(extract new_string)"

haystack="$(printf '%s\n%s\n%s\n%s' "$tool_name" "$command_str" "$path_str" "$content_str")"
lower="$(printf '%s' "$haystack" | tr '[:upper:]' '[:lower:]')"
# Collapse runs of whitespace so `supabase   db   push` cannot slip past a
# literal-substring check, and squeeze spaces around shell metacharacters.
squashed="$(printf '%s' "$lower" | tr '\t\n' '  ' | tr -s ' ')"

block() {
  printf 'BLOCKED by .claude/hooks/block-forbidden.sh — %s\n' "$1" >&2
  printf '%s\n' "$2" >&2
  exit 2
}

# --- Secrets -----------------------------------------------------------------
if printf '%s' "$lower" | grep -qE 'service[_-]role'; then
  block "service_role key handling" \
    "Rule 2.2: the service_role key lives only in local .env for the Supabase CLI. It must never be written into client code, committed files, or command output. Use VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY in the browser."
fi

# --- Forbidden Dependencies --------------------------------------------------
# Match the package as a whole word after an install/add verb, so `vuex` and
# `vue-router` are NOT caught by a `vue` substring.
if printf '%s' "$squashed" | grep -qE '(npm|pnpm|yarn|bun) (i|install|add)( --?[a-z-]+)* (axios|redux|mobx|zustand|jotai|recoil|@tanstack/react-query)( |$)'; then
  block "forbidden dependencies" \
    "Rule 5.2: no second HTTP client and no state manager. These packages are blocked; state stays in React."
fi

# --- Environment files -------------------------------------------------------
# Covers both tool paths (file_path) and shell redirections (`> .env`, `cat .env`).
# Committable templates (.env.example and friends) are exempt — they hold names, not secrets.
env_scan="${path_str//.env.example/}"
env_scan="${env_scan//.env.sample/}"
env_scan="${env_scan//.env.template/}"
env_cmd="${command_str//.env.example/}"
env_cmd="${command_str//.env.sample/}"
env_cmd="${command_str//.env.template/}"
if printf '%s\n%s' "$env_scan" "$env_cmd" | grep -qE '(^|[^A-Za-z0-9_.-])\.env([.][A-Za-z0-9._-]+)?([^A-Za-z0-9_-]|$)'; then
  # READ is always forbidden (rule 2.3): the file holds the owner's PASSPHRASE.
  # A WRITE is allowed only with a live unlock token, which only a human can
  # produce because only a human has a terminal to type the passphrase into.
  if printf '%s' "$haystack" | grep -qE '(^|[^A-Za-z0-9_.-])(read|cat|less|more|head|tail|grep|awk|sed|xxd|od|cp|print)( |$)'; then
    block "reading .env files" \
      "Rule 2.3: never read, print or echo .env / .env.local content — it holds the owner's PASSPHRASE and any local values. If a value is needed, state its NAME in your summary and let the owner fill it in. (.env.template is allowed — names only.)"
  fi

  # `set -u` is on, and the variable is absent when the hook is exercised
  # outside Claude Code (scripts/test-guard.sh), so default it to the repo root.
  project_dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  token="$project_dir/.claude/.gate-token"
  hash_file="$project_dir/.claude/.gate-passphrase"
  ttl=600
  now="$(date +%s)"

  if [ -z "$hash_file" ] || [ ! -f "$hash_file" ]; then
    block "writing .env without an armed gate" \
      "The write gate is not armed. Ask the owner to run: scripts/env-setup.sh (once), then scripts/env-unlock.sh (per session, valid 10 minutes)."
  fi

  if [ ! -f "$token" ]; then
    block "writing .env without an unlock token" \
      "Ask the owner to run scripts/env-unlock.sh and type their passphrase. There is no way for you to produce that token: it requires a controlling terminal, which you do not have."
  fi

  token_hash="$(cut -d' ' -f1 < "$token" 2>/dev/null || true)"
  token_at="$(cut -d' ' -f2 < "$token" 2>/dev/null || echo 0)"
  expect_hash="$(cat "$hash_file" 2>/dev/null || true)"

  if [ "$token_hash" != "$expect_hash" ]; then
    block "unlock token does not match this developer's passphrase" \
      "Run scripts/env-unlock.sh again, in the owner's terminal."
  fi

  if [ "$((now - token_at))" -ge "$ttl" ]; then
    rm -f "$token"
    block "unlock token expired" \
      "Tokens are valid for 600s. Ask the owner to run scripts/env-unlock.sh again."
  fi

  # Consume the token so one unlock authorises exactly one write.
  rm -f "$token"
fi
# --- Database / schema state -------------------------------------------------
# Regex, not literal substring: `supabase   db   push` must not slip through.
if printf '%s' "$squashed" | grep -qE 'supabase(@[a-z0-9._-]+)? +db +(push|reset)'; then
  block "direct database mutation" \
    "Rule 4.3: supabase db push / db reset are blocked. Write a migration file in supabase/migrations/NNNNNN_kebab_case.sql and hand it to the owner to apply."
fi

# --- Deploy ------------------------------------------------------------------
if printf '%s' "$squashed" | grep -qE 'vercel +(deploy|--prod)|npx +vercel'; then
  block "manual deploy" \
    "Rule 7.2: no manual deploys. Deployment happens when main is pushed to the git remote connected to Vercel."
fi

# --- Git safety --------------------------------------------------------------
# The `+ref` refspec IS a force push, and is what git puts on the wire.
if printf '%s' "$squashed" | grep -qE 'push .*(--force|-f)( |$)|\bpush\b[^|;&]*\+[a-z]'; then
  block "force push" \
    "Rule 8.3: main is the deploy branch and must never be force-pushed. Both --force and the +ref refspec are force pushes."
fi
if printf '%s' "$squashed" | grep -qE 'git +reset +--hard'; then
  block "git reset --hard" \
    "Rule 8.3: never run git reset --hard. Use git restore on a single file if something must be undone."
fi
if printf '%s' "$squashed" | grep -qE '(checkout|switch) +-b +main'; then
  block "branch manipulation on the deploy branch" \
    "Rule 8.3: main is the deploy branch. Branch off a feature branch instead."
fi

exit 0
