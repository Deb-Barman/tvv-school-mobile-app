# Mobile app - API notes and verification

## How the app uses your backend

Base URL: `https://tufanganj-vivekanand-vidyalaya.onrender.com/api` (set at build time, see `MOBILE_SETUP.md`).
Auth: `Authorization: Bearer <access>`; access 15 min, refresh 7 days, **rotating with blacklist**.

| Feature | Endpoint(s) | Who may call (enforced by Django) |
|---|---|---|
| Sign in | `POST /auth/staff-login/` (students, teachers), `POST /auth/admin-login/` (Super Admin) | everyone |
| Refresh / sign out | `POST /auth/token/refresh/`, `POST /auth/logout/` | signed-in |
| Me, change password | `GET /auth/me/`, `POST /auth/me/change-password/` | signed-in |
| Forgot password | `POST /auth/forgot-password/` | everyone |
| My profile | `GET/PATCH /auth/me/profile/` | student, teacher |
| Public profile | `GET /auth/profiles/<role>/<username>/` | everyone (404 when private) |
| Sessions, classes, subjects | `/academics/sessions|classes|subjects/` | read: all; write: Super Admin |
| Students | `GET /academics/students/` (students see only themselves), `PATCH /academics/students/<id>/` | read: signed-in; write: Super Admin |
| Class years | `GET /academics/my-classes/` | student |
| Timetable | `/academics/timetable/` (`?school_class=`, `?mine=1`) | read: all; write: Super Admin |
| Homework | `/academics/homework/`, `POST .../<id>/done/`, `GET .../<id>/completions/` | read: all; tick: student; write: staff |
| Exams | `/academics/exams/` | read: all; write: staff |
| Attendance | `/academics/attendance/`, `POST /academics/attendance/bulk/` | read: own / staff; write: staff |
| Teacher attendance | `/academics/teacher-attendance/`, `.../sheet/`, `.../bulk/` | own (teacher) / Super Admin |
| Attendance report | `GET /academics/attendance-report/` | **Super Admin only** |
| Results, marksheets | `/academics/results/`, `.../results/bulk/`, `/academics/marksheets/`, `.../create/` | read: own / staff; write: staff / Super Admin |
| Faculty | `GET /academics/teachers/public/`, `GET /academics/teachers/` | public / staff |
| Notices, events | `/notices/`, `/content/events/` | read: all; write: Super Admin |
| Blog, gallery, downloads, achievements | `/content/articles|gallery|forms|achievements/public/` | everyone |
| Admissions, messages | `/content/admissions/`, `/content/contact/` | Super Admin |
| Accounts | `/auth/admin/users/...`, `/auth/admin/reset-requests/...`, `/auth/admin/stats/` | Super Admin |

No endpoint was added or changed. **No backend change is needed for the app.** (Mobile apps are not subject to CORS.)

## What was verified, and how

I ran **your Django backend** (the code in the ZIP, SQLite, seeded with a student, teacher, Super Admin, class, timetable,
homework, exams, notices, events, marksheet, etc.) and drove it with the app's **real** `ApiClient` and repositories
through `tool/verify_backend.dart`.

* **119 checks passed, 0 failed** with writes on; **87 passed** in the read-only mode.
* Every endpoint above parses into the app's models (decimal strings such as `"91.00"`, nulls, dates).
* **Role-based access:** student and teacher are refused (403) on admin stats, accounts, admissions, attendance report,
  teacher attendance, account creation and notice creation; the Super Admin is refused by the student/teacher sign-in and
  the reverse.
* **Tokens:** an expired access token is refreshed automatically; the **rotated refresh token is stored and works a
  second time**; five simultaneous 401s cause exactly **one** refresh; a blacklisted refresh token ends the session once and
  wipes storage; after sign-out or a password change the old session is dead.
* **Writes:** attendance, marks (with decimals, and rejection above full marks), homework (date rules), exams, accounts
  (create, duplicate-username message, edit, disable, reset password, unlock, delete), notices, events, admissions,
  sessions/classes/subjects/timetable, student class placement, profile editor payload.
* **Network:** retries through 503s (server waking), HTML error pages, 429, validation messages, unreachable server.

You can re-run the read-only check against production any time: Actions -> **"Mobile app - check the live API"**
(needs the `CHECK_*` secrets listed in `MOBILE_SETUP.md`).

### What could NOT be verified in my environment (be aware)

* **The app was never compiled or run on a device or emulator.** My sandbox cannot reach Google's Flutter/Android/pub.dev
  hosts. What I did instead: statically analysed *all* Dart code against the real Flutter 3.41.9 framework source
  (0 errors), ran the pure-Dart layers against the live backend (above), and tested the Android/iOS patch script against
  Flutter 3.41.9's real project templates. A first CI run may still show a build or layout problem I could not see; the
  workflow logs will say exactly what.
* The iOS signing/TestFlight steps and Google Play steps are standard but **untested** (they need your accounts).
* The unit/widget tests in `mobile/test` were written but not run here (the logic test file was run against a shim: 8/8).

## Findings about the existing system

1. **Website bug: signed out about every 30 minutes (found while testing token rotation).**
   Your backend rotates refresh tokens and blacklists the old one. `frontend/src/lib/api.ts` (line ~54) saves only
   the new *access* token (`tokenStorage.setAccess(data.access)`) and keeps the old refresh token, so the second refresh
   (~30 min after sign-in) is rejected and the person is signed out. The mobile app stores the new refresh token. Suggested
   one-line website fix (not applied, as you asked not to change the website unnecessarily):

   ```ts
   // api.ts, inside refreshAccessToken(), replace  tokenStorage.setAccess(data.access);  with:
   if (typeof data.refresh === "string") tokenStorage.setTokens(data.access, data.refresh);
   else tokenStorage.setAccess(data.access);
   ```
2. **Attendance report is Super Admin only**, so students and teachers cannot read a ready-made percentage. The app computes
   it from their own attendance rows and the session's working days (same figures and colour bands as the website).
3. `target_class` on notices is only a free-text label; it does not filter who sees a notice (the app shows it as a label).

## Not in the app (deliberately left on the website)

These are admin tools that suit a large screen. Their APIs exist; they were left out of v1, not blocked:

* Bulk import (Excel/CSV), Promote students (year-end), Database usage, Data view.
* Writing Blog articles, Gallery photos, Downloads and Achievements (the app reads them).
* Uploading files (profile photo, marksheet PDF): the app uses pasted links, which the backend already supports.
* Editing skills, project cards and achievement cards on a profile (they are shown, and never overwritten by the app).

## Security notes

* Tokens only in Keystore/Keychain; Android cloud backup is switched off so tokens are never restored onto another phone.
* HTTPS only (`usesCleartextTraffic=false`); the app only opens `http(s)` links and refuses anything else.
* No secrets, keys or database credentials exist in the app; `API_BASE_URL` is public information.
* Sign-in rate limits and lockouts are the server's; the app shows its messages.
