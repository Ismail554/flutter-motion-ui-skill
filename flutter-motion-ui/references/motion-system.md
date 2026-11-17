# Motion system

## Contents
1. Tokens and why these values
2. Choreography rules
3. Implicit vs explicit — choosing the tool
4. Recipes not covered by the kit
   - Splash sequence
   - Blur focus-in / cross-blur between screens
   - Loader → check mark
   - Progress ring and fill bars
   - Pulsing / radar / scanner ambience
   - Background and theme colour lerp
   - Scroll-linked collapsing header
   - Animated bar chart
5. Performance notes

---

## 1. Tokens

All values live in `motion_kit/motion.dart`. Measured from the reference recordings (sampled at 30 fps):

| Token | ms | Observed in |
|---|---|---|
| `instant` | 100 | press-down scale on keypad keys and buttons |
| `fast` | 180 | toggle switches, chip select, OTP digit pop, focus border |
| `base` | 280 | button enable/disable tint, state cross-fades, list row insert |
| `slow` | 420 | each block of a staggered entrance, sheet content |
| `page` | 460 | route pushes, bottom sheets rising |
| `hero` | 560 | workout card → detail header, product carousel → detail |
| `long` | 900 | calorie/amount count-up, progress fills, route draw |
| `staggerStep` | 55 | gap between sibling entrances |
| `successHold` | 900 | time a success tick stays before the flow continues |

Curves:

- `standard` (0.2, 0, 0, 1) — moving/resizing something already on screen.
- `enter` (0.05, 0.7, 0.1, 1) — arriving; decelerates for most of its length, which is what makes entrances feel soft.
- `exit` (0.3, 0, 0.8, 0.15) — leaving; gets out of the way.
- `overshoot` — small pop for ticks, selected stars, nav lens. Never on large surfaces or text blocks.
- `Motion.spring` / `Motion.bouncy` — for `controller.animateWith(SpringSimulation(Motion.spring, from, to, velocity))` on anything released by a finger, so velocity carries through. Do not pass them to `controller.fling(springDescription: …)`: `fling` asserts on under-damped springs, which both of these are, and the crash only shows on the release path that happy-path tests skip.

Do not add new durations per screen. If something feels wrong at `base`, it is usually the curve or the distance, not the duration.

## 2. Choreography

- **Order follows reading order**: header → hero content → secondary content → actions. The primary action button arrives last so the eye lands on it.
- **Distance is small**: 12–24 px of travel for entrances. Large travel reads as "sliding panels", small travel plus fade reads as "settling".
- **Cap the stagger**: 3–7 blocks. For lists, stagger only the first screenful (`Entrance.maxStaggered`), and switch the entrance off for rows built later or rebuilt on scroll-back (`Entrance(enabled: !entered, …)` with a flag set after the first stagger) — otherwise cards re-fade every time they return to view.
- **Outgoing first, incoming second**: when swapping content, the old content fades in the first ~40% and the new arrives in the remaining ~60% (see `buildAppTransition`). Overlapping two full-opacity layers looks muddy.
- **Sheet then content**: the sheet surface moves as one piece; its icon, title, body and buttons then stagger in (seen in every confirmation sheet in the references). Buttons start disabled-looking and tint in last.
- **Number, then label**: on success screens the tick pops, then the amount counts up, then supporting text fades, then the Done button.
- **Return trips are quieter**: popping back uses the reverse transition at ~80% duration with no extra entrance stagger. Re-running the entrance every time a user comes back is tiring — `Entrance` naturally avoids this because the previous route stays mounted.

## 3. Implicit vs explicit

| Situation | Tool |
|---|---|
| A property depends on state (colour, size, radius, opacity, alignment) | `AnimatedContainer`, `AnimatedOpacity`, `AnimatedAlign`, `AnimatedScale`, `AnimatedSlide`, `AnimatedDefaultTextStyle` |
| A widget is replaced by another | `AnimatedSwitcher` / `StateSwitcher` (give children distinct keys) |
| A number or colour tweens to a new value | `TweenAnimationBuilder` (animates from the *current* value whenever `end` changes) |
| Content height changes | `AnimatedSize` (wrap the smallest subtree possible) |
| Finger drives it | `AnimationController` whose `value` you set in drag callbacks, released with `fling` |
| Runs forever | `AnimationController..repeat()` inside its own small `StatefulWidget` + `RepaintBoundary` |
| Several parts on one timeline | one controller + `Interval` curves per part |

A multi-part timeline looks like this — one controller, each part gets a slice:

```dart
late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
late final _logo  = CurvedAnimation(parent: _c, curve: const Interval(0.00, 0.35, curve: Motion.enter));
late final _title = CurvedAnimation(parent: _c, curve: const Interval(0.20, 0.55, curve: Motion.enter));
late final _bar   = CurvedAnimation(parent: _c, curve: const Interval(0.40, 1.00, curve: Motion.standard));
```

Always dispose controllers, and build them with `Motion.of(context, d)` or skip to `value = 1` when `Motion.reduced(context)`.

## 4. Recipes

### Splash sequence

References: logo ring draws → mark scales in → wordmark fades up → thin progress line fills → whole splash fades/zooms through into home, whose blocks then stagger in.

