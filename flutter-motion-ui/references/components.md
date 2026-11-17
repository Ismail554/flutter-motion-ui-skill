# Component recipes

Building blocks seen repeatedly in the reference apps that are not in the kit, because they depend on app design. Each is short enough to write fresh per project; follow the shape and use the project's tokens.

## Contents
1. Step progress header
2. Selectable card / chip / option row
3. Star rating with reactive label
4. Card carousel that re-tints the page
5. Vertical product pager with scale/parallax
6. Wheel pickers and calendar sheet
7. Skeleton loading
8. OTP wiring (system keyboard and custom keypad)
9. Status timeline
10. Live tracking: map, sheet, moving marker
11. Persistent mini status bar
12. Quantity stepper and animated totals
13. Custom toggle / theme picker

---

## 1. Step progress header

Dots or segments connected by a line that fills as steps complete; completed steps turn into ticks.

```dart
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});
  final int current, total; // current is 0-based
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < total; i++) Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: i <= current ? 1 : 0),
              duration: Motion.slow, curve: Motion.standard,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v, minHeight: 4, color: c.primary, backgroundColor: c.onSurface.withValues(alpha: .12)),
            ),
          ),
        ),
      ),
    ]);
  }
}
```

It lives *outside* the step switcher so it stays still while content moves.

## 2. Selectable card / chip / option row

One recipe covers ride tiers, payment methods, regions, countries, tip amounts, feedback tags:

```dart
Pressable(
  onTap: () => onSelect(option),
  child: AnimatedContainer(
    duration: Motion.fast, curve: Motion.standard,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: selected ? c.primary.withValues(alpha: .10) : c.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? c.primary : c.outlineVariant, width: selected ? 1.6 : 1),
    ),
    child: Row(children: [
      Expanded(child: content),
      AnimatedScale(scale: selected ? 1 : 0, duration: Motion.fast, curve: Motion.overshoot,
        child: Icon(Icons.check_circle, color: c.primary)),
    ]),
  ),
)
```

- Single-select: state holds `selectedId`. Multi-select (feedback tags): a `Set<String>`.
- Selecting something usually **unlocks the primary button** and may **change its label** ("Submit rating" → "Submit & tip $5"): derive the label from state and let `MorphButton` re-render; wrap the label change in an `AnimatedSwitcher` if it should cross-fade.
- Filled chips invert (dark background, light text) — animate both with the same `AnimatedContainer` + `AnimatedDefaultTextStyle`.

## 3. Star rating with reactive label

Tap or drag across stars; stars fill left to right with a tiny stagger; an emoji + word below changes ("Okay" → "Great" → "Amazing!"); follow-up questions appear.

```dart
Row(mainAxisSize: MainAxisSize.min, children: [
  for (var i = 1; i <= 5; i++)
    GestureDetector(
      onTap: () { Haptics.selection(); onChanged(i); },
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: i <= rating ? 1 : 0),
        duration: Motion.fast + Motion.staggerStep * (i <= rating ? i : 0) * .5,
        curve: Motion.overshoot,
        builder: (_, t, __) => Transform.scale(
          scale: 1 + .2 * math.sin(t * math.pi),          // gentle pop mid-way
          child: Icon(t > .5 ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 36, color: Color.lerp(c.outline, const Color(0xFFF5B301), t)),
        ),
      ),
    ),
])
```

Below it: `StateSwitcher(stateKey: rating, child: Text(labelFor(rating)))`, and wrap the follow-up section in `AnimatedSize` + `Entrance` so it grows in once `rating > 0`. The question itself can depend on the score ("What could be better?" vs "What made it great?").

## 4. Card carousel that re-tints the page

Checkout reference: swipe between payment cards; the slide button, dots and accents take the card's colour.

- `PageView.builder(controller: PageController(viewportFraction: .88))`, `onPageChanged` → `selectedCardId` in state.
- Neighbour cards scale down: wrap each page in an `AnimatedBuilder(animation: pageController)` and compute `scale = 1 - (page - index).abs().clamp(0, 1) * .08`.
- Accent: `TweenAnimationBuilder<Color?>(tween: ColorTween(end: selected.color), duration: Motion.base)` high enough to feed the button and dots.
- Dots: `AnimatedContainer` width 6 → 18 for the active one.
- Delete: a small close badge → confirmation sheet that previews the card → on confirm, remove from shared state. Animate the card out (scale .9, fade, slight rotate) by wrapping the page content in `StateSwitcher(stateKey: card.id)`; the pager then shows the next card.

## 5. Vertical product pager with scale/parallax

Coffee reference: products stacked vertically, the focused one large and centred, neighbours peeking and smaller; title and price cross-fade.

- `PageView(scrollDirection: Axis.vertical, controller: PageController(viewportFraction: .55))`.
- Per item: `delta = page - index`; `Transform.translate(offset: Offset(0, delta * -40))` + `Transform.scale(scale: 1 - delta.abs() * .35)` + opacity. That is the parallax.
- Title/price above: `StateSwitcher(stateKey: current.id)`.
- Tap → detail with `Hero` on the product image; size options change the price through `RollingText`.

## 6. Wheel pickers and calendar sheet

Booking reference: one sheet, two steps (date → time) with a small step track, Next/Confirm at the bottom.

- Month grid: `GridView.count(crossAxisCount: 7)`; selected day is a filled circle that **moves** — simplest is `AnimatedContainer` per cell (old shrinks, new grows). Month change: `StateSwitcher(stateKey: month, slide: Offset(dir * .1, 0))`.
- Header chip shows the live selection and updates with `StateSwitcher`.
- Time: three `ListWheelScrollView.useDelegate(itemExtent: 36, physics: FixedExtentScrollPhysics(), perspective: .003, diameterRatio: 1.4, onSelectedItemChanged: …)` side by side with a rounded highlight bar behind the centre row; call `Haptics.selection()` on each change. Style the centred item bolder via `AnimatedDefaultTextStyle`.
- Step 1 → 2 inside the sheet: `StateSwitcher(animateSize: true)`; a back arrow appears beside Confirm.

