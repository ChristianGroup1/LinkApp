-- دعوة الخادم عبر البريد الإلكتروني
-- 1) شغّل هذا الملف في Supabase SQL Editor
-- 2) اضبط Gmail SMTP من Supabase Dashboard → Authentication → SMTP Settings
-- 3) عدّل قالب Invite user في Authentication → Email Templates عند الحاجة
-- 4) انشر Edge Function: send-invitation-email
-- لا تحتاج أي مفاتيح لخدمة بريد خارجية داخل Edge Function.

alter table public.invitations
  add column if not exists email text;

create index if not exists idx_invitations_email
  on public.invitations (email)
  where email is not null and is_used = false;
