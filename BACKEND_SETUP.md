# Zenvora Mart backend setup

## 1. Supabase SQL
Run the existing `supabase/setup.sql` in the Supabase SQL Editor first. Then run:
`supabase/migrations/202611020001_zenvora_operations.sql`

## 2. Edge Function secrets
Set these in Supabase Project Settings → Edge Functions → Secrets:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-side only)
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

Deploy:
- `razorpay-checkout`
- `razorpay-webhook`
- `admin-access-control`
- `refund-admin-action`
- `return-request`

Deploy `send-admin-push` only when Firebase service-account secrets and a trusted database webhook are configured. Required secrets: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `DATABASE_WEBHOOK_SECRET`.

## 3. Razorpay webhook
Configure the Razorpay webhook URL as:
`https://<project-ref>.supabase.co/functions/v1/razorpay-webhook`
Subscribe to payment captured/failed events and use the exact webhook secret stored in Supabase.

## 4. X-Admin / Staff
The user must first register and sign in to the customer app. Super Admin then grants X-Admin or Staff access from Admin → X-Admin & Staff access. Staff receives fixed product-add and order-read permissions. X-Admin permissions are individually selected. Revocation deactivates the role.

## 5. GitHub APK build
The existing `.github/workflows/build-apk.yml` builds a release APK on push to `main` or manual dispatch. Download the `Zenvora-Release-APK` artifact from the completed workflow run.

## 6. Scheduled database backup
Add GitHub Actions secret `SUPABASE_DB_URL` (the PostgreSQL connection string, not the service-role key). `.github/workflows/supabase-backup.yml` runs weekly and can also be triggered manually. It uploads a custom-format `pg_dump` artifact retained for 30 days. Restore should be performed by an authorized operator into a controlled database after validating the target; do not restore over production without a separate verified backup.

## Important
Never place service-role keys, Razorpay secrets, Firebase private keys or database passwords in Flutter config or commit them. The current workspace cannot deploy your Supabase project or run a live payment test. Use Razorpay test mode first.
