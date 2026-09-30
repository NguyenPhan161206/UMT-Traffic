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

| Check | Rule |
|---|---|
| `npm run check` (= `tsc -b --force` + `oxlint`) when `package.json` exists | 6.1 |
| `service_role` absent from `src/` | 2.2 |
| `.env*` is git-ignored and untracked | 2.2, 2.3 |
| Exactly one `createClient(` in `src/` | 3.1 |
| No `supabase.from(` outside the single client module's consumers' import path — reported as INFO, not a failure | 3.2 |
| Migration files match `NNNNNN_kebab_case.sql` | 4.1 |
| `supabase/config.toml` is present (its contents are not machine-checkable) | 1.4 |
| `package.json` scripts contain `check` | 8.2 |
| No bare `any` / `as ` / `@ts-ignore` | 6.2 |
| No `process.env` in `src/`; only whitelisted `import.meta.env.*` | 2.1, 2.4 |
| `vercel.json` present with an `index.html` rewrite | 7.4 |

## Skips

The Vite toolchain is scaffolded, so `src/` checks are live. `supabase/` does not exist yet — until it does, the migration and `config.toml` checks report `SKIP`, not `PASS`. Do not describe a `SKIP` as a pass.

## Then

If something fails, fix it at the source — no `as`, no `any`, no `@ts-expect-error` to make the check green. If a failure points at an undefined business rule (rule 9), stop and ask instead of choosing a default.
