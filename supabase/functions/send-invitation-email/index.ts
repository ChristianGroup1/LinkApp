import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type InvitationRow = {
  id: string
  church_id: string
  full_name: string
  email: string | null
  invite_token: string
  can_take_attendance: boolean
  can_view_reports: boolean
  assignment_scope: string | null
  churches: { name_ar: string } | null
}

function permissionSummary(invitation: InvitationRow): string {
  const parts: string[] = []
  if (invitation.can_take_attendance) parts.push('تسجيل الحضور والغياب')
  if (invitation.can_view_reports) parts.push('عرض التقارير والمتابعة')
  return parts.length > 0 ? parts.join(' • ') : 'صلاحيات محددة من المدير'
}

function scopeLabel(scope: string | null): string {
  switch (scope) {
    case 'class':
      return 'فصل محدد'
    case 'meeting_classes':
      return 'كل فصول اجتماع'
    case 'meeting':
      return 'اجتماع مباشر'
    default:
      return 'مهمة محددة'
  }
}

function buildArabicEmailHtml(params: {
  churchName: string
  servantName: string
  inviteLink: string
  permissions: string
  scope: string
  logoUrl: string
}) {
  const { churchName, servantName, inviteLink, permissions, scope, logoUrl } =
    params

  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>دعوة خادم جديدة - لينك</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f7fb;font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;direction:rtl;text-align:right;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f7fb;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:540px;background-color:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,0.05);border:1px solid #e8edf5;">
          
          <!-- Header Banner with Logo -->
          <tr>
            <td style="padding:36px 28px 24px;text-align:center;background:linear-gradient(135deg,#4338ca 0%,#312e81 100%);color:#ffffff;">
              <img src="https://zowxjinnpqcldhtyjjmd.supabase.co/storage/v1/object/public/app-assets/link_logo.png" 
                   alt="LinkApp Logo" 
                   width="72" 
                   height="72" 
                   style="display:block;margin:0 auto 16px;border-radius:20px;box-shadow:0 6px 16px rgba(0,0,0,0.25);background:#ffffff;padding:4px;" />
              <h1 style="margin:0;font-size:26px;font-weight:900;letter-spacing:-0.5px;color:#ffffff;">لينك</h1>
              <p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,0.85);">نظام خدمة وإدارة الاجتماعات</p>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td style="padding:32px 28px 20px;">
              <h2 style="margin:0 0 12px;font-size:20px;font-weight:800;color:#1e293b;">مرحباً بك 🌸</h2>
              <p style="margin:0 0 16px;font-size:15px;line-height:1.8;color:#475569;">
                تمت دعوتك للانضمام كخادم في تطبيق <strong style="color:#4338ca;">لينك</strong> لمتابعة الخدمة والاجتماعات.
              </p>
              
              <div style="background-color:#f8fafc;border-radius:16px;padding:20px;margin:20px 0;border:1px solid #e2e8f0;">
                <p style="margin:0 0 8px;font-size:14px;font-weight:700;color:#334155;">💡 للبدء وتفعيل حسابك:</p>
                <p style="margin:0;font-size:13px;line-height:1.7;color:#64748b;">
                  اضغط على الزر أدناه لتأكيد قبول دعوتك وإنشاء كلمة المرور الخاصة بك للانضمام فوراً.
                </p>
              </div>

              <!-- Action Button -->
              <div style="text-align:center;margin:28px 0 16px;">
                <a href="{{ .ConfirmationURL }}"
                   style="display:inline-block;background-color:#4338ca;color:#ffffff;text-decoration:none;padding:16px 36px;border-radius:16px;font-size:16px;font-weight:800;box-shadow:0 4px 14px rgba(67,56,202,0.35);">
                  قبول الدعوة وتفعيل الحساب 🚀
                </a>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:20px 28px 28px;background-color:#f8fafc;border-top:1px solid #f1f5f9;text-align:center;">
              <p style="margin:0;font-size:12px;color:#94a3b8;line-height:1.6;">
                إذا لم تكن تتوقع هذه الدعوة، يمكنك تجاهل هذا البريد.<br/>
                تطبيق LinkApp — جميع الحقوق محفوظة.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { invitation_id } = await req.json()
    if (!invitation_id) {
      return new Response(JSON.stringify({ error: 'invitation_id is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('church_id, role')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const isAdmin =
      profile.role === 'church_admin' || profile.role === 'super_admin'
    if (!isAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: invitation, error: invitationError } = await adminClient
      .from('invitations')
      .select(
        'id, church_id, full_name, email, invite_token, can_take_attendance, can_view_reports, assignment_scope, churches(name_ar)',
      )
      .eq('id', invitation_id)
      .single()

    if (invitationError || !invitation) {
      return new Response(JSON.stringify({ error: 'Invitation not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const invite = invitation as InvitationRow
    if (invite.church_id !== profile.church_id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!invite.email?.trim()) {
      return new Response(JSON.stringify({ error: 'Invitation has no email' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const churchName = invite.churches?.name_ar ?? 'الكنيسة'
    const logoUrl =
      Deno.env.get('INVITE_EMAIL_LOGO_URL') ??
      `${supabaseUrl}/storage/v1/object/public/app-assets/link_logo.png`
    const webBaseUrl = Deno.env.get('INVITE_LINK_BASE_URL') ?? 'https://link-church-app.vercel.app/invite'
    const encodedInviteToken = encodeURIComponent(invite.invite_token)
    // Keep the HTTPS link available for manual sharing from the app, while
    // links sent by email open the installed mobile app directly.
    const webInviteLink = `${webBaseUrl}?t=${encodedInviteToken}`
    const emailInviteLink = `io.supabase.link://invite?t=${encodedInviteToken}`

    const isResendKey = !!resendApiKey && resendApiKey.trim().startsWith('re_')

    if (!isResendKey) {
      // Use native Supabase Auth inviteUserByEmail
      const { error: nativeError } = await adminClient.auth.admin.inviteUserByEmail(
        invite.email.trim(),
        {
          // {{ .ConfirmationURL }} verifies the Supabase invite first, then
          // redirects to this deep link with the servant invitation token.
          redirectTo: emailInviteLink,
          data: {
            full_name: invite.full_name,
            church_name: churchName,
            invitation_id: invite.id,
          },
        },
      )

      if (nativeError) {
        return new Response(
          JSON.stringify({
            error: 'Failed to send invitation via Supabase Auth',
            details: nativeError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        )
      }

      return new Response(
        JSON.stringify({
          success: true,
          invite_link: webInviteLink,
          email_invite_link: emailInviteLink,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    const html = buildArabicEmailHtml({
      churchName,
      servantName: invite.full_name,
      inviteLink: emailInviteLink,
      permissions: permissionSummary(invite),
      scope: scopeLabel(invite.assignment_scope),
      logoUrl,
    })

    try {
      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [invite.email.trim()],
          subject: `دعوة للانضمام إلى ${churchName} — Link`,
          html,
        }),
      })

      if (emailResponse.ok) {
        return new Response(
          JSON.stringify({
            success: true,
            invite_link: webInviteLink,
            email_invite_link: emailInviteLink,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        )
      }
    } catch {
      // Ignore Resend fetch error and fallback to Supabase Auth
    }

    // Fallback to Supabase Auth inviteUserByEmail if Resend fails
    const { error: nativeError } = await adminClient.auth.admin.inviteUserByEmail(
      invite.email.trim(),
      {
        redirectTo: emailInviteLink,
        data: {
          full_name: invite.full_name,
          church_name: churchName,
          invitation_id: invite.id,
        },
      },
    )

    if (nativeError) {
      return new Response(
        JSON.stringify({
          error: 'Failed to send email via Resend & Supabase Auth',
          details: nativeError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        invite_link: webInviteLink,
        email_invite_link: emailInviteLink,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unexpected error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
