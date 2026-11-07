# TVV School mobile app - setup and deployment

You do **not** need a laptop. GitHub builds the app in the cloud and gives you the files to download.

> **Read this first.** The app code was written and checked as far as my environment allowed (see
> `MOBILE_API_NOTES.md`: API behaviour tested against your real backend code; all Dart statically analysed against the
> real Flutter 3.41.9) but it has **never been compiled into an APK/AAB/iOS app**, because my sandbox cannot reach Google's
> build tools. So **step 2 is the first real build**. If it fails, open the failed step in the Actions log and send me the
> red lines - those are normally small fixes.

---

## 1. Put the files in your GitHub repository

Add these to the **root of your existing repo** (same paths):

```
mobile/                                   <- the whole Flutter app folder
.github/workflows/mobile-build.yml
.github/workflows/mobile-api-check.yml
docs/MOBILE_SETUP.md
docs/MOBILE_API_NOTES.md
```

Nothing else changes. The website and backend are untouched.

## 2. First build (about 8-12 minutes)

1. GitHub -> your repo -> **Actions** -> **"Mobile app - build (Android APK/AAB + iOS)"** -> **Run workflow**.
2. When it turns green, open the run -> **Artifacts** -> download **`android-release`** (a zip containing the `.apk` and `.aab`).
3. Unzip, open the `.apk` on an Android phone, allow "install unknown apps" for your file manager/browser when asked.
4. Open **TVV School**, sign in with a student, teacher or (small link at the bottom) Super Admin account.