- Drive the visual with one controller and `Interval`s as above.
- **Gate on real readiness**, not a timer: `await Future.wait([bootstrap(), minSplash])` where `minSplash` is ~1.2 s so the animation is never cut, then navigate with `AppTransition.fadeThrough` using `pushReplacement`.
- For the "zoom through the logo" exit, scale the logo up (1 → 12) with `Motion.exit` while fading the splash background; the next route fades in underneath.
- Keep the native launch screen colour identical to the first Flutter frame so there is no flash.

### Blur focus-in / cross-blur

Used in the alarm, OTP and device-pairing references: the old screen blurs and dims while the new content sharpens into place.

```dart
// Blur the *outgoing* layer in place while an overlay state is active.
TweenAnimationBuilder<double>(
  tween: Tween(end: busy ? 12 : 0),
  duration: Motion.base,
  builder: (_, sigma, child) => ImageFiltered(
    enabled: sigma > 0.05,
    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
    child: child,
  ),
  child: content,
)
```

Stack the loader/success view above it with `StateSwitcher`. For incoming content use `Entrance(blur: 8)`. Blur the content layer, not a full-screen `BackdropFilter`, when you only need the content soft — it is cheaper and avoids blurring the status bar.

### Loader → check mark

The pattern in every submit flow: spinner arc → circle closes → tick draws → small pop.

```dart
class CheckPainter extends CustomPainter {
  CheckPainter(this.t, this.color);
  final double t; final Color color;            // t: 0..1
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .08..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(s.width * .28, s.height * .52)
      ..lineTo(s.width * .45, s.height * .68)
      ..lineTo(s.width * .74, s.height * .36);
    final m = path.computeMetrics().first;
    c.drawPath(m.extractPath(0, m.length * t), p);
  }
  @override
  bool shouldRepaint(CheckPainter o) => o.t != t || o.color != color;
}
```

Drive `t` with a `TweenAnimationBuilder(tween: Tween(begin: 0, end: 1), duration: Motion.slow, curve: Motion.standard)` when the state becomes success, inside a circle that scales in with `Motion.overshoot`. Fire `Haptics.success()` from the state listener at the same moment.

### Progress ring and fill bars

`TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: Motion.long, curve: Motion.standard)` feeding `CircularProgressIndicator(value:)` or a `FractionallySizedBox(widthFactor:)`. Pair with `CountUpText` using the same duration and curve so the number and the ring land together.

### Ambient loops (pulse, radar sweep, scanner line)

- Put each loop in its own tiny `StatefulWidget` wrapped in `RepaintBoundary` so it does not repaint the screen.
- Pulse: `ScaleTransition` + `FadeTransition` on 2–3 concentric circles with phase offsets (`(t + i / n) % 1`).
- Radar sweep ("finding driver"): `CustomPaint` drawing a `SweepGradient` rotated by `t * 2π`, clipped to a circle.
- Scanner line: a gradient bar translated between the frame corners with `repeat(reverse: true)`; on detection switch the frame colour with a `ColorTween` and stop the loop.
- Stop loops when the state leaves (dispose with the widget) — `StateSwitcher` removing the subtree handles this.

### Background / theme colour lerp

- App-wide light/dark: `MaterialApp(themeMode: mode, themeAnimationDuration: Motion.slow, themeAnimationCurve: Motion.standard)` — widgets that read `Theme.of(context)` cross-fade automatically. Hard-coded colours are the only things that will "pop", which is a good audit.
- Page tint follows selection (card carousel recolouring the action button): `TweenAnimationBuilder<Color?>(tween: ColorTween(end: selected.color), duration: Motion.base, …)` or lerp continuously from the `PageController.page` fraction for a tint that follows the finger.
- Scene change (night alarm → morning): `AnimatedContainer` with a gradient `decoration`; gradients lerp when stop counts match.

### Scroll-linked collapsing header

Seen in the delivery and wallet references: the header shrinks, the search field fades out, a compact title stays pinned.

Prefer slivers: `CustomScrollView` + `SliverPersistentHeader(pinned: true, delegate: …)` and compute `t = (shrinkOffset / (maxExtent - minExtent)).clamp(0, 1)` to lerp height, opacity and radius. This is scroll-driven, so it needs no duration — it is tied 1:1 to the finger, which is why it feels solid. Avoid `setState` in a scroll listener for this; if you must listen, use a `ValueNotifier` + `ValueListenableBuilder` around only the header.

### Animated bar chart

Bars grow from zero with a per-bar stagger: one controller, `Interval(i * .08, .6 + i * .08)` per bar, `FractionallySizedBox(heightFactor:)` aligned bottom. Highlight "today" with the accent colour and animate highlight changes with `AnimatedContainer`.

## 5. Performance

- Animate `Transform`/`Opacity`; they skip layout. `AnimatedContainer` changing width/height in a long list will relayout siblings.
- `Opacity` over a large, complex subtree saves a layer — fine for a few items, avoid on dozens at once. `FadeTransition` is cheaper than rebuilding `Opacity`.
- `BackdropFilter` and `ImageFiltered` blur cost scales with area and sigma. Keep glass surfaces small, keep sigma ≤ 30, never stack blurs.
- `RepaintBoundary` around anything that animates continuously and around heavy static content beneath a moving overlay.
- Pass the static part as `child` to `AnimatedBuilder`/`TweenAnimationBuilder` so it is not rebuilt each frame.
- Precache hero and splash images (`precacheImage`) so the first transition does not hitch on decode.
- Profile in **profile mode on a real mid-range Android device**; the simulator and debug mode both lie about jank.
