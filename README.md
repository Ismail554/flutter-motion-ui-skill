# flutter-motion-ui

A [Claude skill](https://docs.claude.com/en/docs/claude-code/skills) for building polished, animated Flutter UI where **motion and state are designed together**.

Ask Claude for a Flutter screen or flow and, with this skill loaded, it will:

- model the flow as named states and let those states drive the animation,
- take every duration, curve and haptic from one shared file instead of scattering numbers through screens,
- use a small, dependency-free widget kit for the hard parts (glass nav bar, slide to confirm, morphing buttons, rolling numbers, animated lists, OTP boxes, page routes and Hero helpers),
- honour the phone's reduce-motion setting,
- write tests, including small-screen, large-text and failure-path tests,
- fit into the project it finds: its state library, theme and folder structure.

It was built by studying 22 screen recordings of well-made mobile apps, then tested by having Claude build six apps with and without it (results below).

---

## Contents

- [Install](#install)
- [Use it](#use-it)
- [What is in the kit](#what-is-in-the-kit)
- [How the skill works](#how-the-skill-works)
- [Trial results](#trial-results)
- [Repository layout](#repository-layout)
- [Check the kit yourself](#check-the-kit-yourself)
- [Limits](#limits)
- [Licence](#licence)

---

## Install

### Claude Code (all your projects)

Copy the `flutter-motion-ui` folder into your personal skills folder.

macOS / Linux:

```bash
git clone https://github.com/Ismail554/flutter-motion-ui-skill.git
mkdir -p ~/.claude/skills
cp -r flutter-motion-ui-skill/flutter-motion-ui ~/.claude/skills/
```

Windows (PowerShell):

```powershell
git clone https://github.com/Ismail554/flutter-motion-ui-skill.git
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse flutter-motion-ui-skill\flutter-motion-ui "$HOME\.claude\skills\"
```

Start a new Claude Code session afterwards so the skill is picked up.

### Claude Code (one project only)

Copy the folder into that project instead, and commit it so your team gets it too:

```bash
mkdir -p .claude/skills
cp -r /path/to/flutter-motion-ui-skill/flutter-motion-ui .claude/skills/
```

### Claude apps (claude.ai / desktop)

Download `flutter-motion-ui.skill` from the [Releases](https://github.com/Ismail554/flutter-motion-ui-skill/releases) page and upload it under **Settings → Capabilities → Skills**.

### Check it loaded

In a new session, ask:

> What skills do you have for Flutter?

Claude should mention `flutter-motion-ui`.

---

## Use it

You do not need to name the skill. Describe the screen or flow you want in plain words:

> Build a phone verification flow with Riverpod: phone number, 6-digit code with a resend timer, a nice error on a wrong code, and a verified screen. Dark theme.

> Add a floating glass bottom bar to my app and make the list-to-detail transition a hero.

> This checkout screen feels janky. It has four booleans for loading and error. Clean up the state and make the transitions smooth.

> Add a cart and checkout to my existing Provider app. Keep my state management.

What Claude does with the skill:

1. **Reads your project first**: state library, theme, router, folder structure. It extends what is there and does not add a second state library.
2. **Copies only the kit files the task needs** into your shared UI folder (default `lib/core/motion/`).
3. **Designs the states and the moments**: which states the flow has, and which motion marks each change.
4. **Verifies**: `dart format`, `flutter analyze`, and tests.

If you want the stricter lint set the kit passes, ask Claude to merge `assets/project_setup/analysis_options.yaml` into your project. It will not overwrite rules you already chose.

---

## What is in the kit

Plain Flutter, no packages. Files live in [`flutter-motion-ui/assets/motion_kit`](flutter-motion-ui/assets/motion_kit).

| File | What it gives you |
|---|---|
| `motion.dart` | `Motion` durations, curves and springs; `Motion.of(context, …)` for reduced motion; `Haptics.tap / selection / success / error` |
| `entrance.dart` | `Entrance` staggered fade-and-rise for content; `StateSwitcher` for cross-fading between states |
| `page_routes.dart` | `AppRoute`, `AppPageTransitions.theme()`, `showAppSheet`, Hero helpers |
| `glass_nav_bar.dart` | `GlassNavBar` floating blurred bottom bar, with `reservedHeight` for scroll padding |
| `morph_button.dart` | `Pressable`, `MorphButton`, `AsyncMorphButton` (idle → loading → success / failure) |
| `slide_to_confirm.dart` | `SlideToConfirm` drag-to-commit with haptics and an accessible tap alternative |
| `rolling_number.dart` | `CountUpText`, `RollingText` for totals, balances and counters |
| `otp_boxes.dart` | `OtpBoxes` with error shake; `Shake` |
| `animated_items.dart` | `AnimatedItems<T>` list that animates inserts and removals from a plain list |
| `motion_kit.dart` | Barrel file |

A complete worked flow is in [`assets/examples/send_money_flow.dart`](flutter-motion-ui/assets/examples/send_money_flow.dart) (list → keypad → slide → sending → success → new row animates in), with its tests beside it.

---

## How the skill works

The idea in one line: **state drives motion**. A screen changes because its state changed, and the animation is how that change is shown.

- **Named flow states.** A flow is a `sealed class` (or enum) such as `Editing → Sending → Sent | Failed`, never a pile of `isLoading` / `hasError` flags. The UI is an exhaustive `switch` over it.
- **One source of truth.** Totals, badges and lists are derived from one piece of state, so they cannot disagree.
- **One place for timing.** Durations and curves come from `Motion.*`. Changing the feel of the app is a one-file edit.
- **Reduced motion is built in.** `Motion.of(context, …)` collapses durations when the OS asks for less motion.
- **One showpiece per navigation.** A hero, or a staggered entrance, not everything at once.

The detail is in the reference files, which Claude reads only when it needs them:

| Reference | Covers |
|---|---|
| [`motion-system.md`](flutter-motion-ui/references/motion-system.md) | Tokens, curves, springs, stagger rules |
| [`navigation-transitions.md`](flutter-motion-ui/references/navigation-transitions.md) | Page transitions, Hero, sheets |
| [`glass-nav-bar.md`](flutter-motion-ui/references/glass-nav-bar.md) | Building and placing the glass bar |
| [`state.md`](flutter-motion-ui/references/state.md) | Sealed states, optimistic updates, side effects |
| [`components.md`](flutter-motion-ui/references/components.md) | Each kit widget and when to use it |
| [`flutter-best-practices.md`](flutter-motion-ui/references/flutter-best-practices.md) | Structure, lifecycle, async safety, layout, performance, accessibility, testing |
| [`consistency-checklist.md`](flutter-motion-ui/references/consistency-checklist.md) | Final pass before calling a screen done |
| [`video-analysis.md`](flutter-motion-ui/references/video-analysis.md) | Notes on the 22 reference recordings and how to rebuild each pattern |

---

## Trial results

Claude built six apps twice, once with the skill and once without. Each project was checked for a clean `flutter analyze`, passing tests, no overflow on launch at several screen sizes, plus checks specific to the prompt.

| Prompt | With skill | Without skill |
|---|---|---|
| Phone + OTP verification (Riverpod) | 9 / 9 | 7 / 9 |
| Food delivery home, glass nav, hero | 10 / 10 | 9 / 10 |
| Settings with theme switch and Save (no packages) | 9 / 9 | 8 / 9 |
| Add cart and checkout to an existing Provider app | 12 / 12 | 11 / 12 |
| Reading list: optimistic favourite, rollback, undo | 11 / 11 | 10 / 11 |
| Wallet: per-tab navigation, hero, back blocking | 12 / 13 | 9 / 13 |
| **Total** | **63 / 64** | **54 / 64** |

How to read this honestly:

- **One run per side.** There is no variance estimate, so treat the gap as suggestive.
- **Claude is already good at this without the skill.** Every baseline project built the requested features and had passing tests.
- **Where the skill made the difference:** hard-coded durations (the baseline failed that check in five of six projects), reduced motion (ignored in two baseline projects), small-screen and large-text overflow (one baseline project), and flow state mixed with booleans (one baseline project).
- **Cost:** with-skill projects were roughly 2 to 4 times larger, kit included.
- **The one with-skill failure** was a sideways overflow in two text rows at 320 wide with 1.6× text. The skill now requires a test for that. That fix, and a slider crash the trials found and fixed, have not been re-trialled.
- **Nothing was viewed on a device.** The checks cover code and layout, not how the motion looks.

The prompts and checks are in [`flutter-motion-ui/evals`](flutter-motion-ui/evals).

---

## Repository layout

```text
flutter-motion-ui/
  SKILL.md                  Instructions Claude reads first
  references/               Deeper guides, read on demand
  assets/
    motion_kit/             The widget kit (copy what you need)
    examples/               Worked send-money flow and its tests
    project_setup/          Strict analysis_options.yaml template
  evals/                    Six trial prompts with their checks
README.md
```

---

## Check the kit yourself

The kit and example are meant to stay analyzer-clean and tested. To check them in a scratch project (Flutter 3.47 / Dart 3.13 was used here):

```bash
flutter create --platforms=android,ios kit_check
cd kit_check
flutter pub add flutter_riverpod
mkdir -p lib/motion_kit lib/examples
cp ../flutter-motion-ui/assets/motion_kit/*.dart lib/motion_kit/
cp ../flutter-motion-ui/assets/examples/send_money_flow.dart lib/examples/
cp ../flutter-motion-ui/assets/examples/send_money_flow_test.dart test/
cp ../flutter-motion-ui/assets/project_setup/analysis_options.yaml .
```

Then, in `lib/examples/send_money_flow.dart` and `test/send_money_flow_test.dart`, point the imports at your package (`package:kit_check/…` instead of `package:your_app/…`, and the kit path you copied to), and run:

```bash
flutter analyze
flutter test
```

Only the example needs Riverpod. The kit itself has no dependencies.

---

## Limits

- The glass bar is a blur, saturation and tint approximation. It is not Apple's system Liquid Glass material.
- The kit targets phones. Tablet and desktop layouts are not covered.
- Visual quality was never judged on a device during the trials. Run your app and look.
- The skill guides Claude. It does not guarantee a result, so review the code it writes.

---

## Licence

[MIT](LICENSE)
