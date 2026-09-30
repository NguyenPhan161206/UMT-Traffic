---
name: check-policy
description: Run the mechanical half of the CLAUDE.md rulebook — tsc, lint, migration naming/state, and greps for the forbidden patterns (service_role, duplicate createClient, bare `any`, non-whitelisted VITE_* vars, process.env, committed .env). Use before reporting any task as done, and after any change to supabase/migrations, .claude/settings.json, or package.json. Does not read .env files and does not touch the network or the database.
---

# check-policy

Mechanical gate. It proves nothing that requires judgement — it only catches the violations a machine can see. Anything about authorisation correctness, schema design, or business rules stays a human/`stack-guard` decision.

## Run

```bash
bash .claude/skills/check-policy/scripts/check-policy.sh
```

Exit code is `0` when every check passes, `1` otherwise. Quote the raw output in your reply — never summarise a failure as a pass.

## What it checks

| Check | Rule | Severity |
|---|---|---|
| `npm run check` (= `tsc -b --force` + `oxlint`) when `package.json` exists | 6.1 | FAIL |
| `tsc -p tsconfig.app.json --noEmit` — the app project, not the root solution file | 6.1 | FAIL |
| `service_role` absent from `src/` | 2.2 | FAIL |
| No `.env*` secret file tracked; every `.env*` on disk is git-ignored; `.env.example` / `.env.template` are the exemptions | 2.2, 2.3 | FAIL |
| `.env.template` holds variable names only — every value empty | 2.5 | FAIL |
| Exactly one `createClient(` call site, in `src/lib/supabase.ts` | 3.1 | FAIL |
| No hand-built PostgREST / REST URL, no direct `fetch()` in `src/` (`.rpc()` on the sanctioned client is fine) | 3.2, 3.3 | FAIL |
| Migration files match `NNNNNN_kebab_case.sql` | 4.1 | FAIL |
| No `any`, non-null `!`, `@ts-ignore`, `@ts-expect-error` — via oxlint, not grep | 6.2 | FAIL |
| `supabase.from()` outside `src/lib/`; type assertions | 3.2, 6.2 | INFO |
| `supabase/config.toml` present (contents are not machine-checkable) | 1.4 | PASS/SKIP |
| `vercel.json` present with an `index.html` rewrite | 7.4 | FAIL |

Anything the linter cannot express without false positives stays INFO, never FAIL. `as` is the case in point: `import * as ns` and every re-export would match, so it is reported for a human to judge.

`scripts/test-guard.sh` (44 assertions) is the test suite for the PreToolUse hook itself, not for this skill. Run it after editing `.claude/hooks/block-forbidden.sh`.

## Skips

The Vite toolchain is scaffolded, so `src/` checks are live. `supabase/` does not exist yet — until it does, the migration and `config.toml` checks report `SKIP`, not `PASS`. Do not describe a `SKIP` as a pass.

## Then

If something fails, fix it at the source — no `as`, no `any`, no `@ts-expect-error` to make the check green. If a failure points at an undefined business rule (rule 9), stop and ask instead of choosing a default.
