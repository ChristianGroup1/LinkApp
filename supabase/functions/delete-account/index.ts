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

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('church_id, role')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError) {
      console.error('Account profile lookup failed', {
        userId: user.id,
        message: profileError.message,
      })
      return json({ error: 'تعذر التحقق من مسؤوليات الحساب الآن.' }, 500)
    }

    if (
      profile?.church_id &&
      (profile.role === 'church_admin' || profile.role === 'super_admin')
    ) {
      const { count, error: adminsError } = await adminClient
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('church_id', profile.church_id)
        .eq('is_active', true)
        .in('role', ['church_admin', 'super_admin'])
        .neq('id', user.id)

      if (adminsError) {
        console.error('Church admins lookup failed', {
          userId: user.id,
          message: adminsError.message,
        })
        return json({ error: 'تعذر التحقق من مسؤولي الخدمة الآن.' }, 500)
      }

      if ((count ?? 0) === 0) {
        return json(
          {
            error:
              'لا يمكن حذف آخر مدير للكنيسة. عيّن مديرًا آخر أولًا ثم أعد المحاولة.',
            code: 'last_church_admin',
          },
          409,
        )
      }
    }

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
            'تعذر حذف الحساب بسبب ارتباطه ببيانات خدمة محفوظة. شغّل تحديث قاعدة البيانات الخاص بحذف الحساب ثم حاول مرة أخرى.',
          code: 'account_delete_conflict',
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
