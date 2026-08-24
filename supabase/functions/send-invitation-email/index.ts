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

    const { invitation_id } = await req.json()
    if (!invitation_id) {
      return json({ error: 'invitation_id is required' }, 400)
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser()
    if (userError || !user) return json({ error: 'Unauthorized' }, 401)

    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('church_id, role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return json({ error: 'Profile not found' }, 403)
    }

    const isAdmin =
      profile.role === 'church_admin' || profile.role === 'super_admin'
    if (!isAdmin) return json({ error: 'Forbidden' }, 403)

    const { data: invitation, error: invitationError } = await adminClient
      .from('invitations')
      .select('id, church_id, full_name, email, invite_token, churches(name_ar)')
      .eq('id', invitation_id)
      .single()

    if (invitationError || !invitation) {
      return json({ error: 'Invitation not found' }, 404)
    }
    if (invitation.church_id !== profile.church_id) {
      return json({ error: 'Forbidden' }, 403)
    }

    const email = invitation.email?.trim().toLowerCase()
    if (!email) return json({ error: 'Invitation has no email' }, 400)

    const configuredWebBase =
      Deno.env.get('INVITE_LINK_BASE_URL')?.trim() ??
      'https://linkchurch.space'
    const normalizedWebBase = configuredWebBase.replace(/\/+$/, '')
    const webBaseUrl = normalizedWebBase.endsWith('/invite')
      ? normalizedWebBase
      : `${normalizedWebBase}/invite`
    const inviteLink = `${webBaseUrl}?t=${encodeURIComponent(invitation.invite_token)}`
    const churchName = invitation.churches?.name_ar ?? 'الكنيسة'

    // Existing accounts get a Supabase magic link through the configured
    // Gmail SMTP. The callback carries the same servant invitation token.
    const { data: existingProfile, error: existingProfileError } =
      await adminClient
        .from('profiles')
        .select('id')
        .ilike('email', email)
        .maybeSingle()

    if (existingProfileError) {
      return json(
        {
          error: 'Failed to check invitation account',
          details: existingProfileError.message,
        },
        500,
      )
    }

    if (existingProfile) {
      const smtpClient = createClient(supabaseUrl, supabaseAnonKey)
      const { error: magicLinkError } = await smtpClient.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: false,
          emailRedirectTo: inviteLink,
        },
      })

      if (magicLinkError) {
        return json(
          {
            error: 'Failed to send invitation via Supabase SMTP',
            details: magicLinkError.message,
          },
          502,
        )
      }

      return json({
        success: true,
        provider: 'supabase_gmail_smtp',
        delivery: 'existing_account_magic_link',
        invite_link: inviteLink,
      })
    }

    // New accounts use Supabase's native invitation email through Gmail SMTP.
    const { error: inviteError } =
      await adminClient.auth.admin.inviteUserByEmail(email, {
        redirectTo: inviteLink,
        data: {
          full_name: invitation.full_name,
          church_name: churchName,
          invitation_id: invitation.id,
          invitation_token: invitation.invite_token,
          signup_type: 'invitation',
        },
      })

    if (inviteError) {
      return json(
        {
          error: 'Failed to send invitation via Supabase SMTP',
          details: inviteError.message,
        },
        502,
      )
    }

    return json({
      success: true,
      provider: 'supabase_gmail_smtp',
      delivery: 'new_account_invite',
      invite_link: inviteLink,
    })
  } catch (error) {
    console.error('Unexpected invitation email error', error)
    return json(
      {
        error: error instanceof Error ? error.message : 'Unexpected error',
      },
      500,
    )
  }
})
