import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser()
    if (userError || !user) return json({ error: 'Unauthorized' }, 401)

    // This function is the trusted boundary for account deletion. The service
    // role key remains server-side and the target ID always comes from the
    // verified access token, never from request input.
    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const { error: deletionError } = await adminClient.auth.admin.deleteUser(
      user.id,
      false,
    )

    if (deletionError) {
      console.error('Account deletion failed', {
        userId: user.id,
        message: deletionError.message,
      })
      return json(
        {
          error:
            'تعذر حذف الحساب الآن. تأكد من نقل مسؤولية الخدمة ثم حاول مرة أخرى.',
        },
        409,
      )
    }

    return json({ success: true })
  } catch (error) {
    console.error('Unexpected account deletion error', error)
    return json({ error: 'تعذر حذف الحساب الآن. حاول مرة أخرى لاحقاً.' }, 500)
  }
})
