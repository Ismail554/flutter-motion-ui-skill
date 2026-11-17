---
name: flutter-motion-ui
description: Build polished, animated Flutter UI where motion and state are designed together - page transitions, Hero / shared-element animations, liquid-glass floating nav bars, staggered entrances, bottom-sheet confirmations, slide-to-confirm, OTP and multi-step auth flows, morphing loading-to-success buttons, rolling numbers, animated list insert/remove, live tracking screens, theme switching, plus the state management (sealed flow states, single source of truth, optimistic updates) that keeps screens consistent. Use this skill whenever the user asks to build, design, restyle, animate or make smoother / more premium any Flutter screen, widget, flow or app (splash, onboarding, auth, home, detail, checkout, profile, delivery, ride-sharing, wallet, fitness), or mentions Flutter transitions, hero, glassmorphism / liquid glass, micro-interactions, UI consistency, design tokens, janky animation, or state management for UI (Riverpod, Bloc, Provider, messy setState), even if they never say the word animation.
---

# Flutter Motion UI

This skill produces Flutter screens that feel like one coherent, hand-finished product: every element arrives with intent, every tap answers back, every state change is visible, and data stays consistent across screens.

It was distilled from frame-by-frame analysis of 22 reference app recordings (wallet, delivery, ride-sharing, fitness, auth/OTP, alarm, checkout, booking, device pairing). `references/video-analysis.md` lists what each one does and which recipe reproduces it.

## The core idea: state drives motion

Almost every "smooth" moment in the references is the same mechanism: **a piece of state changed, and the UI animated from the old value to the new one.** Nobody called `controller.forward()` from a button handler. So the work is always:

1. Model the screen's states explicitly (a sealed class, not five booleans).
2. Render with a `switch` over that state.
3. Wrap what changes in an implicit animation (`AnimatedSwitcher`, `AnimatedContainer`, `TweenAnimationBuilder`, or a kit widget) so the difference between two states animates itself.

When this is done, animation and state management stop being two problems. Interrupted animations, double taps, and "loading spinner next to success tick" bugs disappear because the impossible states cannot be represented.

Explicit `AnimationController`s are reserved for three things: finger-driven gestures, looping ambience (pulses, scanners), and choreographed multi-part sequences.

## Workflow

### 1. Read the project before writing anything

- `pubspec.yaml`: Flutter/Dart SDK, state library already in use (riverpod / bloc / provider / getx / none), router (go_router / auto_route / Navigator), existing animation packages.
- Existing theme, colours, spacing, shared widgets. **Extend what is there**; do not introduce a second design system or a second state library. Match the project's folder structure and naming. In an existing app, keep changes to files you were not asked about as small as the feature needs (a `Hero` wrapper, a padding inset), leave unrelated lint or style clean-ups alone unless asked, and list every existing file you rewrote in your summary so the diff holds no surprises.
- If it is a new project or has no conventions, use the defaults in this skill (Riverpod `Notifier`, Material 3 theme with extensions, `lib/core/` + `lib/features/<name>/`).

### 2. Install the motion kit once

Copy the kit files the task needs into the project's shared UI folder (default `lib/core/motion/`): always `motion.dart`, plus only the widgets you will actually use, and trim the barrel file to match. Copying all ten files for a screen that uses three leaves the user with code nobody calls. The kit is pure Flutter with no dependencies, analyzer-clean and widget-tested. If the project already has an equivalent (its own durations file, its own nav bar), adapt to theirs instead of duplicating.

| File | Gives you |
|---|---|
| `motion.dart` | `Motion.fast/base/slow/page/hero`, curves, springs, reduced-motion helper — the only place durations live; `Haptics.tap/selection/success/error` — the only place haptics are fired |
| `entrance.dart` | `Entrance` (staggered fade/slide/blur-in), `StateSwitcher` (animated `switch` over state) |
| `page_routes.dart` | `AppRoute`, `AppPageTransitions.theme()`, `showAppSheet`, `heroFadeShuttle` |
| `glass_nav_bar.dart` | `GlassNavBar` floating liquid-glass pill with sliding lens indicator |
| `morph_button.dart` | `Pressable`, `MorphButton` (idle→spinner→success), `AsyncMorphButton` |
| `slide_to_confirm.dart` | `SlideToConfirm` drag-to-commit with haptics and status |
| `rolling_number.dart` | `CountUpText`, `RollingText` (odometer digits) |
| `otp_boxes.dart` | `OtpBoxes`, `Shake` |
| `animated_items.dart` | `AnimatedItems<T>` — list that animates inserts/removes from a plain immutable list |

