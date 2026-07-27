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
  <title>دعوة للانضمام إلى LINK</title>
</head>
<body style="margin:0;padding:0;background:#f4f7fb;font-family:Tahoma,Arial,sans-serif;direction:rtl;text-align:right;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f7fb;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e6ebf2;">
          <tr>
            <td style="padding:28px 24px 12px;text-align:center;background:linear-gradient(180deg,#f8fbff 0%,#ffffff 100%);">
              <img src="${logoUrl}" alt="LINK" width="88" height="88" style="display:block;margin:0 auto 14px;border-radius:20px;" />
              <div style="font-size:24px;font-weight:800;color:#1f3b68;letter-spacing:1px;">LINK</div>
              <div style="font-size:13px;color:#6b7c93;margin-top:4px;">نظام إدارة الكنيسة</div>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 24px 0;">
              <h1 style="margin:0 0 10px;font-size:22px;color:#152238;">مرحباً ${servantName}</h1>
              <p style="margin:0 0 14px;font-size:15px;line-height:1.8;color:#425466;">
                تمت دعوتك للانضمام كخادم في <strong style="color:#1f3b68;">${churchName}</strong> عبر تطبيق LINK.
              </p>
              <p style="margin:0 0 18px;font-size:14px;line-height:1.8;color:#5d6b7a;">
                اضغط الزر أدناه لفتح التطبيق والرد على الدعوة (قبول أو رفض).
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 24px 18px;text-align:center;">
              <a href="${inviteLink}"
                 style="display:inline-block;background:#1f5fbf;color:#ffffff;text-decoration:none;padding:14px 28px;border-radius:14px;font-size:16px;font-weight:800;">
                فتح الدعوة في LINK
              </a>
            </td>
          </tr>
          <tr>
            <td style="padding:0 24px 8px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8fafc;border-radius:12px;border:1px solid #e8edf4;">
                <tr>
                  <td style="padding:14px 16px;font-size:13px;line-height:1.8;color:#425466;">
                    <div><strong>نطاق الخدمة:</strong> ${scope}</div>
                    <div><strong>الصلاحيات:</strong> ${permissions}</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 24px 8px;">
              <ol style="margin:0;padding-right:18px;font-size:14px;line-height:1.9;color:#425466;">
                <li>حمّل تطبيق LINK على هاتفك إن لم يكن مثبتاً.</li>
                <li>اضغط زر <strong>فتح الدعوة في LINK</strong>.</li>
                <li>راجع التفاصيل ثم اختر <strong>قبول</strong> أو <strong>رفض</strong>.</li>
              </ol>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 24px 26px;">
              <p style="margin:0;font-size:12px;line-height:1.7;color:#8a97a8;">
                إذا لم تكن تتوقع هذه الدعوة، يمكنك تجاهل الرسالة أو رفضها من داخل التطبيق.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    if (!resendApiKey) {
      return new Response(
        JSON.stringify({ error: 'RESEND_API_KEY is not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

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
    const fromAddress =
      Deno.env.get('INVITE_EMAIL_FROM') ?? 'LINK <onboarding@resend.dev>'
    const inviteLink = `${supabaseUrl}/functions/v1/invite-redirect?t=${invite.invite_token}`

    const html = buildArabicEmailHtml({
      churchName,
      servantName: invite.full_name,
      inviteLink,
      permissions: permissionSummary(invite),
      scope: scopeLabel(invite.assignment_scope),
      logoUrl,
    })

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromAddress,
        to: [invite.email.trim()],
        subject: `دعوة للانضمام إلى ${churchName} — LINK`,
        html,
      }),
    })

    if (!emailResponse.ok) {
      const details = await emailResponse.text()
      return new Response(
        JSON.stringify({
          error: 'Failed to send email',
          details,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    return new Response(JSON.stringify({ success: true, invite_link: inviteLink }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
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
