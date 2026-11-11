# Upgrade 1.4 - full-size icon, new loading screen, app name, design-skill rules

## From your screenshots
| Screenshot | Fix |
|---|---|
| App icon looked small on the home screen | The old icon was the seal on a **light grey** square, so it looked tiny. New icon: the seal fills the whole icon on a **dark navy** background (same colour as the seal's outer ring). Works with round and rounded-square launcher shapes. (`assets/images/app_icon.png`, `app_icon_foreground.png`, background `#05101C` in `pubspec.yaml`.) |
| Loading screen was a plain logo + spinner | **New loading screen**: seal fades in with a glow and a slowly turning colour ring, school name + motto rise in, a progress bar, and a plain-words status that changes with time ("Opening your school..." -> "Connecting..." -> "The school server is waking up - the first open can take up to a minute"). Respects the phone's "remove animations" setting. |
| App name | The app is now named **Tufanganj Vivekanand Vidyalaya (H.S.)** (icon label, loading screen, sign-in screen, window title). Phones cut long labels ("Tufanganj Viv..."); to use a shorter label set the repo variable `TVV_APP_NAME`. |

## Rules taken from the UI UX Pro Max skill (github.com/nextlevelbuilder/ui-ux-pro-max-skill)
I ran its search tool on the real repository (design system, UX guidelines, mobile interface rules, Flutter rules) and applied what fits a school app:
* **Reduced motion (rated Critical):** list animations, press effects, shimmer and chart animations all switch off when the phone asks for reduced motion.
* **Touch targets:** every tappable control is at least 44 dp tall (chips, day strip, buttons, icon buttons 48 dp).
* **Contrast 4.5:1:** I measured every text colour; amber, green and red text in light mode failed (3.0-4.4:1) and were darkened so pills and labels now pass.
* **Loading feedback:** skeletons keep the layout; long waits are explained in words; the only looping animations are loaders.
* **Typography:** the **Inter** font (SIL Open Font License) is bundled in the app (`assets/fonts/`), so text looks identical on every phone and works offline.
* **Performance:** the shimmer sits in a `RepaintBoundary` and stops while motion is reduced.
The skill's auto-generated style for "school app" was *Claymorphism with a playful kids font*. I did **not** use it: this app is for class XI-XII students, teachers and the administration, and you asked for an Instagram-like look.

## Files with pictures / fonts
GitHub web upload handles these: upload `mobile/assets/fonts/*` and `mobile/assets/images/app_icon*.png` the same way as other files.
