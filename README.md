# UMT-Traffic

React + TypeScript (Vite) front end on Supabase, deployed to Vercel.

The rules that govern this repository live in [`CLAUDE.md`](./CLAUDE.md) and are
enforced mechanically by `.claude/skills/check-policy/`. Read that before making
changes.

## Setup

```bash
npm ci
cp .env.template .env      # then fill in the two VITE_ values
npm run dev
```

For local Supabase, `supabase start` prints a URL and a publishable key. Both
local values are fixed public constants — the issuer is literally `supabase-demo`
— so there is nothing secret about them.

## Environment

Exactly two variables may reach the browser:

| Variable | Value |
|---|---|
| `VITE_SUPABASE_URL` | `http://127.0.0.1:54321` locally, `https://<ref>.supabase.co` when hosted |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_...` |

The publishable key replaces the legacy `anon` key. Supabase stops issuing
`anon` to new projects and removes the legacy keys in late 2026; see the note in
`CLAUDE.md` §2.

**Never** put the secret key (`sb_secret_...`, formerly `service_role`) in any
`VITE_*` variable. It bypasses Row Level Security entirely, and Supabase returns
HTTP 401 if it is used from a browser.

## Write gate for `.env`

Reading `.env` is forbidden to agents. Writing it requires a token that only you
can produce, because producing it needs a terminal:

```bash
scripts/env-setup.sh     # once per machine — choose your passphrase
scripts/env-unlock.sh    # per session — re-enter it, valid for 10 minutes
```

`env-unlock.sh` writes `.claude/.gate-token`; the `PreToolUse` hook checks that
token before permitting a `.env` write and consumes it afterwards, so one unlock
authorises exactly one write. An agent cannot create the token: `read -s` needs a
controlling terminal, and tool calls do not have one.

The passphrase lives in `.env` (git-ignored) and its hash in
`.claude/.gate-passphrase` (git-ignored, `chmod 600`).

### Why the passphrase is not in this file

A passphrase in a public README is one the agent can read, hash, and use to forge
a valid token. It would stop a careless agent and no deliberate one. Keeping it
outside the repository is what makes the gate a gate rather than a speed bump.

## Local checks

```bash
npm run check             # tsc + oxlint
bash scripts/check-policy.sh
bash scripts/test-guard.sh   # 58 assertions against the hook and the gate
```

The same commands run in CI on every push and pull request. `main` is the deploy
branch and requires the `ci` status check to pass.