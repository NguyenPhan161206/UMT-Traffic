#!/usr/bin/env bash
# check-policy — mechanical enforcement of the CLAUDE.md rulebook.
# Exit 0 = all checks passed (SKIP counted as neither pass nor fail).
# Exit 1 = at least one FAIL.
# Never reads .env contents. Never touches the network or the database.

set -uo pipefail

# Resolve the repo root: prefer git, fall back to walking up from this script.
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$_here" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then ROOT="$(cd "$_here/../../../.." && pwd)"; fi
cd "$ROOT" || exit 1

fails=0
skips=0
passes=0

ok()   { printf '  PASS  %s\n' "$1"; passes=$((passes+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; [[ $# -gt 1 ]] && printf '        %s\n' "$2"; fails=$((fails+1)); }
skip() { printf '  SKIP  %s\n' "$1"; skips=$((skips+1)); }
info() { printf '  INFO  %s\n' "$1"; }
head2() { printf '\n== %s\n' "$1"; }

# hits <regex> <ext ext ...> <dir> — grep with several --include patterns.
# (grep's --include uses fnmatch: brace groups like *.{ts,tsx} silently match nothing.)
hits() {
  local ext args=()
  for ext in $2; do args+=("--include=*.$ext"); done
  grep -rnE "${args[@]}" --exclude-dir=node_modules --exclude-dir=dist "$1" "$3" 2>/dev/null
}

# --- 1. TypeScript + lint ----------------------------------------------------
head2 "TypeScript & lint (rule 6.1)"
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  # mktemp, not a fixed /tmp path: two concurrent runs (pre-push + CI, or two
  # agents) would otherwise clobber each other's diagnostics.
  npm_log="$(mktemp)"; tsc_log="$(mktemp)"
  # shellcheck disable=SC2064  # expand $npm_log now, on purpose
  trap "rm -f '$npm_log' '$tsc_log'" EXIT

  if npm run 2>/dev/null | grep -qE '^ +check$'; then
    if npm run check >"$npm_log" 2>&1; then
      ok "npm run check"
    else
      bad "npm run check" "$(tail -n 15 "$npm_log" | tr '\n' ' ')"
    fi
  else
    skip "no npm 'check' script yet (rule 8.2 wants one)"
  fi

  # Type-check the app project explicitly. The root tsconfig.json is a
  # `files: []` + references solution file, so `tsc -p tsconfig.json` checks
  # ZERO source files and would report a green that means nothing.
  if [ -x node_modules/.bin/tsc ] && [ -f tsconfig.app.json ]; then
    if node_modules/.bin/tsc -p tsconfig.app.json --noEmit >"$tsc_log" 2>&1; then
      ok "tsc -p tsconfig.app.json --noEmit"
    else
      bad "tsc -p tsconfig.app.json --noEmit" "$(tail -n 8 "$tsc_log" | tr '\n' ' ')"
    fi
  else
    skip "tsconfig.app.json absent"
  fi
else
  skip "no package.json"
fi

# --- 2. Secrets (rules 2.1, 2.2, 2.3) ----------------------------------------
head2 "Secrets & environment (rules 2.1-2.3)"
if [ -d src ]; then
  if out="$(hits 'service_role|service-role' 'ts tsx js jsx' src)"; then
    bad "service_role in src/" "$(printf '%s' "$out" | head -n 3 | tr '\n' ' ')"
  else ok "no service_role in src/"; fi

  if out="$(hits 'process\.env' 'ts tsx js jsx' src)"; then
    bad "process.env in src/" "$(printf '%s' "$out" | head -n 3 | tr '\n' ' ')"
  else ok "no process.env in src/"; fi

  bad_vars=""
  while IFS= read -r name; do
    case "$name" in
      VITE_SUPABASE_URL|VITE_SUPABASE_ANON_KEY) ;;
      "") ;;
      *) bad_vars="$bad_vars $name" ;;
    esac
  done < <(grep -rhoE 'import\.meta\.env\.[A-Za-z_][A-Za-z0-9_]*' src 2>/dev/null | sed 's/.*\.//' | sort -u)
  if [ -n "$bad_vars" ]; then
    bad "non-whitelisted VITE_* var(s)" "$bad_vars"
  else
    ok "only whitelisted VITE_* vars referenced"
  fi
else
  skip "src/ absent"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  # Quote every pathspec so the SHELL does not expand the glob — `git ls-files
  # .env.*` unquoted expands to whatever matches on disk, and the script then
  # flags the legitimate .env.example template as a leaked secret. Ask git to
  # do the matching, then subtract the sanctioned templates.
  tracked="$(git ls-files -- '.env' '.env.*' '.env.local' \
    | grep -vE '(^|/)\.env\.(example|sample|template)$' | tr '\n' ' ')"
  if [ -n "$tracked" ]; then
    bad "env file(s) tracked in git" "$tracked"
  else ok "no .env* secret file tracked in git"; fi

  # Every .env* on disk must be ignored. .env.example is the one exemption.
  while IFS= read -r f; do
    case "$f" in
      */.env.example|*/.env.sample|*/.env.template|.env.example|.env.sample|.env.template) continue ;;
    esac
    if git check-ignore -q "$f" 2>/dev/null; then ok "$f is git-ignored"
    else bad "$f is not git-ignored" "add .env / .env.* to .gitignore (keep the !.env.example exemption)"; fi
  done < <(find . -path ./node_modules -prune -o -path ./.git -prune -o -name '.env' -print -o -name '.env.*' -print 2>/dev/null)
else
  skip "not a git repo yet"
fi

# --- 3. Data access (rules 3.1, 3.2) -----------------------------------------
head2 "Data access (rules 3.1-3.2)"
if [ -d src ]; then
  # Count CALL SITES, not files. Two calls in one file is still two clients.
  n="$(hits 'createClient[[:space:]]*\\(' 'ts tsx js jsx' src | wc -l | tr -d ' ')"
  if [ "$n" = "1" ]; then
    site="$(hits 'createClient[[:space:]]*\\(' 'ts tsx js jsx' src | head -n1 | cut -d: -f1)"
    case "$site" in
      src/lib/supabase.ts) ok "exactly one createClient(), in src/lib/supabase.ts" ;;
      *) bad "createClient() must live in src/lib/supabase.ts (rule 3.1)" "found it in $site" ;;
    esac
  elif [ "$n" = "0" ]; then
    skip "no createClient() call found yet"
  else
    bad "createClient() called $n times (rule 3.1 allows exactly one)" \
      "$(hits 'createClient[[:space:]]*\\(' 'ts tsx js jsx' src | cut -d: -f1 | sort -u | tr '\n' ' ')"
  fi

  if out="$(grep -rn 'supabase\.from(' src --include='*.ts' --include='*.tsx' 2>/dev/null | grep -v 'src/lib/')"; then
    info "supabase.from() used outside src/lib/ (fine if it imports the single client):"
    printf '%s\n' "$out" | head -n 5 | sed 's/^/        /'
  fi

  # .rpc() is a first-class method of the sanctioned client (rule 3.1) and
  # `prefetch(` is not `fetch(`. Only genuinely raw transport is a violation.
  if out="$(hits 'rest/v1|@supabase/postgrest' 'ts tsx' src)"; then
    bad "raw PostgREST / hand-built REST URL — rule 3.2 forbids it" \
      "$(printf '%s\n' "$out" | head -n 5 | tr '\n' ' ')"
  else ok "no hand-built PostgREST/REST path in src/"; fi

  if out="$(hits '[^A-Za-z0-9_]fetch[[:space:]]*\\(' 'ts tsx' src)"; then
    bad "fetch() in src/ — rule 3.3 forbids a second data path; use the single client" \
      "$(printf '%s\n' "$out" | head -n 5 | tr '\n' ' ')"
  else ok "no direct fetch() data path in src/"; fi
