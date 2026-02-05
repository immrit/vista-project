import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL;
const anon = process.env.SUPABASE_ANON_KEY;
const service = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !anon || !service) {
  // eslint-disable-next-line no-console
  console.warn(
    "[vista-node-feed] Missing env vars: SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY"
  );
}

export const supabaseAnon = createClient(url, anon, {
  auth: { persistSession: false },
});

export const supabaseService = createClient(url, service, {
  auth: { persistSession: false },
});

