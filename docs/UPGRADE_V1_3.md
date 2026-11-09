# Upgrade 1.3 - Results, Attendance, Homework, new features, shareable release

## From your screenshots
| Page | Problem | Fix |
|---|---|---|
| Homework (teacher) -> tap card | "Not found." | The card says "2 of 0 students": the class has **no enrolled students**, so the server returns 404 for the list. The app now explains this in plain words (and shows how many ticked) instead of the raw error. Cards say "2 ticked - no students are enrolled in this class". *(If students are enrolled and you still see it, send me the backend `academics/views.py` + `urls.py` and I will match the exact route.)* |
| Results | Plain bars | **Hero summary** (overall % ring, total marks, best / needs-focus subject), **progress-across-terms bar chart**, one **expandable card per term** with a ring, change since the previous term (▲/▼) and per-subject change. |
| Attendance | Long plain list | **Hero ring** with status (On track / Needs attention / Below minimum), a **smart tip** ("You can miss up to N more days and still finish at 75%" - worked out from the real working days), streak tiles, **last-6-months chart**, calendar, and a **day-by-day list grouped by month** with "Show all". |

## New features
* **Next class card** on the student and teacher dashboards: "Next class in 25 min" / "In progress - 12 min left" (updates by itself).
* **Homework progress** for students: ring "3/5 done" and "Next due: ...".
* **In-app updates**: a banner appears when a newer build is published; Settings -> **Check for updates** and **Share this app**.
* **Offline, photo, loading placeholders** from 1.2 stay.

## Release and share link
Every green run publishes **TVV-School.apk** to the always-the-same link
`https://github.com/<owner>/<repo>/releases/download/mobile-latest/TVV-School.apk` (page: `.../releases/tag/mobile-latest`),
with a **QR code, size, SHA-256 checksum and "what is new"**. The run's Summary page prints the links.
Private source code but public downloads: see docs/MOBILE_SETUP.md section 4b.

## Honest limits
* No Flutter SDK was available to me: the screens are checked by the Dart analyser against the real Flutter 3.41.9 source (0 errors)
  and the new logic (attendance maths, results analytics, next class, update parser) was executed for real in the Dart VM.
  The widget tests run for the first time in your GitHub Actions - if one fails the APK is not built; send me the red lines.
* The update check and share link need the repository (or the downloads repo) to be public.
* Push notifications still need a backend addition plus Firebase.
