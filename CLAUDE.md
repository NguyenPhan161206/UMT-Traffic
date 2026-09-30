# CLAUDE.md

Microsite for a school traffic-safety quiz contest.

**Stack (fixed — no substitutions):** React + Vite SPA, TypeScript `strict`, Supabase (Auth + Postgres + RLS), Vercel static deploy from `main`.

This file is a rulebook, not a tutorial. Every rule is mandatory.
If a task appears to require breaking a rule: **STOP and ask.** Never invent a workaround.

---

## 1. Identity & Auth Boundary

1.1 `auth.uid()` is the **only** source of identity. Every public table MUST have `user_id uuid references auth.users(id)`.
1.2 MUST NOT store an `email` column in any public table (duplicated PII). Display name is a separate column from the auth email.
1.3 MUST NOT trust client-supplied `score`, `school`, `completed_at`, `user_id`, or any other field that decides an outcome. Server/DB computes those.
1.4 Auth configuration MUST live in `supabase/config.toml` (committed). MUST NOT toggle anything in the Supabase Auth Dashboard — environment state that is not reproducible is out of bounds.
1.5 MUST NOT let the client choose its own authorization outcome. Roles/permissions come from RLS only.

**OK**
```ts
const { data } = await supabase.from('submissions').insert({ user_id, answers });
```

**Not OK**
```ts
const { data } = await supabase.from('submissions').insert({ ...body, score: body.score });
```

---

## 2. Secrets & Environment

2.1 The public env whitelist is exactly two variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`. Any other `VITE_*` variable is a violation.
2.2 `service_role` key MUST live only in local `.env` for the Supabase CLI. MUST NEVER reach the browser, committed code, or any logged output.
2.3 MUST NOT read `.env` / `.env.local` content, print it, echo it, or include it in a commit message.
2.4 MUST NOT reference `process.env` ad hoc. Only the whitelisted `import.meta.env.*` accesses above.

---

## 3. Data Access

3.1 Exactly **one** Supabase client, created once in `src/lib/supabase.ts` and exported. MUST NOT call `createClient()` anywhere else.
3.2 MUST NOT hand-write SQL, raw PostgREST calls, or construct Supabase REST URLs from the browser.
3.3 MUST NOT add a second data-fetching path (direct `fetch` to Supabase, axios, etc.).
3.4 Database types MUST be generated from the Supabase schema and imported — no hand-maintained type duplicates.

---

## 4. Database & Schema

4.1 Every schema/RLS/index change MUST be a file in `supabase/migrations/` named `NNNNNN_kebab_case.sql`.
4.2 MUST NOT edit tables, policies, or RLS by hand in the Supabase Dashboard.
4.3 MUST NOT run `supabase db push` / `supabase db reset` — these are blocked by a hook. Migrations are applied by me.
4.4 Any migration containing `drop` or `delete` against a table holding contest data MUST include a preceding `supabase db dump` backup step and MUST be called out explicitly in the summary. MUST NOT run such a migration silently.

---

## 5. Dependencies

5.1 MUST NOT add any package without asking first. A proposal MUST state: package name, why it is needed, bundle-size impact, and why existing/stdlib options are insufficient.
5.2 MUST NOT add a second state manager, router, CSS framework, or HTTP client. One of each, chosen once.
5.3 MUST NOT hand-edit the lockfile.
5.4 MUST NOT add a dependency for something smaller than ~50 lines of own code. Write it instead.

---

## 6. TypeScript

6.1 `strict: true` is non-negotiable. Type errors get fixed at the source.
6.2 MUST NOT use `any`, `as`, `@ts-ignore`, `@ts-expect-error`, or `!` to silence a type error or make code "compile".
6.3 `oxlint` is the one and only linter. MUST NOT add ESLint, Biome, or a second linter. `npm run check` (= typecheck + lint) is the single gate.

**OK**
```ts
type Score = number;
function total(rows: Submission[]): Score { /* ... */ }
```

**Not OK**
```ts
function total(rows: any[]): any { return rows as unknown as Score; }
```

---

## 7. Vercel

7.1 Vercel is a runtime host only. MUST NOT create work longer than 10s, long-lived DB connections, fake cron via `setTimeout`, or temp-file writes.
7.2 MUST NOT deploy manually. No `vercel --prod`, no `npx vercel`. Deployment = git push to `main`.
7.3 MUST NOT change deploy settings in the Vercel dashboard.
7.4 Client-side routing REQUIRES `vercel.json` with a rewrite to `index.html`. MUST NOT be removed.

---

## 8. Workflow (single developer, PR-gated)

8.1 MUST NOT run `git commit` or `git push` unless I explicitly say the word `commit`. Prepare the change, show `git diff`, and stop.
8.2 Before reporting a task as done, MUST run `npm run check` and quote the real output. Never assume it passed.
8.3 `main` is the deploy branch. MUST NOT force-push `main`. MUST NOT run `git reset --hard`.
8.4 MUST NOT reformat, rename, or restructure files outside the scope of the current task.
8.5 Git hooks are the owner's gate, not mine: `pre-commit` runs `lint-staged` (oxlint on staged files), `pre-push` runs `npm run check`. MUST NOT suggest or run `--no-verify`.
8.6 `main` is protected: a merge requires a pull request whose `ci` check passed. The deploy path is branch → push → PR → green `ci` → merge → Vercel builds. MUST NOT merge a red PR, and MUST NOT suggest disabling the protection rule or `admin:repo` bypass to get a deploy through.
8.7 The job name in `.github/workflows/ci.yml` and the required status check in `main`'s branch protection are the same string (`ci`). Renaming one without the other blocks every future merge. If a rename is unavoidable, update both in the same change and say so out loud.

---

## 9. Business Rules — NOT YET DEFINED

9.1 Scoring method, duplicate-entry handling, deadlines, admin role assignment, and anti-cheat behaviour are **undefined**. There is no spec to follow.
9.2 When a task touches any of those areas: **STOP and ask.** Present the options and their trade-offs. MUST NOT invent a rule, silently pick a default, or write a "reasonable" assumption into code or comments.
9.3 Do not create placeholder business logic "to be filled in later". Leave the surface absent or clearly TODO-with-question instead.

---

## 10. Ask, don't assume

10.1 If a rule here conflicts with a request, raise the conflict before writing code.
10.2 If the correct implementation is genuinely ambiguous, choose the simplest option that satisfies the rules, implement it, and flag the choice in one line at the end of your summary.