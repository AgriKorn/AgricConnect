import { createClient } from '@supabase/supabase-js';
import { env } from './env';

const supabaseUrl = env.SUPABASE_URL || 'https://elqvrqydxpykxurmziky.supabase.co';
const supabaseAnonKey = env.SUPABASE_ANON_KEY || 'dev_dummy_anon_key';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false },
});
