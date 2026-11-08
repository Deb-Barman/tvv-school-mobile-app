# Upgrade 1.1 - what changed

## 1. Screen "going outside the phone" - what I did
I could not reproduce this without your phone, and I found no single oversized widget by reading the code. So I removed every
likely cause instead:
* The **More** screen was a 2-column grid with a fixed aspect ratio (cards could not hold their text on narrow screens or with
  big system fonts). It is now a plain list that always fits.
* The timetable's teacher row used a fixed 218 px box next to a second field; it now shares the line and can never overflow.
* Text growth is limited to **15 %** (was 30 %) and everything is clipped to the screen width.
* The manual "edge-to-edge" system-bar mode was removed; Android decides it and `Scaffold`/`SafeArea` keep content inside.
If it still happens, send a screenshot + phone model and I will pin it down.

## 2. New look (Instagram-style)
White / true-black, hairline borders instead of heavy shadows, colourful story rings, icon-only bottom bar (filled icon
when selected, your own picture as the last tab), shortcut "stories" row on every dashboard, notices as feed posts, gallery as a
3-column photo grid, profile header like an Instagram profile, flat grey inputs and pill chips, restyled loading placeholders.
The Super Admin sign-in is now hidden: **long-press the school seal** on the sign-in screen.

## 3. Items 1-15 from the review
| # | Status |
|---|---|
| 1 First build never run | Still true - the first Actions run is the test. Code re-analysed against Flutter 3.41.9: 0 errors. |
| 2 Tests don't gate the build | Analyse + tests now run but never block the APK (you asked for a download first). |
| 3 `pubspec.lock` ignored | No longer ignored. After the first green build you may commit the generated `mobile/pubspec.lock`. |
| 4 Signing | Kept optional (step 4 of MOBILE_SETUP). The workflow now remembers its test key so updates install over each other. |
| 5 Offline cache | Done (saved copies + "offline" banner, wiped on sign-in/out). |
| 6 Push notifications | Not done: needs a backend endpoint + Firebase. |
| 7 India time | Done everywhere. |
| 8 Unsaved changes | Done for marks entry and attendance marking. |
| 9 Images | Done: pictures are decoded at display size (no full-size decoding). No disk cache (would need a new package). |
| 10 Accessibility | Improved (labels on avatars, bubbles, tabs, tappable cards). Text growth limited to 15 %. |
| 11 Super Admin link | Hidden behind long-press on the seal. |
| 12 Privacy policy / account deletion | Not needed for an APK you share yourself; needed before Play Store / App Store. |
| 13 `prepare_platforms.py` wipes android/ios | Unchanged (CI only). |
| 14 `minSdk` | Forced to at least 23 in the generated Gradle file. |
| 15 Tests | Added: school clock, offline cache. Login test updated. |

## 4. Workflow
`mobile-build.yml` now builds **only the APK**. Download: Releases -> "TVV School app - latest build" -> TVV-School.apk.
(iOS and AAB steps were removed. `mobile-api-check.yml` is a separate optional check and is unchanged.)
