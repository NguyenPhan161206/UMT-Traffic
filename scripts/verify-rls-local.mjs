// Local-only RLS verification for public.profiles.
//
// Asserts the real access surface of the table against a running local stack:
// an anonymous client, and a signed-in client holding a genuine JWT. Run it
// after changing policies in supabase/migrations — a green test here is the
// only evidence that the change tightened access rather than just looking right.
//
//   npx supabase start
//   node scripts/verify-rls-local.mjs
//
// Requires VITE_SUPABASE_URL + VITE_SUPABASE_PUBLISHABLE_KEY pointing at LOCAL
// (127.0.0.1 / localhost). It signs up throwaway @example.test users and leaves
// rows behind in your local database. It refuses to run against a hosted URL.
import { execSync } from 'node:child_process';
import { createClient } from '@supabase/supabase-js';

const url = process.env.VITE_SUPABASE_URL;
const pub = process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
if (!url || !pub) {
  console.error('Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY (local only).');
  process.exit(1);
}
if (!/^https?:\/\/(127\.0\.0\.1|localhost|\[::1\])/.test(url)) {
  console.error(`Refusing to run against ${url} — this script only targets a local stack.`);
  process.exit(1);
}

const mk = () => createClient(url, pub, { auth: { persistSession: false } });
let fails = 0;
const ok = (c, m) => { if (!c) fails++; console.log(`  ${c ? 'PASS' : 'FAIL'}  ${m}`); };

const anon = mk();
const r1 = await anon.from('profiles').select('*');
ok(r1.error === null && r1.data.length === 0,
  `anon select -> ${r1.error ? `error ${r1.error.code}` : '0 rows (denied)'}`);

const au = mk();
const up = await au.auth.signUp({ email: `p_${Date.now()}@example.test`, password: 'not-a-real-password-123' });
if (up.error) { console.error('signUp failed:', up.error.message); process.exit(1); }
const myId = up.data.user.id;

const ins = await au.from('profiles').insert({ id: myId, display_name: 'probe user' }).select();
ok(!ins.error && ins.data.length === 1,
  `insert own profile -> ${ins.error ? `error ${ins.error.code}` : '1 row'}`);

const sel = await au.from('profiles').select('*');
ok(!sel.error && sel.data.length === 1, `select own profile -> ${sel.data?.length} row(s)`);

const upd = await au.from('profiles').update({ display_name: 'renamed' }).eq('id', myId).select();
ok(!upd.error && upd.data[0]?.display_name === 'renamed', 'update own profile -> renamed');
ok(new Date(upd.data[0].updated_at) > new Date(ins.data[0].updated_at),
  'updated_at advanced via trigger');

// A real second auth user, so the profiles.id foreign key is satisfied.
const bu = mk();
const up2 = await bu.auth.signUp({ email: `q_${Date.now()}@example.test`, password: 'not-a-real-password-123' });
if (up2.error) { console.error('second signUp failed:', up2.error.message); process.exit(1); }
const otherId = up2.data.user.id;
const psql = (sql) => {
  execSync(`docker exec supabase_db_UMT-Traffic psql -U postgres -d postgres -q -c "${sql}"`);
};
psql(`insert into public.profiles (id, display_name) values ('${otherId}','someone else')`);

const s2 = await au.from('profiles').select('*');
ok(s2.data.length === 1, `cannot see another user's row -> ${s2.data.length} row(s), must be 1`);

const hij = await au.from('profiles').update({ display_name: 'hijacked' }).eq('id', otherId).select();
ok(hij.data.length === 0, `update another user's row -> ${hij.data.length} affected, must be 0`);

const insOther = await au.from('profiles').insert({ id: otherId, display_name: 'forged' }).select();
ok(insOther.error?.code === '42501',
  `insert a row owned by someone else -> ${insOther.error ? `denied ${insOther.error.code}` : 'ALLOWED'}`);

// DELETE is denied in two possible ways depending on which layer stops it: a
// missing privilege yields 42501, whereas a privilege plus no RLS policy yields
// a silent 0-row no-op. Assert on the outcome (row still present) rather than
// on one specific denial mechanism.
const del = await au.from('profiles').delete().eq('id', myId).select();
const stillThere = await au.from('profiles').select('id').eq('id', myId);
const affected = del.data?.length ?? 0;
ok(affected === 0 && stillThere.data.length === 1,
  `delete own profile -> ${del.error ? `denied ${del.error.code}` : `${affected} rows affected`}, row survived: ${stillThere.data.length === 1}`);

console.log(fails ? `\n${fails} FAILURE(S)` : '\nall checks passed');
process.exit(fails ? 1 : 0);
