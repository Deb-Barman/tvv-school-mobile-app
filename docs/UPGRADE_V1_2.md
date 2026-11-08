# Upgrade 1.2 - fixes from your screenshots, premium polish, test-then-build CI

## Your screenshots -> what I changed
| Screenshot | Problem | Fix |
|---|---|---|
| Timetable (teacher) | "By class" chip cut off, class field squeezed | Controls now stack: a full-width **My periods / By class** switch, then the class field on its own line. Days are an equal-width **Mon-Sat strip** that always fits. |
| Blog article | Plain, cover image did not open | Magazine-style page: cover to the screen edges, **tap the cover to open it full screen**, title, author line, read time, readable paragraphs. List cards redesigned too. |
| Gallery | One tiny tile, bare | **Mosaic grid** (a big tile + smaller ones, captions on big tiles, photo count). Tap any photo -> full-screen viewer: **swipe between photos**, pinch / double-tap zoom, counter, caption. |
| Achievements | Long text crammed beside a small icon | Trophy badge with the colourful ring, title + year/category chips, text limited to 4 lines with **Read more**; tap a card to read everything (and open its picture). |
| Menu | Profile picture missing (only initials) | Your photo now shows in the menu, the bottom bar and the dashboard header (loaded from your profile). |
| Notices (list + dashboard) | Cards did not open | Every notice card **opens a full notice page** (author, date, class, whole text, selectable, copy button). |
| Loading screens (your note in Achievements) | Generic loaders | **YouTube/Facebook-style shimmer placeholders that have the same shape as each real screen**: notices, blog, gallery, achievements, profile, timetable, dashboards, lists. |

## Extra polish
Cards press in slightly when touched, lists glide in, bottom-bar taps give a light haptic tick, the sign-in screen has a soft violet glow.

## CI/CD: test, then build
`.github/workflows/mobile-build.yml` now has two jobs:
1. **Analyse + test** - `flutter analyze` (real errors stop the run) and `flutter test` (every test must pass; summary shown on the run page).
2. **Build APK** - runs only after job 1 is green, then publishes the APK on the *mobile-latest* release.
New tests: layout on a small 320 dp phone with big text (no overflow, light + dark, all placeholders), photo viewer swiping, notice page, offline cache storage.

## Not in the app
Your notes inside the Achievements card about the **website** (sidebar on mobile, big loading logo, mobile-only website design) belong to the website code, which is not part of this upload; send me the website files when you want those done.
