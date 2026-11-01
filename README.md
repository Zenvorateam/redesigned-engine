# Zenvora Mart — Flutter app

## Sabse pehle: `lib/config.dart` bharo
Saari keys yahin daalni hain:
- `supabaseUrl`, `supabaseAnonKey` (Supabase > Project Settings > API, **anon** key)
- `razorpayKeyId` (sirf Key ID, secret kabhi app me nahi)
- `logoUrl` ya `logoAsset` (logo `assets/logo/logo.png` me rakho)
- `adminEmails` (jo email admin banega) aur `adminPin`
- `membershipPrice` (29), `membershipDays` (30)

## Supabase setup (ek baar)
1. Supabase > SQL Editor me `supabase/setup.sql` paste karke Run karo.
2. Uske andar `insert into public.admins ...` line me apna admin email daalo (config.dart wala same).
3. Authentication > Providers > Email: "Confirm email" band kar do (warna signup ke baad email confirm karna padega).

## Features
- Login / Sign up / Sign out (Supabase email + password), Account page se
- Product page: clean design, Add to cart + **Buy now** (sirf ek product ka order, cart me kuch add nahi hota)
- Zenvora Plus membership: Rs 29/month, har order par free + faster delivery (Razorpay se payment)
- Reviews: sirf wahi customer likh sakta hai jisne product order kiya ho, baaki sirf padh sakte hain (app + Supabase RLS dono jagah)
- Razorpay online payment at checkout (COD bhi hai)
- Notifications: order updates, offers, membership expiry (+ admin ko new order)
- Admin panel: admin email se login -> PIN. Saare customers ke orders, products/banners/coupons/settings sab sync hote hain
- Dark / Light mode (Home header ya Account me toggle)

## Build APK
GitHub par push karo -> Actions > **Build Zenvora APK** > artifact download.
# probable-parakeet


## Google Login + Firebase Cloud Messaging setup

1. In Firebase Console, register the Android app using the exact `applicationId` used by the generated Android project (the current GitHub workflow generates `com.zenvora.zenvora`). Download `google-services.json`.
2. Put `google-services.json` at `android/app/google-services.json` before building. This repository generates the Android folder during GitHub Actions, so either commit an Android folder containing this file or update the workflow to create `android/app` and decode a GitHub Actions secret named `GOOGLE_SERVICES_JSON_BASE64` into that path. Never commit private service-account keys.
3. In Google Cloud Console, configure OAuth consent and create an Android OAuth client using the same package name and the SHA-1 of the APK signing certificate. Create a Web OAuth client too.
4. Enable Google provider in Supabase Authentication and paste the Web Client ID and Client Secret. Add the Supabase redirect URL shown in its provider settings.
5. Set `AppConfig.googleWebClientId`, `supabaseUrl`, and `supabaseAnonKey` in `lib/config.dart`. The anon key is public; never put a service-role key or OAuth client secret in the app.
6. Run `supabase/setup.sql` in Supabase SQL Editor. It creates the `device_tokens` table.
7. Run `flutter pub get` and build. On Android 13+, allow notification permission when prompted.

FCM initialization and token registration are included. This client currently does not send admin push messages itself: a trusted server-side Supabase Edge Function must send FCM messages using Firebase service-account credentials stored as server secrets. Foreground notifications also need a local-notification presentation layer. Configure Firebase Android Gradle plugin/google-services processing when generating the Android project; `google-services.json` alone is not sufficient.
# redesigned-engine
