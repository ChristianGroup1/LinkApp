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
        const { data: churchUserIds, error: churchDeletionError } =
          await adminClient.rpc('delete_church_for_last_admin', {
            p_requester_id: user.id,
          })

        if (churchDeletionError) {
          console.error('Full church deletion failed', {
            userId: user.id,
            message: churchDeletionError.message,
          })
          return json(
            {
              error:
                'تعذر حذف الكنيسة وبياناتها. تأكد من تشغيل تحديث قاعدة البيانات الخاص بحذف آخر مدير.',
              code: 'church_delete_failed',
            },
            409,
          )
        }

        const linkedUserIds = Array.isArray(churchUserIds)
          ? churchUserIds.filter(
            (candidate): candidate is string => typeof candidate === 'string',
          )
          : []
        const uniqueUserIds = [...new Set([...linkedUserIds, user.id])]
        // Delete the requester's Auth account last so its current session is
        // available until all other linked accounts have been processed.
        uniqueUserIds.sort((left, right) =>
          left === user.id ? 1 : right === user.id ? -1 : 0
        )

        const failedUserIds: string[] = []
        for (const linkedUserId of uniqueUserIds) {
          const { error: authDeletionError } =
            await adminClient.auth.admin.deleteUser(linkedUserId, false)
          if (authDeletionError) {
            failedUserIds.push(linkedUserId)
            console.error('Linked Auth account deletion failed', {
              userId: linkedUserId,
              message: authDeletionError.message,
            })
          }
        }

        if (failedUserIds.length > 0) {
          return json(
            {
              error:
                'تم حذف بيانات الكنيسة، لكن تعذر إنهاء حذف بعض حسابات الدخول. تواصل مع الدعم.',
              code: 'auth_cleanup_incomplete',
              failed_accounts: failedUserIds.length,
            },
            500,
          )
        }

        return json({
          success: true,
          deleted_church: true,
          deleted_users: uniqueUserIds.length,
        })
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
