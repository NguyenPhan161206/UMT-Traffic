#!/usr/bin/env bash
# Exercises block-forbidden.sh against a table of payloads. Run from the repo root.
HOOK=".claude/hooks/block-forbidden.sh"
pass=0; fail=0

expect() { # expect <block|allow> <label> <tool_name> <json tool_input> [CLAUDE_PROJECT_DIR]
  local want="$1" label="$2" name="$3" input="$4" got
  printf '{"tool_name":"%s","tool_input":%s}' "$name" "$input" \
    | CLAUDE_PROJECT_DIR="${5:-}" bash "$HOOK" >/dev/null 2>/tmp/hook-err.txt
  got=$?
  if [ "$got" = "2" ]; then got=block; else got=allow; fi
  if [ "$got" = "$want" ]; then
    printf '  ok    %-6s %s\n' "$want" "$label"
    pass=$((pass+1))
  else
    printf '  WRONG expected=%s got=%s  [%s]\n' "$want" "$got" "$label"
    printf '        %s\n' "$(head -n1 /tmp/hook-err.txt)"
    fail=$((fail+1))
  fi
}

echo "== must BLOCK: secrets (rule 2.2)"
expect block 'service_role in command'      Bash  '{"command":"echo SUPABASE_SERVICE_ROLE_KEY=abc"}'
expect block 'service-role in path'         Write '{"file_path":"/r/src/service-role.ts","content":"export const k = 1"}'
expect block 'service_role in file name'    Write '{"file_path":"/r/supabase/service_role.ts","content":"export const k = 1"}'
expect block 'service_role in file CONTENT' Write '{"file_path":"/r/src/config.ts","content":"const k=\"eyJhbGciOiJIUzI1NiJ9\"; // service_role"}'
expect block 'service_role in new_string'   Edit  '{"file_path":"/r/src/a.ts","old_string":"a","new_string":"b service_role"}'

echo "== must BLOCK: reading env files (rule 2.3)"
expect block 'cat .env'                     Bash  '{"command":"cat .env"}'
expect block 'cat .env.local'               Bash  '{"command":"cat .env.local"}'
expect block 'read .env via Read'           Read  '{"file_path":"/r/.env"}'
expect block 'read .env.production'         Read  '{"file_path":"/r/.env.production"}'
expect block 'cp .env.example .env'         Bash  '{"command":"cp .env.example .env"}'
expect block 'head .env'                    Bash  '{"command":"head -5 .env"}'
expect block 'grep in .env'                 Bash  '{"command":"grep PASSPHRASE .env"}'

echo "== must BLOCK: database (rule 4.3)"
expect block 'supabase db push'             Bash  '{"command":"supabase db push --linked"}'
expect block 'supabase db reset'            Bash  '{"command":"supabase db reset --local"}'
expect block 'padded-whitespace variant'    Bash  '{"command":"supabase   db   push"}'
expect block 'tab-separated variant'        Bash  '{"command":"supabase\tdb\tpush"}'

echo "== must BLOCK: deploy (rule 7.2)"
expect block 'vercel --prod'                Bash  '{"command":"vercel --prod"}'
expect block 'vercel deploy'                Bash  '{"command":"vercel deploy"}'
expect block 'npx vercel'                   Bash  '{"command":"npx vercel"}'
expect block 'padded vercel deploy'         Bash  '{"command":"vercel   deploy   --prod"}'

echo "== must BLOCK: git safety (rule 8.3)"
expect block 'push --force'                 Bash  '{"command":"git push --force origin main"}'
expect block 'push -f'                      Bash  '{"command":"git push -f"}'
expect block '+ref refspec force push'      Bash  '{"command":"git push origin +main"}'
expect block 'reset --hard'                 Bash  '{"command":"git reset --hard HEAD~1"}'
expect block 'checkout -b main'             Bash  '{"command":"git checkout -b main"}'

echo "== must BLOCK: forbidden deps (rule 5.2)"
expect block 'npm install axios'            Bash  '{"command":"npm install axios"}'
expect block 'npm i redux'                  Bash  '{"command":"npm i redux"}'
expect block 'pnpm add zustand'             Bash  '{"command":"pnpm add zustand"}'
expect block 'yarn add redux'               Bash  '{"command":"yarn add redux"}'

