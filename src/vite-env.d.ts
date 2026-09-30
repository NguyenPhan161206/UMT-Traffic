/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Rule 2.1 — `sb_publishable_...` (or a local Supabase constant), never a secret key. */
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}