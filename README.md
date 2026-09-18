# Link

Arabic RTL church management app (Flutter + Supabase + BLoC).

## Setup

1. Copy environment file and add your Supabase keys:

```bash
cp .env.example .env
```

2. Run the SQL migration in Supabase SQL Editor: `supabase_security_and_fixes_migration.sql`

3. For invitation links and emails: run `supabase_invitation_link_migration.sql`, then `supabase_invitation_identity_fix.sql` (and `supabase_invitation_email_migration.sql` if not already applied), configure Gmail SMTP in Supabase Authentication, and deploy Edge Functions `invite-redirect` and `send-invitation-email`. Optional: set `INVITE_LINK_BASE_URL` for a custom HTTPS invite domain.

## Run (automatic)

1. Ensure `.env` exists: `cp .env.example .env` (then add your Supabase keys)
2. Run once after setup: `flutter clean && flutter pub get`
3. Press **Run** in Cursor, or `flutter run`, or `make run`

The app loads keys from the bundled `.env` asset — no extra flags needed for local dev.

## Build for production

| Method | Command |
|---|---|
| **Local** | `make build-web` or `make build-apk` |
| **CI (GitHub)** | Push to `main` — workflow uses repo secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY` |

Do not commit `.env`. The anon key is embedded at build time; data access is enforced by Supabase RLS.

## Website and PWA on one domain

The public website lives in `site/`; the Flutter application is built from the
same source as Android and is served by that site at `/app/`.

```text
https://linkchurch.space/       # public website
https://linkchurch.space/app/   # full Flutter Web PWA
```

Run `make build-web` to build Flutter with the required `/app/` base path and
copy it to `site/public/app`. The Vercel workflow performs the same step before
deploying. In Vercel Project Settings, set **Root Directory** to `site` once;
the domain remains `linkchurch.space`.
