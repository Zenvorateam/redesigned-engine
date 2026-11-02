# Zenvora Mart — GitHub test package status

This package is an overlay for the existing `redesigned-engine-main` repository. It is not a new GitHub repository. Merge/replace the included paths in the existing repository and remove `lib/seed.dart` as listed in `PATCH_INSTRUCTIONS.txt`.

## Included in this test package
- Branded Android launcher/splash and GitHub Actions APK build workflow.
- Supabase-first sign-in and secure Razorpay checkout foundation with server-side order creation, payment signature verification and webhook confirmation.
- Removal of seeded demo catalogue data and legacy demo accounts.
- Admin operational sections for products, categories, banners, orders, returns, refunds, support tickets, admin access, suppliers, supplier payments, membership plans, messages, receipts, product policies and analytics.
- Super Admin-controlled X-Admin provisioning through the `admin-access-control` Edge Function; Staff defaults to add-product and read-orders access.
- Server-side return-request validation and admin refund status actions.
- CSV operational export that opens in Excel.
- Weekly Supabase database dump GitHub workflow (requires the `SUPABASE_DB_URL` GitHub secret).
- SQL foundation for RLS, role permissions, returns, refunds, support, suppliers, loyalty, memberships, payment receipts, audit logs and remote settings.

## Important limitations — do not treat these as already live
- No Flutter/Dart SDK, Android emulator, Supabase credentials or Razorpay live account is available in this workspace. A release APK, Dart analyzer pass, SQL migration execution and live payment test have NOT been performed.
- Deploy the SQL migration and Edge Functions listed in `BACKEND_SETUP.md` before testing cloud-backed operations.
- X-Admin/Staff provisioning requires the target user to register first. The service-role secret must stay in Supabase Edge Function secrets, never in Flutter config or GitHub APK secrets.
- Manual refund payout is recorded by an authorized admin; the app does not transfer money automatically. COD refund timing depends on the owner confirming receipt of COD funds.
- CSV is Excel-compatible, not a formatted `.xlsx` workbook. Scheduled database backups are handled by GitHub Actions; restore is a controlled database operation and is not a one-tap in-app restore.
- Business profit/loss is not fully calculated until supplier cost data is consistently entered. The analytics page currently shows operational record counts and exports source records.
- Full visual design studio, customer membership purchase/benefit lifecycle, complete in-app chat thread UI, automatic customer-specific push campaign delivery, geocoded PIN extraction, and end-to-end restore verification still need device/backend testing and further implementation.

## Recommended test sequence
1. Apply overlay and remove `lib/seed.dart`.
2. Run `flutter pub get` and `flutter analyze` locally or through GitHub Actions.
3. Apply `supabase/setup.sql`, then the migration under `supabase/migrations/`.
4. Configure and deploy Edge Functions as described in `BACKEND_SETUP.md`.
5. Build APK through Actions and test sign-in, catalogue, cart, checkout, admin roles and return/refund workflows using test accounts and Razorpay test mode.
