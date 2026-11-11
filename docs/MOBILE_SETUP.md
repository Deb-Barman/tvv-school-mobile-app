# TVV School mobile app - test, build the APK and install it

You do **not** need a laptop. GitHub builds the Android app (APK) in the cloud and you download it on your phone.

> **Honest note.** The code was written and statically analysed against the real Flutter 3.41.9 framework source
> (0 errors), and the networking, offline-cache and date logic was run for real in the Dart VM. But the app has **never
> been compiled into an APK**, because my sandbox cannot reach Google's build tools. So the first run of the workflow is
> the real test. If it fails, open the failed step in the Actions log and send me the red lines - normally a tiny fix.

---

## 1. Put the files in your GitHub repository

Replace / add these in the **root of your repo** (same paths). See `docs/UPGRADE_V1_1.md` for the exact list of changed files.

The website and backend are untouched.

## 2. Build the APK (about 8-12 minutes)

1. GitHub -> your repo -> **Actions** -> **"Mobile app - test, then build Android APK"** -> **Run workflow**
   (it also runs by itself every time you push a change inside `mobile/` to `main`).
   The run has two jobs: **1 - Analyse + test** (code check + every unit/widget test) and **2 - Build APK**.
   The APK is built **only if the tests pass**. If a test fails, open job 1 -> *Unit + widget tests*, copy the red lines
   and send them to me. (Emergency only: when starting the run by hand you can tick **Skip tests**. You can also type *What is new* - it appears on the download page.)
2. When the run turns green, open the run page -> **Summary**. It shows your **share link and a QR code**:
   * **Download page** (always the newest build): `https://github.com/<owner>/<repo>/releases/tag/mobile-latest`
   * **Direct APK link**: `https://github.com/<owner>/<repo>/releases/download/mobile-latest/TVV-School.apk`
   Open either on your phone and tap **TVV-School.apk**. Send the same link (or let someone scan the QR code) to anyone -
   students, teachers, parents. The link never changes; it always gives the latest build.
   *(Anyone can open it without a GitHub account only if the repository that holds the release is **public** - see 4b.)*
3. Open the downloaded APK. Android asks to allow "install unknown apps" for your browser / file manager - allow it once.
4. Open the app (named **Tufanganj Vivekanand Vidyalaya (H.S.)**) and sign in. (Super Admin: **long-press the school seal** on the sign-in screen.)

The first request after the server has been idle can take up to a minute (Render's free server is asleep). The app wakes it
while you type, shows placeholders while loading and retries by itself.

### Updates reach people by themselves

The app checks the download page once each time it opens. When a newer build exists, a banner says **"Version x.y.z is ready - Update"**
(Settings also has **Check for updates** and **Share this app**, which copies the link). Nothing is installed without the person tapping.

### Installing a newer build over an older one

The workflow remembers its test-signing key between builds, so a new APK installs over the old one. If Android ever says
*"App not installed"* (GitHub forgets the remembered key after 7 days without a build), **uninstall the old app once**, then
install the new one - you only lose the saved sign-in. To make this permanent, sign with your own key (step 4).

## 3. Settings you can change (optional)

GitHub -> repo -> **Settings -> Secrets and variables -> Actions -> Variables tab**. All have defaults, so none are required.

| Variable | Default | What it does |
|---|---|---|
| `TVV_API_BASE_URL` | `https://tufanganj-vivekanand-vidyalaya.onrender.com/api` | The Django API address (must end with `/api`, no slash after). |
| `TVV_WEBSITE_URL` | `https://tufanganj-vivekanand-vidyalaya.vercel.app` | "Open school website" link. |
| `TVV_APP_ID` | `com.tvv.school` | Android package name. **Choose before you ever publish - it can never change afterwards.** Do not start it with `in.` (a Kotlin keyword). |
| `TVV_APP_NAME` | `Tufanganj Vivekanand Vidyalaya (H.S.)` | Name under the icon. Phones cut long names with "..."; set a shorter one here if you prefer (for example `TVV School`). |

The app contains **no secrets**: only the public API address. Never put passwords or keys in these variables.

## 4. Optional: sign with your own key (permanent updates)

Create the key once on your phone with Termux (install Termux from F-Droid):

```bash
pkg update && pkg install openjdk-21
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks > upload-keystore.b64
```

**Back up `upload-keystore.jks` and both passwords somewhere safe (not in the repo).** Then add four **Secrets**
(Settings -> Secrets and variables -> Actions -> *Secrets*):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the whole text inside `upload-keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password you typed |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password (same as above if you pressed Enter) |

Run the workflow again. From now on every build is signed with your key and always installs over the previous one.

## 4b. Keep the source code private but the download public (recommended for sharing)

A private repository's download link only works for people who have access to it. To let everybody download:

1. Create a **second, public** repository, e.g. `tvv-school-app-downloads`. Tick **Add a README file** (the repo needs one commit).
2. GitHub -> your profile photo -> **Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens -> Generate new token**.
   *Repository access:* **Only select repositories** -> the downloads repo. *Permissions -> Repository permissions -> Contents:* **Read and write**. Copy the token.
3. In your **source** repo -> Settings -> Secrets and variables -> Actions:
   * **Secrets** -> New: `TVV_RELEASE_TOKEN` = the token.
   * **Variables** -> New: `TVV_RELEASE_REPO` = `your-user/tvv-school-app-downloads`.
4. Run the workflow again. Your share link is now
   `https://github.com/your-user/tvv-school-app-downloads/releases/download/mobile-latest/TVV-School.apk`
   (printed on the run's Summary page). The code stays private.

## 5. Releasing a new version

Change `version: 1.4.0+1` in `mobile/pubspec.yaml` (the part before `+` is what people see; the build number is replaced
automatically by the workflow run number). Push to `main`.

## 6. Troubleshooting

| Symptom | What to do |
|---|---|
| App shows an offline banner but the internet works | The Render server is waking up. Wait ~30-60 s and pull down to refresh. |
| "App not installed" when updating | Uninstall the old app once, then install (see step 2) - or sign with your own key (step 4). |
| Signed out after you changed your password | Expected: the server ends every old session. Sign in again. |
| "Too many attempts" when signing in | The backend's rate limit. Wait a minute; the Super Admin can *Unlock* the account in **Accounts**. |
| Job "1 - Analyse + test" is red, so no APK | A test or the code check failed. Open the red step, copy the lines and send them to me. You can still get an APK in an emergency with **Run workflow -> Skip tests**. |
| Workflow fails at "Build APK" | Open the step, copy the red lines and send them to me. |
| Workflow fails at "Generate the android project files" | The Flutter version changed its template. Keep `FLUTTER_VERSION: "3.41.9"` or ask me to update `tool/prepare_platforms.py`. |
| Gallery / profile photos don't show | They load from the pasted link; Google Drive links must be shared as "Anyone with the link". |
| The screen still looks cut off or too big | Send me a screenshot and your phone model; I'll pin it down. Also check Settings -> Display -> *Display size* and *Font size* (the app now limits text growth to 15%). |

## 7. Not included right now

* **iOS / App Store and Google Play (AAB)** were removed from the workflow on purpose (APK only). The old setup steps are in
  your git history if you want them back.
* **Push notifications** need a small backend addition plus Firebase; they are planned for a later upgrade.

## 8. Running locally (optional)

See `mobile/README.md`. Flutter 3.41.9 is expected.
