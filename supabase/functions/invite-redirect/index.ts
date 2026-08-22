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

  const headingText = valid
    ? `مرحباً <strong>${escapeHtml(inviteeName || 'خادم')}</strong>، تمت دعوتك للخدمة في <strong>${escapeHtml(churchName || 'الكنيسة')}</strong>.`
    : status === 'declined'
      ? 'تم رفض هذه الدعوة مسبقاً.'
      : status === 'used'
        ? 'تم استخدام هذه الدعوة بالفعل.'
        : 'جاري فتح تطبيق Link ومتابعة الدعوة...'

  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>دعوة للانضمام — Link</title>
  <script>
    function openApp() {
      window.location.href = ${JSON.stringify(appLink)};
    }
    window.addEventListener('load', function () {
      setTimeout(openApp, 100);
    });
  </script>
</head>
<body style="margin:0;padding:24px;background:#f4f7fb;font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;direction:rtl;text-align:center;">
  <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:20px;padding:32px 24px;border:1px solid #e6ebf2;box-shadow:0 10px 25px rgba(0,0,0,0.04);">
    <h1 style="margin:0 0 12px;font-size:26px;font-weight:900;color:#1f3b68;">LinkApp</h1>
    <p style="margin:0 0 16px;font-size:16px;line-height:1.8;color:#425466;">
      ${headingText}
    </p>
    ${scope ? `<p style="margin:0 0 20px;font-size:14px;color:#5d6b7a;">نطاق الخدمة: ${escapeHtml(scope)}</p>` : ''}
    <a href="${escapeHtml(appLink)}" onclick="openApp(); return false;"
       style="display:inline-block;background:#4338ca;color:#fff;text-decoration:none;padding:16px 28px;border-radius:14px;font-weight:800;font-size:16px;box-shadow:0 4px 14px rgba(67,56,202,0.3);">
      فتح التطبيق والرد على الدعوة 🚀
    </a>
    <p style="margin:20px 0 0;font-size:12px;color:#8a97a8;line-height:1.5;">
      إذا لم يفتح التطبيق تلقائياً، اضغط الزر أعلاه بعد فتح التثبيت.
    </p>
  </div>
</body>
</html>`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
      },
    })
  }

  try {
    const url = new URL(req.url)
    const token = url.searchParams.get('t')?.trim()
    const responseHeaders = new Headers()
    responseHeaders.set('Access-Control-Allow-Origin', '*')
    responseHeaders.set('Content-Type', 'text/html; charset=utf-8')

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
          headers: responseHeaders,
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
    // The trailing slash also opens Android builds whose intent filter expects
    // an invite path, while remaining compatible with newer builds.
    const appLink = `io.supabase.link://invite/?t=${encodeURIComponent(token)}`

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
      headers: responseHeaders,
    })
  } catch (error) {
    const errorHeaders = new Headers()
    errorHeaders.set('Access-Control-Allow-Origin', '*')
    errorHeaders.set('Content-Type', 'application/json')
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unexpected error',
      }),
      {
        status: 500,
        headers: errorHeaders,
      },
    )
  }
})
