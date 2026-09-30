const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey',
}

Deno.serve((request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'GET') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(
    JSON.stringify({
      minimum_version: '1.0.4',
      android_url:
        'https://play.google.com/store/apps/details?id=com.linkapp.church',
      ios_url: 'https://apps.apple.com/search?term=LinkApp',
      updates: [
        {
          version: '1.0.3',
          published_at: '2026-09-27',
          title: 'تحسينات على سجلات الحضور',
          summary: 'أصبح ملخص كل كشف حضور أوضح وأكثر اتساقًا مع بيانات تسجيل الحضور.',
          changes: [
            'تحديث ملخص الحضور والغياب بعد تحميل الكشوف.',
            'إظهار جميع أعضاء الفصل أو الاجتماع في الملخص، حتى عند عدم وجود تسجيل محفوظ لهم.',
          ],
        },
      ],
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
})
