# Zenvora Mart — Flutter app

## Sabse pehle: `lib/config.dart` bharo
Saari keys yahin daalni hain:
- `supabaseUrl`, `supabaseAnonKey` (Supabase > Project Settings > API, **anon** key)
- `logoUrl` ya `logoAsset` (logo `assets/logo/logo.png` me rakho)
- `adminEmails` (existing Supabase Super Admin email; backend role must also be configured)

## Supabase setup (required)
1. Run `supabase/setup.sql` first. Add the existing Super Admin email to `public.admins` (must match `lib/config.dart`).
2. Then run `supabase/migrations/202611020001_zenvora_operations.sql`.
3. Deploy `razorpay-checkout` and `razorpay-webhook` Edge Functions. Set the secrets listed in `BACKEND_SETUP.md`.
4. Configure the Razorpay webhook URL and signing secret in the Razorpay dashboard.
5. Enable Email and Google providers in Supabase Auth and configure OAuth redirect/client IDs.
6. Never place Razorpay secret, webhook secret or Supabase service-role key in `lib/config.dart` or any client file.

The app now sends checkout creation and Razorpay signature verification to the server function. COD and online checkout are unavailable until the SQL migration and Edge Functions are deployed correctly.

## Features (current app scope)
- Login / Sign up / Sign out (Supabase email + password), Google login
- Product page: clean design, Add to cart + **Buy now** (sirf ek product ka order, cart me kuch add nahi hota)
- Membership schema includes Silver / Gold / Platinum defaults; customer membership purchase UI is still pending server-side integration
- Reviews: sirf wahi customer likh sakta hai jisne product order kiya ho, baaki sirf padh sakte hain (app + Supabase RLS dono jagah)
- Server-created Razorpay orders, server-side signature verification, COD (requires deployed Edge Functions)
- Notifications: order updates, offers, membership expiry (+ admin ko new order)
- Admin panel: signed-in Super Admin account and backend role checks; no shared hard-coded admin PIN
- Admin-controlled branding and app appearance (customer-side theme toggle removed)

## Build APK
GitHub par push karo -> Actions > **Build Zenvora APK** > artifact download.
# probable-parakeet


## Google Login + Firebase Cloud Messaging setup

1. In Firebase Console, register the Android app using `applicationId` `com.zenvora.zenvora`. Download `google-services.json`.
2. Put `google-services.json` at `android/app/google-services.json` before building. The Android folder is committed in this repository. Never commit private service-account keys.
3. In Google Cloud Console, configure OAuth consent and create an Android OAuth client using the same package name and the SHA-1 of the APK signing certificate. Create a Web OAuth client too.
4. Enable Google provider in Supabase Authentication and paste the Web Client ID and Client Secret. Add the Supabase redirect URL shown in its provider settings.
5. Set `AppConfig.googleWebClientId`, `supabaseUrl`, and `supabaseAnonKey` in `lib/config.dart`. The anon key is public; never put a service-role key or OAuth client secret in the app.
6. Run `supabase/setup.sql`, then the operational migration as described in `BACKEND_SETUP.md`.
7. Run `flutter pub get` and build. On Android 13+, allow notification permission when prompted.

FCM initialization and token registration are included. This client currently does not send admin push messages itself: a trusted server-side Supabase Edge Function must send FCM messages using Firebase service-account credentials stored as server secrets. Foreground notifications also need a local-notification presentation layer. The committed Android Gradle project applies the Google Services plugin; `google-services.json` must match the package name.
# redesigned-engine


See `IMPLEMENTATION_STATUS.md` for code audit, known limitations and deployment checklist.
