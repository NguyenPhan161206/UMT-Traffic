import { createClient } from '@supabase/supabase-js';

/**
 * The single sanctioned Supabase client (rule 3.1). Every feature slice imports
 * from here; no slice may construct its own client.
 */

function required(name: 'VITE_SUPABASE_URL' | 'VITE_SUPABASE_PUBLISHABLE_KEY'): string {
  const value = import.meta.env[name];
  if (!value) {
    // Naming the variable, never its value (rule 2.3).
    throw new Error(
      `${name} is not set. Copy .env.template to .env and fill it in — see README.`,
    );
  }
  return value;
}

export const supabase = createClient(
  required('VITE_SUPABASE_URL'),
  required('VITE_SUPABASE_PUBLISHABLE_KEY'),
);