## 7. Skeleton loading

Prefer a skeleton shaped like the real content over a centred spinner for first loads.

```dart
class Shimmer extends StatefulWidget { /* one controller..repeat(), 1200 ms */ }
// build:
ShaderMask(
  blendMode: BlendMode.srcATop,
  shaderCallback: (r) => LinearGradient(
    begin: Alignment(-1 - 2 * (1 - t * 2), 0), end: Alignment(1 - 2 * (1 - t * 2), 0),
    colors: [base, highlight, base], stops: const [.35, .5, .65]).createShader(r),
  child: child, // grey rounded boxes matching the real layout
)
```

One `Shimmer` wraps the whole skeleton (one ticker, one shader). Swap skeleton → content with `StateSwitcher`, then let content blocks `Entrance` in. If data returns in under ~150 ms, skip the skeleton entirely.

## 8. OTP wiring

`OtpBoxes` only draws. Feed it from either input source:

**System keyboard** — an invisible `TextField` under the boxes:

```dart
Stack(alignment: Alignment.center, children: [
  OtpBoxes(code: state.code, length: 6, status: status, errorCount: state.errorCount),
  Positioned.fill(child: Opacity(opacity: 0, child: TextField(
    controller: _c, focusNode: _f, autofocus: true,
    keyboardType: TextInputType.number, maxLength: 6,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    showCursor: false, enableInteractiveSelection: false,
    onChanged: controller.codeChanged,
  ))),
])
```

**Custom keypad** — keys call `controller.digit(d)` / `backspace()` (see the example's `_Keypad`).

Behaviour to implement in the controller: auto-submit when the last digit lands; on failure go back to editing with `errorCount + 1`, **clear the code after the shake** (≈ `Motion.slow`), show the message under the boxes; resend countdown from a periodic stream; on success switch boxes to `OtpStatus.success`, hold, then continue.

## 9. Status timeline

Vertical list of steps (placed → preparing → on the way → delivered) with a connecting line:

- Each node: `AnimatedContainer` circle that fills and shows a tick (`AnimatedSwitcher`) when done; the *current* node pulses.
- Connector: `TweenAnimationBuilder` height factor 0 → 1 with the accent colour when the step completes.
- Trailing time/"Done" badge fades in per row.
- Drive it from a single `currentStep` in the order state; never per-row booleans.

## 10. Live tracking: map, sheet, moving marker

Layout: `Stack[ map, top bar (back, status pill), DraggableScrollableSheet ]`.

- **Status pill** at the top: `StateSwitcher(stateKey: status)` — "Finding driver" → "On the way" → "Arrived" → "In transit" → "Completed".
- **Sheet header** shows the one fact that matters now (ETA box with `RollingText` minutes, turning into "NOW"), then driver row, vehicle, addresses. Header text changes with `StateSwitcher`; the primary button morphs per phase (chat → slide to start → rate trip).
- **Finding phase**: map dimmed, radar sweep around the pickup point, "Looking for drivers nearby…" + Cancel.
- **Marker along a route** without a maps SDK (or as an overlay on one):

```dart
final metric = routePath.computeMetrics().first;
TweenAnimationBuilder<double>(
  tween: Tween(end: progress),                     // 0..1 from live state
  duration: tickInterval, curve: Curves.linear,    // glide between updates
  builder: (_, p, child) {
    final tan = metric.getTangentForOffset(metric.length * p)!;
    return Positioned(
      left: tan.position.dx - 14, top: tan.position.dy - 14,
      child: Transform.rotate(angle: -tan.angle + math.pi / 2, child: child));  // face along the road
  },
  child: const CarIcon(),
)
```

  Draw travelled vs remaining route with `extractPath(0, len * p)` in the accent colour over a grey full path.
- With `google_maps_flutter` / `flutter_map`: animate the camera with the SDK, but still interpolate marker lat/lng yourself between updates (a `Tween<LatLng>`-style lerp driven by one controller).
- Arrival: marker stops, pill and header switch, haptic, and the sheet's action becomes the next step.

## 11. Persistent mini status bar

Delivery reference: a compact "Preparing your food · 17 min" card pinned above the nav bar on every tab, updating live, expanding into the tracking screen on tap.

- Rendered by the **shell**, above `GlassNavBar`, only when `activeOrderProvider` has data — `AnimatedSwitcher` + `SizeTransition` so it slides in/out.
- Content watches the same provider as the tracking screen (`select` the few fields shown). Title cross-fades on status change; ETA uses `RollingText`.
- Tap → container-transform into the tracking screen (see `navigation-transitions.md` §4).
- Add its height to the scroll bottom padding.

## 12. Quantity stepper and animated totals

`−  2  +` where the number uses `RollingText(up: increased)`, buttons are `Pressable`, minus disables at the minimum. Line total and cart total use `CountUpText`/`RollingText` reading derived state, so everything that depends on the quantity moves in the same frame.

## 13. Custom toggle / theme picker

- Switch: `AnimatedContainer` track colour + `AnimatedAlign` thumb, `Motion.fast`, selection haptic. Wrap in `Semantics(toggled: value)`.
- Theme picker: two preview cards (light/dark) as selectable cards; choosing one sets `themeMode` in an app-level provider (persisted), and `MaterialApp.themeAnimationDuration` cross-fades the whole UI. Unsaved changes reveal a Save bar (see `state.md` §5).
