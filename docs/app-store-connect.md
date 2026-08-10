# Link App Store Connect package

## App identity

- App name: `Link — إدارة الخدمة`
- Bundle ID: `com.linkapp.church`
- SKU: `link-church-ios`
- Primary language: Arabic
- Primary category: Productivity
- Secondary category: Utilities
- Version: `1.0.2`
- Build: `4`
- Price: Free
- Copyright: `2026 fady khayrat`

## Product page — Arabic

### Subtitle

`إدارة الخدمة والحضور بسهولة`

### Promotional text

`كل أدوات الخدمة في مكان واحد: الاجتماعات، الأعضاء، الحضور، الافتقاد، والتقارير.`

### Description

`لينك` منظومة عربية متكاملة تساعد الكنائس والخدام على تنظيم الخدمة ومتابعتها بسهولة.

من خلال التطبيق يمكنك:

- إدارة الاجتماعات وفصول مدارس الأحد.
- تسجيل الحضور والغياب بسرعة ووضوح.
- إدارة بيانات الأعضاء والخدام والصلاحيات.
- متابعة الافتقاد وسجل حضور كل عضو.
- عرض التقارير والإحصائيات الخاصة بالخدمة.
- استلام الدعوات والانضمام إلى فريق الخدمة بأمان.
- استخدام البيانات المحفوظة عند ضعف الاتصال، ثم مزامنتها لاحقاً.
- ضبط تذكيرات محلية لمواعيد تسجيل الحضور.

صُمم لينك بواجهة عربية كاملة واتجاه من اليمين إلى اليسار، ليجعل التنظيم أبسط ويترك للخدام وقتاً أكبر للخدمة نفسها.

### Keywords

`كنيسة,خدمة,حضور,اجتماعات,افتقاد,خدام`

## URLs

- Marketing URL: `https://link-church-app.vercel.app`
- Support URL: `https://link-church-app.vercel.app/support`
- Privacy Policy URL: `https://link-church-app.vercel.app/privacy-policy`

## Review information

- Contact first name: `Fady`
- Contact last name: `Khayrat`
- Contact email: `fadykhayrat@gmail.com`
- Contact phone: `[ADD PHONE NUMBER]`
- Sign-in required: Yes
- Demo username: `[CREATE PERMANENT APPLE REVIEW ACCOUNT]`
- Demo password: `[ADD PERMANENT PASSWORD]`

### Review notes

Link is an Arabic RTL church-management app for authorized church servants and administrators. The supplied review account must remain active and include sample meetings, members, attendance sessions, follow-up records, and administrator permissions so all features can be reviewed.

The app uses local notifications only for optional meeting reminders. It does not collect precise location and has no in-app purchases. Account deletion is available from Settings > Account > Delete account permanently (`الإعدادات > الحساب > حذف الحساب نهائياً`). Shared church attendance and service records remain organizational records after an individual account is removed.

## App privacy answers

Declare collection by the app and its Supabase backend. None of these data types are used for third-party advertising or cross-company tracking.

| Apple data type | Linked to identity | Purpose |
| --- | --- | --- |
| Name | Yes | App Functionality |
| Email Address | Yes | App Functionality |
| Phone Number | Yes | App Functionality |
| User ID | Yes | App Functionality, Analytics |
| Product Interaction | Yes | Analytics |
| Other User Content | Yes | App Functionality |

`Other User Content` covers church/member directories, attendance, notes, assignments, meeting information, follow-up records, and invitation information entered by authorized users.

Answer **No** to tracking. The app does not use advertising identifiers, third-party advertising, or data-broker sharing.

## Age rating and compliance

- Complete the age-rating questionnaire with no mature-content categories unless the app content changes.
- The app is intended for adult church servants and administrators, even though they may manage attendance records for children.
- Export compliance is already declared in the binary as exempt (`ITSAppUsesNonExemptEncryption = false`) because the app uses standard HTTPS/TLS rather than proprietary encryption.
- Content rights: the developer owns or has permission to use the app content.

## Required screenshots

Prepare at least three polished Arabic screenshots without real personal data:

1. Dashboard and service overview.
2. Meeting/class attendance entry.
3. Members and attendance history.
4. Reports and analytics.
5. Settings, permissions, or reminders.

Use the App Store Connect screenshot slots shown for the current iPhone and iPad device families. This binary supports both iPhone and iPad, so both sets may be requested. Avoid login screens as primary product-page screenshots.

## Before submission

- Deploy and test the Supabase `delete-account` Edge Function.
- Deploy the `/support` web page and verify the public URL returns HTTP 200.
- Create and test a permanent reviewer account with representative sample data.
- Test password reset and invitation deep links on a physical iPhone.
- Upload the signed IPA and wait for processing.
- Complete pricing/availability, age rating, app privacy, content rights, and reviewer contact fields.
- Attach the processed build to version 1.0.2, add it for review, then submit the draft submission.