else
  skip "src/ absent"
fi

# --- 4. Schema (rules 1.4, 4.1) ---------------------------------------------
head2 "Schema & migrations (rules 1.4, 4.1)"
if [ -d supabase/migrations ]; then
  # Do NOT use `find -regex` here: its dialect rejects {6,} and (...)+ while
  # grep -E accepts them, so a correct filename silently FAILS the test.
  # Bash's =~ supports both. Tested against 000001_init.sql (accept) and
  # 000002_add_users.sql / BadName.sql (reject) — rule 4.1 says kebab-case.
  bad_files=""
  while IFS= read -r f; do
    base="$(basename "$f")"
    if ! [[ "$base" =~ ^[0-9]{6,}_[a-z0-9]+(-[a-z0-9]+)*\.sql$ ]]; then
      bad_files="$bad_files $f"
    fi
  done < <(find supabase/migrations -type f -name '*.sql' 2>/dev/null)
  if [ -n "$bad_files" ]; then
    bad "migration file name must be NNNNNN_kebab_case.sql (rule 4.1)" "$bad_files"
  else ok "migration filenames valid"; fi
else
  skip "supabase/migrations/ absent"
fi
if [ -f supabase/config.toml ]; then ok "supabase/config.toml present (auth config is committed)"
else skip "supabase/config.toml absent"; fi

