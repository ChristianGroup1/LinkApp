import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
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

function buildPage(params: {
  churchName: string
  inviteeName: string
  scope: string
  appLink: string
  valid: boolean
  status?: string
}) {
  const { churchName, inviteeName, scope, appLink, valid, status } = params

  if (!valid) {
    const message =
      status === 'declined'
        ? 'تم رفض هذه الدعوة مسبقاً.'
        : status === 'used'
          ? 'تم استخدام هذه الدعوة بالفعل.'
          : 'رابط الدعوة غير صالح أو منتهي.'

    return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>دعوة LINK</title>
</head>
<body style="margin:0;padding:24px;background:#f4f7fb;font-family:Tahoma,Arial,sans-serif;direction:rtl;text-align:center;">
  <div style="max-width:480px;margin:40px auto;background:#fff;border-radius:18px;padding:28px;border:1px solid #e6ebf2;">
    <h1 style="margin:0 0 12px;font-size:22px;color:#152238;">LINK</h1>
    <p style="margin:0;font-size:15px;line-height:1.8;color:#5d6b7a;">${escapeHtml(message)}</p>
  </div>
</body>
</html>`
  }

  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>دعوة للانضمام — LINK</title>
  <script>
    function openApp() {
      window.location.href = ${JSON.stringify(appLink)};
    }
    window.addEventListener('load', function () {
      setTimeout(openApp, 300);
    });
  </script>
</head>
<body style="margin:0;padding:24px;background:#f4f7fb;font-family:Tahoma,Arial,sans-serif;direction:rtl;text-align:center;">
  <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:18px;padding:28px;border:1px solid #e6ebf2;">
    <h1 style="margin:0 0 10px;font-size:24px;color:#1f3b68;">LINK</h1>
    <p style="margin:0 0 16px;font-size:15px;line-height:1.8;color:#425466;">
      مرحباً <strong>${escapeHtml(inviteeName)}</strong>،
      تمت دعوتك للخدمة في <strong>${escapeHtml(churchName)}</strong>.
    </p>
    <p style="margin:0 0 20px;font-size:14px;color:#5d6b7a;">نطاق الخدمة: ${escapeHtml(scope)}</p>
    <a href="${escapeHtml(appLink)}" onclick="openApp(); return false;"
       style="display:inline-block;background:#1f5fbf;color:#fff;text-decoration:none;padding:14px 24px;border-radius:12px;font-weight:700;font-size:15px;">
      فتح التطبيق والرد على الدعوة
    </a>
    <p style="margin:18px 0 0;font-size:12px;color:#8a97a8;">
      إذا لم يفتح التطبيق تلقائياً، اضغط الزر أعلاه بعد تثبيت LINK.
    </p>
  </div>
</body>
</html>`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const token = url.searchParams.get('t')?.trim()
    if (!token) {
      return new Response(
        buildPage({
          valid: false,
          churchName: '',
          inviteeName: '',
          scope: '',
          appLink: '',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
        },
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const adminClient = createClient(supabaseUrl, serviceRoleKey)

    const { data, error } = await adminClient.rpc('get_invitation_by_token', {
      p_token: token,
    })

    if (error) {
      throw error
    }

    const preview = data as Record<string, unknown>
    const valid = preview.valid === true
    const appLink = `io.supabase.link://invite?t=${encodeURIComponent(token)}`

    const html = buildPage({
      valid,
      status: typeof preview.status === 'string' ? preview.status : undefined,
      churchName:
        typeof preview.church_name === 'string' ? preview.church_name : 'الكنيسة',
      inviteeName:
        typeof preview.invitee_name === 'string' ? preview.invitee_name : 'خادم',
      scope: scopeLabel(
        typeof preview.assignment_scope === 'string'
          ? preview.assignment_scope
          : null,
      ),
      appLink,
    })

    return new Response(html, {
      status: valid ? 200 : 410,
      headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' },
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
