# Consistency, quality and performance checklist

## Design tokens — set up once

```dart
// lib/core/theme/tokens.dart
abstract final class Space { static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0; static const page = 20.0; }
abstract final class Radii { static const sm = 12.0, md = 20.0, lg = 28.0; }

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.success, required this.warning, required this.glassTint});
  final Color success, warning, glassTint;
  @override AppColors copyWith({Color? success, Color? warning, Color? glassTint}) =>
      AppColors(success: success ?? this.success, warning: warning ?? this.warning, glassTint: glassTint ?? this.glassTint);
  @override AppColors lerp(AppColors? o, double t) => o == null ? this : AppColors(
      success: Color.lerp(success, o.success, t)!, warning: Color.lerp(warning, o.warning, t)!, glassTint: Color.lerp(glassTint, o.glassTint, t)!);
}
extension AppThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppColors get brand => Theme.of(this).extension<AppColors>()!;
}
```

`lerp` on the extension is what lets custom colours animate during a theme switch.

Build both `ThemeData`s from one function (`buildTheme(Brightness)`) so light and dark cannot diverge: component themes (`filledButtonTheme`, `inputDecorationTheme`, `bottomSheetTheme`, `cardTheme`, `chipTheme`) are defined there, and screens use the stock widgets unstyled.

If the project uses `flutter_screenutil` or similar scaling, keep using it consistently; do not mix scaled and unscaled values.

## Before calling a screen done

**Structure and tokens**
- [ ] No hex colours, raw durations, or magic radii in feature code (search for `Color(0x`, `Duration(`, `circular(`).
- [ ] Page padding, section spacing and card radius match the other screens.
- [ ] Text uses `TextTheme` roles; changing numbers use tabular figures.
- [ ] Works in light and dark; nothing "pops" during a theme switch.

**States**
- [ ] Loading, empty, error and content are all designed — not just content.
- [ ] Error keeps user input and offers a retry.
- [ ] Double-tap on the primary action cannot submit twice.
- [ ] Leaving the screen mid-request does not throw (async gaps guarded).
- [ ] Data changed here is correct on every other screen that shows it.

**Motion**
- [ ] Entrance: 3–7 blocks staggered; nothing blocks input while it plays.
- [ ] Every state change animates from the previous state (no hard cuts, no double layers).
- [ ] Exactly one showpiece per navigation.
- [ ] Back navigation feels like the reverse and is faster.
- [ ] Success/failure have haptics; selections have a light tick.
- [ ] Reduced-motion setting on: flow still works, nothing essential is lost.

**Layout robustness**
- [ ] Small phone (≈360×640) and large text scale (1.3×): no overflow. Flows with keypads/pickers need a scroll view or flexible spacing.
- [ ] Keyboard open: focused field visible, primary button reachable.
- [ ] Safe areas: notch, home indicator, floating nav bar clearance.
- [ ] Long names/amounts ellipsise or scale down (`FittedBox`) instead of breaking the row.

**Accessibility**
- [ ] Icon-only controls have semantic labels/tooltips; custom controls expose `Semantics` (button/selected/toggled).
- [ ] Gesture-only controls have a tap/assistive alternative (`SlideToConfirm` has one built in).
- [ ] Touch targets ≥ 44×44; text contrast ≥ 4.5:1, also over glass and images (add a scrim/gradient under text on photos).
- [ ] State changes that matter are announced or visible as text, not colour alone.

**Performance**
- [ ] `flutter analyze` clean.
- [ ] No `BackdropFilter`/blur per list row; glass surfaces small; no nested blurs.
- [ ] Continuous animations isolated with `RepaintBoundary`; static subtrees passed as `child`.
- [ ] Lists are lazy (`ListView.builder`/slivers); images sized (`cacheWidth`) and hero images precached.
- [ ] Frequently-ticking state is watched with `select` by a small widget.
- [ ] All controllers, timers, stream subscriptions and focus nodes disposed.
- [ ] Checked in profile mode on a real device when one is available; say so explicitly when it was not.

## Auditing an existing app for consistency

1. Grep for hard-coded values: `Color(0x`, `Colors.` in feature folders, `Duration(milliseconds`, `BorderRadius.circular(`, `EdgeInsets.` with odd numbers, `fontSize:`.
2. List every button, input, card, sheet and nav variant; collapse near-duplicates into one shared widget with parameters.
3. List every page transition in use; map each to one of the three `AppTransition`s.
4. Replace boolean state clusters with sealed states screen by screen, starting with the flows users touch most.
5. Change one category at a time and run the app between passes — large mixed refactors of visuals and state are hard to review.