`assets/examples/send_money_flow.dart` is a complete worked flow (list → keypad → slide → sending → success → back, new row animates in). Read it when building any multi-state flow; it is the pattern to imitate. `send_money_flow_test.dart` beside it shows how to test such a flow (full path, small-screen overflow, reduced motion).

`assets/project_setup/analysis_options.yaml` is the strict lint set the kit passes. Offer to merge it into the project's analyzer config; do not overwrite rules a team already chose.

### 3. Design the screen as states and moments, then build

Before coding a screen, write down (in your head or a short comment):

- **States**: what are the distinct things this screen can be? (e.g. `Editing → Submitting → Done | Failed`)
- **Shared data**: what does this screen show that another screen also shows? That data gets one owner.
- **Moments**: entrance, the primary action, each state change, and exit. Each gets one deliberate motion from the table below. Everything else stays still.

Then build in this order: tokens/theme → static layout → state layer → state-change animations → entrance stagger → navigation transition → haptics → reduced-motion and small-screen check.

### 4. Verify

Run `dart format` on the files you touched and `flutter analyze` until clean. Where a device/emulator is available, run the app and actually look at the flow; otherwise write a short widget test that walks the states (see the example test's shape) and run it. Then go through `references/consistency-checklist.md`.

## Which motion for which moment

| Moment | Use | Timing |
|---|---|---|
| Screen first appears | `Entrance(index: n)` on 3–7 top-level blocks, top to bottom | `slow`, 55 ms apart |
| Push to an unrelated screen (splash→home, auth→app) | `AppTransition.fadeThrough` | `page` |
| Next step in the same flow (phone→OTP→password) | `AppTransition.sharedAxisX` + animated step indicator | `page` |
| List item → its detail | `Hero` on the image/card + rest of detail fades in after | `hero` |
| Confirm / choose / rate / pick | `showAppSheet`, content staggered inside | `page` |
| Request in flight | `MorphButton` or `SlideToConfirm` with `status` | `base` per phase |
| Value changes (price, ETA, balance) | `RollingText` (discrete) / `CountUpText` (magnitude) | `base` / `long` |
| Item added / removed | `AnimatedItems` | `base` |
| Screen state changes (loading→content→error) | `StateSwitcher` | `base` |
| Selection (chip, card, tab, star) | `AnimatedContainer` colour/border + small `AnimatedScale` | `fast` |
| Any tap | `Pressable` scale + light haptic | `instant` |
| Validation failure | `Shake` + red border + message; keep the input | `slow` |
| Success | check pops with `Motion.overshoot`, hold `successHold`, then move on | — |

Rules of thumb that keep it tasteful:

- **Entrances play once.** In lazy lists a row that scrolls back into view is rebuilt and would animate again; pass `Entrance(enabled: …)` so only the first appearance animates.
- **One showpiece per navigation.** A Hero *or* a blur-through *or* a big stagger — not all three.
- **Enter slow, exit fast.** Exits run ~60–80% of the enter duration with `Motion.exit`.
- **Things that are related move together; unrelated things are staggered.**
- **Animate transform and opacity; avoid animating layout** in long lists. Blur is expensive — use it on a few hero elements, never per list row.
- **Never block input for decoration.** Entrances must not delay tappability; only real work (network) disables controls.
- Honour reduced motion: the kit already collapses durations via `Motion.of(context, …)`; do the same in any controller you write.

## State management essentials

Full guide with Riverpod / Bloc / ChangeNotifier equivalents: `references/state.md`. The non-negotiables:

- **Flow state is a sealed class**; UI is an exhaustive `switch`. Carry the data each state needs inside it.
- **One owner per piece of shared data.** A list screen and a detail/flow screen read the same provider; the flow writes to it. Do not pass results back through `Navigator.pop` and patch a local copy — that is how screens drift out of sync.
- **Keep the user's input on failure.** Failed submit returns to the editing state with fields intact plus an error.
- **Side effects in listeners, not `build`.** Navigation, snackbars, haptics react to state transitions (`ref.listen`, `BlocListener`).
- **Animation state stays in widgets; business state never does.** A controller knows `Submitting`; it does not know about `AnimationController`s.
- **Live data is a stream mapped into state** (ETA, driver position, order status), with the widget interpolating between ticks so motion is continuous even when updates arrive once a second.
- Guard async gaps (`ref.mounted` / `isClosed` / `mounted`) before touching state after an `await`.

## UI consistency

Consistency is what separates a designed app from a pile of nice screens. Put tokens in the theme and never hard-code them in widgets:

- **Colour**: `ColorScheme` + a `ThemeExtension` for brand extras (success, glass tint, gradients). Widgets read `Theme.of(context)`; this is also what makes animated light/dark switching free.
- **Spacing**: a 4-pt scale (4, 8, 12, 16, 20, 24, 32). One horizontal page padding for the whole app.
- **Radius**: three values (e.g. 12 small / 20 card / 28 sheet) plus pill. Same card = same radius everywhere.
- **Type**: `TextTheme` roles only; tabular figures for any number that changes.
- **Motion**: `Motion.*` only.
- **Components**: one primary button, one sheet style, one input style, one nav bar. If a second variant appears, promote it to a shared widget with a parameter.

Details and the audit list: `references/consistency-checklist.md`.

## Code quality bar

Animated UI multiplies the cost of sloppy code: a build method that runs 120 times a second, a controller that outlives its screen, a layout that only fits one phone. Hold every file to the same bar the kit meets. `references/flutter-best-practices.md` has the full guidance; the points that most often go wrong:

- **Small widget classes, not `_buildX()` helper methods**, with `const` constructors — so a rebuild touches only what changed.
- **Everything created is disposed**: animation/text/scroll/page controllers, `CurvedAnimation`s, focus nodes, timers, subscriptions.
- **Guard every async gap** (`context.mounted` / `ref.mounted` / `isClosed`) and never drop a Future silently (`await` or `unawaited`).
- **Stable keys**: `ValueKey(item.id)` in dynamic lists and on `AnimatedSwitcher` children; never index keys, never keys created in `build`.
- **Layouts that scroll instead of overflow**: any screen with a keypad, form or picker must survive a 320×480 viewport, an open keyboard and 1.3× text.
- **Every screen survives narrow + large text**, not only the flow you were asked about: at 320 wide with 1.6× text, a `Row` holding a title and an amount, a card with a number and a label, or a list tile will overflow sideways unless the text is in `Expanded`/`Flexible` with `maxLines` and `overflow`. Include one test that pumps the app's first screen (and each tab) at 320×568 with `tester.platformDispatcher.textScaleFactorTestValue = 1.6` and expects no exception.
- **Test the unhappy gesture**: a drag released early, a second tap while loading, back pressed mid-request. These paths hold the crashes that a start-to-finish test never touches.
- **No literals in feature code**: colours, radii, spacing, durations, haptics all come from theme/tokens/`Motion`/`Haptics`; user-facing strings follow the project's localization setup.
- **Lazy lists and scoped rebuilds**: builders for anything scrollable, `select` for ticking values, static subtrees passed as `child`.
- **Accessible by construction**: semantics on custom controls, an alternative for gesture-only actions, reduced motion honoured. A `Semantics(label: …, excludeSemantics: true)` wrapper also removes the child's tap action — pass `onTap` to the `Semantics` as well.
- **Tested where it matters**: controller state transitions as unit tests; one widget test per flow asserting outcomes, not animation internals.

## Reference files — read the one that matches the task

- `references/motion-system.md` — tokens explained, choreography, and recipes for effects not in the kit (splash sequences, blur focus-in, progress rings, scanner lines, colour/theme lerps, scroll-linked headers).
- `references/navigation-transitions.md` — page transitions, Hero done properly, container-transform, bottom sheets, multi-step flows, go_router integration.
- `references/glass-nav-bar.md` — how the liquid-glass bar is built, tuning, performance, shell/tab state, known pitfalls.
- `references/state.md` — flow states, shared state, async/optimistic patterns, live streams, in Riverpod, Bloc and ChangeNotifier.
- `references/components.md` — recipes: step progress, selectable cards/chips, star rating with reactive label, card carousel that re-tints the page, wheel pickers, skeletons, live tracking sheet + route marker, persistent mini status bar.
- `references/video-analysis.md` — the 22 analysed recordings: what happens on screen and how to rebuild it.
- `references/flutter-best-practices.md` — project structure, widget composition, lifecycle, async safety, Dart 3 habits, robust layout, performance, theming, l10n/accessibility, error states, testing, tooling. Read before creating a new project structure or when reviewing/refactoring existing code.
- `references/consistency-checklist.md` — tokens, pre-delivery QA, performance and accessibility checks.

## Output expectations

- Deliver complete, runnable files in the project's structure — not fragments with "…rest of your code".
- Use the project's existing packages. Suggest a new package only when it clearly earns its place, and say why.
- Flutter APIs move quickly. If the installed SDK is newer than you are sure about, check the signature (`flutter analyze` is the fastest oracle) rather than guessing.
- When finishing, tell the user briefly which moments were animated and what state shape was used, and flag anything not verified on a device.