# --- 5. Type assertions (rule 6.2) -------------------------------------------
head2 "Type assertions (rule 6.2)"
if [ -d src ] && [ -x node_modules/.bin/oxlint ]; then
  # oxlint, not grep. `any`, `!` and the ts-comments are real rules, and grep
  # misses them: `\s`/`\b` are GNU-only, and `as string` / `as const` escape a
  # pattern that only accepts an uppercase target.
  if out="$(node_modules/.bin/oxlint -A all \
      -D typescript/no-explicit-any \
      -D typescript/no-non-null-assertion \
      -D typescript/ban-ts-comment \
      src 2>&1)"; then
    ok "no any / non-null assertion / ts-comments (oxlint)"
  else
    bad "rule 6.2 violation caught by oxlint:" "$(printf '%s' "$out" | grep -E 'error|warning' | head -n 5 | tr '\n' ' ')"
  fi

  # `as` cannot be expressed as a linter rule without false-positiving every
  # `import * as ns` and every re-export, so it stays INFO: report, don't block.
  if out="$(hits '(^|[=(,:;\[!&|?]|^[[:space:]]+)as[[:space:]]+(const|[A-Za-z_][A-Za-z0-9_]*(\[\])?|(unknown|string|number|boolean))' 'ts tsx' src | grep -vE 'as (default|namespace|const enum)')"; then
    info "type assertions found — rule 6.2: each must be justified, not a silencer:"
    printf '%s\n' "$out" | head -n 5 | sed 's/^/        /'
  else ok "no type assertions"; fi
elif [ ! -d src ]; then
  skip "src/ absent"
else
  skip "oxlint not installed (npm install first)"
fi

# --- 6. Vercel (rule 7.4) ----------------------------------------------------
head2 "Vercel (rule 7.4)"
if [ -f vercel.json ]; then
  if grep -q 'index.html' vercel.json 2>/dev/null; then ok "vercel.json rewrites to index.html"
  else bad "vercel.json has no index.html rewrite" "client-side routing breaks on refresh"; fi
else
  skip "vercel.json absent"
fi

# --- Summary -----------------------------------------------------------------
printf '\n----------------------------------------\n'
printf 'check-policy: %d pass, %d fail, %d skip\n' "$passes" "$fails" "$skips"
if [ "$fails" -gt 0 ]; then
  printf 'RESULT: FAIL — fix the FAIL lines above before reporting the task as done.\n'
  exit 1
fi
printf 'RESULT: OK — mechanical checks pass. Rule 9 (business rules) and the\n'
printf 'stack-guard review are still required before declaring a task done.\n'
exit 0