echo "== must ALLOW"
expect allow '.env.example written'         Write '{"file_path":"/r/.env.example","content":"VITE_SUPABASE_URL="}'
expect allow '.env.template written'        Write '{"file_path":"/r/.env.template","content":"VITE_SUPABASE_URL="}'
expect allow '.env.template read'           Read  '{"file_path":"/r/.env.template"}'
expect allow '.env.example edited'          Edit  '{"file_path":"/r/.env.example","old_string":"a","new_string":"b"}'
expect allow '.env.example read'            Read  '{"file_path":"/r/.env.example"}'
expect allow 'vuex (not the vue substring)' Bash  '{"command":"npm install vuex"}'
expect allow 'vue-router'                   Bash  '{"command":"npm install vue-router"}'
expect allow 'tanstack query'               Bash  '{"command":"npm install @tanstack/react-query-devtools"}'
expect allow 'npm run check'                Bash  '{"command":"npm run check"}'
expect allow 'npx tsc --noEmit'             Bash  '{"command":"npx tsc --noEmit"}'
expect allow 'git status'                   Bash  '{"command":"git status --short"}'
expect allow 'git diff'                     Bash  '{"command":"git diff"}'
expect allow 'git log'                      Bash  '{"command":"git log --oneline -10"}'
expect allow 'check-policy'                 Bash  '{"command":"bash .claude/skills/check-policy/scripts/check-policy.sh"}'
expect allow 'edit src'                     Edit  '{"file_path":"/r/src/lib/supabase.ts"}'
expect allow 'edit CLAUDE.md'               Edit  '{"file_path":"/r/CLAUDE.md"}'
expect allow 'read migration'               Read  '{"file_path":"/r/supabase/migrations/000001_init.sql"}'
expect allow 'eslint (for contrast)'        Bash  '{"command":"npm install --save-dev eslint"}'

# --- .env write gate -------------------------------------------------------
# Exercised against a throwaway project dir so the real repo's real gate state
# (and any real token) is never touched or consumed.
# Fail loudly. If mktemp cannot create the dir (disk full, TMPDIR unwritable)
# then $GATE_DIR is empty, every path below silently resolves to the repo root,
# and the gate assertions below "pass" while testing nothing at all — which is
# exactly the failure mode this suite exists to catch.
if ! GATE_DIR="$(mktemp -d)"; then
  printf 'FATAL: mktemp -d failed (disk full? TMPDIR unwritable?). Gate assertions would be meaningless.\n' >&2
  exit 1
fi
[ -d "$GATE_DIR" ] || { printf 'FATAL: GATE_DIR=%s is not a directory\n' "$GATE_DIR" >&2; exit 1; }
trap 'rm -rf "$GATE_DIR"' EXIT
mkdir -p "$GATE_DIR/.claude"
REAL_HASH="$(printf '%s' 'correct horse battery staple' | sha256sum | cut -d' ' -f1)"
printf '%s' "$REAL_HASH" > "$GATE_DIR/.claude/.gate-passphrase"

write_env='{"command":"echo FOO=bar > .env"}'

echo "== gate: .env write WITHOUT a token"
expect block 'write, gate not armed'        Bash "$write_env" "$GATE_DIR"

printf '%s %s\n' "$REAL_HASH" "$(date +%s)" > "$GATE_DIR/.claude/.gate-token"
expect allow 'write, fresh valid token'     Bash "$write_env" "$GATE_DIR"
# The hook consumes the token, so a replay of the same write must now fail.
expect block 'write, token already spent'   Bash "$write_env" "$GATE_DIR"

printf '%s %s\n' "$REAL_HASH" "$(( $(date +%s) - 601 ))" > "$GATE_DIR/.claude/.gate-token"
expect block 'write, token expired (601s)'  Bash "$write_env" "$GATE_DIR"

printf '%s %s\n' "$REAL_HASH" "$(( $(date +%s) - 599 ))" > "$GATE_DIR/.claude/.gate-token"
expect allow 'write, token 599s (in TTL)'   Bash "$write_env" "$GATE_DIR"

printf 'deadbeef %s\n' "$(date +%s)" > "$GATE_DIR/.claude/.gate-token"
expect block 'write, token hash mismatch'   Bash "$write_env" "$GATE_DIR"

: > "$GATE_DIR/.claude/.gate-token"
expect block 'write, token empty'           Bash "$write_env" "$GATE_DIR"

rm -f "$GATE_DIR/.claude/.gate-passphrase"
printf '%s %s\n' "$REAL_HASH" "$(date +%s)" > "$GATE_DIR/.claude/.gate-token"
expect block 'write, hash file removed'     Bash "$write_env" "$GATE_DIR"

# The template must stay writable with no token at all.
expect allow 'write .env.template, no gate' Write '{"file_path":"/r/.env.template","content":"X=1"}' "$GATE_DIR"
expect allow 'write .env.example, no gate'  Write '{"file_path":"/r/.env.example","content":"X=1"}' "$GATE_DIR"
# And a live token must not unlock reading.
printf '%s %s\n' "$REAL_HASH" "$(date +%s)" > "$GATE_DIR/.claude/.gate-token"
expect block 'read .env even with token'    Bash '{"command":"cat .env"}' "$GATE_DIR"

printf '\nhook test: %d ok, %d wrong\n' "$pass" "$fail"
[ "$fail" -eq 0 ]