import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

function requireEnvironment(name: string, fallback?: string) {
  const value = process.env[name] ?? (fallback ? process.env[fallback] : undefined);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();

  return createServerClient(
    requireEnvironment('NEXT_PUBLIC_SUPABASE_URL', 'SUPABASE_URL'),
    requireEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY', 'SUPABASE_ANON_KEY'),
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            // Server Components cannot always write cookies. The next Server
            // Action or route request will persist a refreshed session.
          }
        },
      },
    },
  );
}

