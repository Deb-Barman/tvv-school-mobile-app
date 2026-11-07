# TVV School - mobile app (Flutter)

The official app of **Tufanganj Vivekananda Vidyalaya (H.S.)** for Android and iOS, one Dart codebase.
It talks to the school's **existing** Django REST API (the same one the website uses). Nothing in the backend, the
Supabase database or the website is replaced or duplicated.

* Setup, cloud builds, Play Store and TestFlight: [`../docs/MOBILE_SETUP.md`](../docs/MOBILE_SETUP.md)
* API map, what was verified, known gaps: [`../docs/MOBILE_API_NOTES.md`](../docs/MOBILE_API_NOTES.md)

## What each role gets

| | Student | Teacher | Super Admin |
|---|---|---|---|
| Dashboard | attendance ring, today's classes, homework to do, exams, notices | today's periods, quick actions, exams, notices | school numbers, attendance today + 7-day chart, inbox counts |
| Timetable | own class (and earlier years) | own periods or any class | any class, **add / edit / delete periods** |
| Homework | see + tick inside the open window | set / edit / delete, see who finished | same as teacher |
| Exam schedule | read | add / edit / delete | add / edit / delete |
| Attendance | own %, month calendar, history | **take class attendance**, own record | take attendance, **teacher attendance**, **attendance report** (students / teachers) |
| Results | marks by session and term, totals | **enter / correct marks** for a class | same as teacher |
| Marksheets | open own | view | view, **attach by link**, delete |
| Class & subjects | own class + subjects | all | **manage sessions, classes, subjects** |
| Students list | - | search / filter, guardian contact | same, plus **class + roll assignment** |
| Notices / Events | read | read | **publish / edit / delete** |
| Accounts | - | - | **create, edit, disable, delete, unlock, set password, password-reset queue** |
| Inbox | - | - | admissions (status), contact messages |
| Profile | view + edit, public page switch | same | - |
| Faculty, Blog, Gallery, Downloads, Achievements | read | read | read |
| Settings | light / dark / auto theme, **change password**, sign out | same | same |

Permissions are enforced by Django. The app only decides what to *show*; if a screen is ever reached without
permission the server answers 403 and the app shows its message.

## How it is built

```
lib/
  core/        config, ApiClient (JWT, refresh, retry), errors, token storage      <- pure Dart
  data/        models (one per API serializer) + repositories (one per area)       <- pure Dart
  state/       session, theme, app scope (no state-management package)
  ui/          theme tokens, shared widgets, screens per role
tool/
  verify_backend.dart     API check using the app's own client (see API notes)
  prepare_platforms.py    creates android/ and ios/ in CI, applies the few required changes
test/                     unit + widget tests (run in CI)
```

* **Three dependencies only:** `flutter_secure_storage`, `shared_preferences`, `url_launcher`.
* **Tokens** live in the Android Keystore / iOS Keychain. Nothing secret is in the app: it only knows the public API address.
* **Networking** is plain `dart:io` over HTTPS. 15-minute access tokens are refreshed automatically; refresh tokens
  rotate on this backend, so each new one is stored; one refresh is shared by simultaneous requests; going offline
  or a sleeping server never signs anybody out; reads retry while the free Render server wakes up.
* **Loading states:** a skeleton until all of a screen's data has arrived, a clear error with *Try again*, pull-to-refresh.
* **Design:** the website's soft lilac "neumorphic" identity, light and dark.

## Run it on a computer (optional)

```bash
cd mobile
python3 tool/prepare_platforms.py        # creates android/ and ios/ (needs Flutter installed)
flutter pub get
dart run flutter_launcher_icons
flutter run --dart-define=API_BASE_URL=https://tufanganj-vivekanand-vidyalaya.onrender.com/api
```

Flutter version used for development and CI: **3.41.9** (change `FLUTTER_VERSION` in the workflow to move up).
