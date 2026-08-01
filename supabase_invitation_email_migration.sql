-- دعوة الخادم عبر البريد الإلكتروني
-- 1) شغّل هذا الملف في Supabase SQL Editor
-- 2) ارفع شعار التطبيق إلى Storage:
--    Bucket عام: app-assets
--    المسار: link_logo.png  (يفضّل نسخة مضغوطة ~200KB للبريد)
-- 3) انشر Edge Function: send-invitation-email
-- 4) أضف Secrets في Supabase Dashboard → Edge Functions:
--    RESEND_API_KEY=...
--    INVITE_EMAIL_FROM="Link <noreply@your-domain.com>"
--    INVITE_EMAIL_LOGO_URL=https://YOUR_PROJECT.supabase.co/storage/v1/object/public/app-assets/link_logo.png

alter table public.invitations
  add column if not exists email text;

create index if not exists idx_invitations_email
  on public.invitations (email)
  where email is not null and is_used = false;
