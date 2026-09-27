# LinkApp Supabase Auth email templates

These HTML templates use the Link blue-and-white email design and the public
logo at `https://linkchurch.space/link-logo.png`.

Apply them in Supabase Dashboard → Authentication → Email Templates for project
`rkarotybkzlclgqleled`:

| Supabase template | Subject | HTML file |
| --- | --- | --- |
| Reset Password | `🔒 إعادة تعيين كلمة المرور | لينك` | `password-reset.html` |
| Invite User | `🤝 دعوة للانضمام إلى الخدمة | لينك` | `invite.html` |
| Magic Link | `✉️ رابط تسجيل الدخول | لينك` | `magic-link.html` |
| Confirm Signup | `✅ تأكيد البريد الإلكتروني | لينك` | `confirmation.html` |

Keep `{{ .ConfirmationURL }}` intact in each template. Invitation and recovery
links depend on it to finish their Supabase Auth flow.