The first request after the server has been idle can take up to a minute (Render's free server is asleep). The app
wakes it while you type, shows a skeleton while loading and retries by itself.

The APK from this step is signed with a **debug key**: perfect for testing, not accepted by Google Play. Add your own key in step 4.

## 3. Settings you can change (optional)

GitHub -> repo -> **Settings -> Secrets and variables -> Actions -> Variables tab**. All have defaults, so none are required.

| Variable | Default | What it does |
|---|---|---|
| `TVV_API_BASE_URL` | `https://tufanganj-vivekanand-vidyalaya.onrender.com/api` | The Django API address (must end with `/api`, no slash after). |
| `TVV_WEBSITE_URL` | `https://tufanganj-vivekanand-vidyalaya.vercel.app` | "Open school website" link. |
| `TVV_APP_ID` | `com.tvv.school` | Android package name / iOS bundle id. **Choose before the first store upload - it can never change afterwards.** Do not start it with `in.` (a Kotlin keyword). |
| `TVV_APP_NAME` | `TVV School` | Name under the icon. |

The app contains **no secrets**: only the public API address. Never put passwords or keys in these variables.

## 4. Android: sign for Google Play (one time)

Google Play needs an AAB signed with **your upload key**. You create the key once and keep it safe forever.

**Create the key on your phone with Termux** (install Termux from F-Droid):

```bash
pkg update && pkg install openjdk-21
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks > upload-keystore.b64
```

Keytool asks for a password (use a long one) and your details. **Back up `upload-keystore.jks` and both passwords
somewhere safe (not in the repo).** Then add four **Secrets** (Settings -> Secrets and variables -> Actions -> *Secrets*):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the whole text inside `upload-keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password you typed |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password (same as above if you pressed Enter) |

Run the workflow again: the APK and AAB are now signed with your key (the log says "Signing with your upload key").

**Upload to Google Play:** create a developer account at play.google.com/console (one-time fee), create the app,
choose **Play App Signing** (recommended), then *Testing -> Internal testing -> Create release* and upload
`TVV-School-<version>.aab`. Fill in the store listing, privacy policy and Data safety form (the app collects: name,
username, school records, entered by the school; data goes only to the school's own server; sent encrypted).
The version number goes up automatically with every build.

## 5. iOS: TestFlight / App Store

iOS needs an **Apple Developer Program** membership (paid, yearly). There is no way around this.

1. developer.apple.com -> *Certificates, Identifiers & Profiles* -> **Identifiers** -> register an App ID whose Bundle ID
   equals `TVV_APP_ID` (default `com.tvv.school`).
2. appstoreconnect.apple.com -> **My Apps -> +** -> New App, choose that Bundle ID.
3. App Store Connect -> **Users and Access -> Integrations -> App Store Connect API** -> generate a key with the
   **Admin** role. Note the **Key ID** and **Issuer ID**, download the `.p8` file (only once!).
4. Your **Team ID** is shown under *Membership details*.
5. Add four Secrets: `APPLE_TEAM_ID`, `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, and `APPSTORE_KEY_P8` (paste the **entire
   contents** of the `.p8` file including the BEGIN/END lines).
6. Actions -> run the workflow with **"Also build the iOS app" ticked** (or push a tag such as `mobile-v1.0.0`).
   On success the signed IPA is uploaded to **TestFlight** automatically; it appears in App Store Connect after Apple's
   processing (about 10-30 minutes). Add testers there, then submit for App Review when ready.

Without those secrets the iOS job still compiles the app (a useful check) and tells you that no IPA was produced.
macOS minutes cost 10x more than Linux minutes on GitHub; that is why iOS is opt-in.

## 6. Releasing a new version

* Change `version: 1.0.0+1` in `mobile/pubspec.yaml` (the part before `+` is what people see; the build number after `+` is
  replaced automatically by the workflow run number so it always increases).
* Push to `main` (Android builds) or tag `mobile-v1.0.1` (Android + iOS, APK attached to a GitHub Release).

## 7. Check that the live backend still matches the app

Add Secrets `CHECK_STUDENT_USER`, `CHECK_STUDENT_PASS`, `CHECK_TEACHER_USER`, `CHECK_TEACHER_PASS`, `CHECK_ADMIN_USER`
(the e-mail), `CHECK_ADMIN_PASS` - ideally a dedicated test student, test teacher and the admin. Then Actions ->
**"Mobile app - check the live API"** -> Run. It is read-only and prints PASS/FAIL per endpoint, role rule and token behaviour.

## 8. Every setting in one table

| Name | Kind | Needed for |
|---|---|---|
| `TVV_API_BASE_URL`, `TVV_WEBSITE_URL`, `TVV_APP_ID`, `TVV_APP_NAME` | Variables | optional customisation |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Secrets | Google Play (signed AAB/APK) |
| `APPLE_TEAM_ID`, `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_P8` | Secrets | iOS IPA + TestFlight |
| `CHECK_*` (six) | Secrets | live API check |
| Backend (Render) | unchanged | the app needs **no** new backend environment variables |

On the backend you do **not** need to touch `CORS_ALLOWED_ORIGINS` or `FRONTEND_URL`: those only affect browsers.

## 9. Troubleshooting

| Symptom | What to do |
|---|---|
| App shows "You're offline" but the internet works | The Render server is waking up. Wait ~30-60 s and tap **Try again**. Your keep-alive ping (mentioned in your docs) avoids this. |
| "Can't reach the school server" only on release builds | The Android INTERNET permission is added by `tool/prepare_platforms.py`; confirm the workflow step "Generate android/ and ios/" ran. |
| Signed out after you changed your password | Expected: the server ends every old session. Sign in again. |
| "Too many attempts" when signing in | The backend's rate limit / lockout. Wait a minute; the Super Admin can *Unlock* the account in **Accounts**. |
| Workflow fails at `flutter analyze` | Send me the red lines. Style hints never fail the build; only real errors do. |
| Workflow fails at "Generate android/ and ios/" | The Flutter version changed its template. Keep `FLUTTER_VERSION: "3.41.9"` or ask me to update `tool/prepare_platforms.py`. |
| Play Console rejects the AAB ("signed in debug mode") | The four `ANDROID_*` secrets are missing or wrong; see step 4. |
| iOS job: "No profiles for ..." | The Bundle ID in step 5.1/5.2 doesn't match `TVV_APP_ID`, or the API key isn't **Admin**. |
| Gallery / profile photos don't show | They load from the pasted link; Google Drive links must be shared as "Anyone with the link". |
| Launcher icon looks soft | The source seal in the repo is 320 px. Replace `mobile/assets/images/app_icon.png` (1024x1024, no transparency) and `app_icon_foreground.png` with sharper art. |

## 10. Running locally (optional)

See `mobile/README.md`. Flutter 3.41.9 is expected.
