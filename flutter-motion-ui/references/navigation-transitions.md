# Navigation and transitions

## Contents
1. Choosing the transition
2. Wiring it app-wide (Navigator and go_router)
3. Hero done properly
4. Container transform (card expands into a screen)
5. Bottom sheets
6. Multi-step flows on one route
7. Returning with results
8. Pitfalls

---

## 1. Choosing the transition

Transitions explain *how two screens relate*. Pick by relationship, not by taste:

| Relationship | Transition | Kit |
|---|---|---|
| No relationship (splash→home, logged-out→logged-in, flow finished→root) | fade-through, slight scale | `AppTransition.fadeThrough` |
| Sibling steps in a sequence | shared axis X (forward = from right) | `AppTransition.sharedAxisX` |
| Parent → child without a shared element | shared axis Y / subtle rise | `AppTransition.sharedAxisY` (default) |
| Parent → child *with* a shared element | `Hero`, rest of page fades | `Hero` + `heroFadeShuttle` |
| Temporary task over current context | bottom sheet | `showAppSheet` |
| Tab switch | none or quick cross-fade; never a slide push | `IndexedStack` / `StateSwitcher` |

Use the same choice for the same relationship everywhere. A user should be able to predict the motion.

## 2. Wiring it app-wide

**Navigator 1.0**

```dart
MaterialApp(
  theme: theme.copyWith(pageTransitionsTheme: AppPageTransitions.theme()),
  ...
)
// explicit:
Navigator.of(context).push(AppRoute(page: const OtpScreen(), transition: AppTransition.sharedAxisX));
```

`AppPageTransitions.theme()` keeps Cupertino transitions on iOS so edge-swipe-back still works. Pass `customOnIOS: true` only if the design demands identical motion on both platforms and you accept losing the interactive swipe (or re-add it yourself).

**go_router**

```dart
CustomTransitionPage<T> appPage<T>(GoRouterState state, Widget child,
        [AppTransition t = AppTransition.sharedAxisY]) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.page,
      reverseTransitionDuration: Motion.page * 0.8,
      transitionsBuilder: (context, a, s, child) => buildAppTransition(t, a, s, child),
    );

GoRoute(path: '/otp', pageBuilder: (c, s) => appPage(s, const OtpScreen(), AppTransition.sharedAxisX)),
```

Tabs: use `StatefulShellRoute.indexedStack` with `GlassNavBar` in the shell; each branch keeps its own stack and scroll position.

## 3. Hero done properly

Hero is the strongest tool and the easiest to get subtly wrong.

```dart
// list
Hero(
  tag: 'workout-image-${w.id}',            // unique per item, namespaced per element
  flightShuttleBuilder: heroFadeShuttle,   // cross-fade source→destination shapes
  child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image(image: w.image, fit: BoxFit.cover)),
)
// detail
Hero(
  tag: 'workout-image-${w.id}',
  flightShuttleBuilder: heroFadeShuttle,
  child: ClipRRect(borderRadius: BorderRadius.zero, child: Image(image: w.image, fit: BoxFit.cover)),
)
```

Rules:

- **Hero the image/shape, not text.** Text changes size and line-wrap mid-flight and looks broken. If a title must travel, wrap it in `Material(type: MaterialType.transparency)` and keep the same style on both ends.
- **Same `BoxFit` and same image provider** on both ends, or the picture jumps on the first and last frame.
- **Tags are unique per route.** The same item shown twice on one screen (carousel + list) needs different tags.
- **Push with a fade-based route** (`AppRoute`), not a slide: the hero should be the only thing travelling. Then stagger the detail's non-hero content with `Entrance(delay: Motion.base)` so it appears as the hero lands.
- **Duration**: make the route `Motion.hero` for hero navigations: `AppRoute(page: …, duration: Motion.hero)`.
- **Curved path**: install `appHeroController()` for an arced flight instead of a straight line.
- **Images must be ready**: `precacheImage` the destination's larger asset on tap-down or when the list item builds.
- **Heroes across tabs / nested navigators do not fly** — each Navigator has its own HeroController.

## 4. Container transform

When a whole card becomes the screen (the live-order mini bar expanding into the tracking screen, a product card opening): the cleanest dependency-free version is a Hero on the *container*:

```dart
Hero(
  tag: 'order-${o.id}',
  flightShuttleBuilder: heroFadeShuttle,
  child: Material(color: surface, borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias, child: MiniOrderBar(o)),
)
// destination: Hero(tag: same, child: Material(color: surface, child: TrackingScreen(o)))
```

`heroFadeShuttle` cross-fades the small content into the large content while the rect grows. If the project already uses the `animations` package, `OpenContainer` does the same with less code — use what is there.

## 5. Bottom sheets

Every confirmation/selection/rating in the references is a sheet with identical behaviour. Use `showAppSheet` so radius, handle, scrim and timing never vary.

Inside the sheet:

```dart
showAppSheet<bool>(context, builder: (context) => Padding(
  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Entrance(index: 0, scaleFrom: .8, offset: Offset.zero, child: const _SheetIcon()),
    Entrance(index: 1, child: Text('Remove card?', style: t.titleLarge)),
    Entrance(index: 2, child: Text('This action cannot be undone', style: t.bodyMedium)),
    const SizedBox(height: 20),
    Entrance(index: 3, child: _SubjectPreview(card)),          // show *what* is affected
    const SizedBox(height: 20),
    Entrance(index: 4, child: Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
      const SizedBox(width: 12),
      Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))),
    ])),
  ]),
));
```

- `mainAxisSize: MainAxisSize.min` + `isScrollControlled: true` (already set) lets the sheet hug its content and animate its height with `AnimatedSize` when content changes (e.g. star rating reveals tag chips and the submit button).
- **A sheet may host its own mini-flow**: selecting → processing → success inside the same sheet using `StateSwitcher(animateSize: true)`, then auto-dismiss after `Motion.successHold`. The payment reference does exactly this.
- For a persistent draggable panel over a map, use `DraggableScrollableSheet` with `snap: true, snapSizes: [.35, .9]` in a `Stack` — not a modal.
- The destructive action runs *after* the sheet has closed (`await showAppSheet(...)` then act), so the removal animation is visible on the page behind.

## 6. Multi-step flows on one route

Auth/onboarding (phone → OTP → password → done) reads best as **one route with an internal step**, not four pushed routes: the progress header stays put while only the body moves, and back just decrements the step.

```dart
PopScope(
  canPop: step == 0,
  onPopInvokedWithResult: (didPop, _) { if (!didPop) controller.back(); },
  child: Column(children: [
    StepProgress(current: step, total: 3),            // animates its own fill
    Expanded(
      child: AnimatedSwitcher(
        duration: Motion.page,
        transitionBuilder: (child, a) {
          final forward = (child.key as ValueKey<int>).value == step ? goingForward : !goingForward;
          final begin = Offset(forward ? .08 : -.08, 0);
          return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(a), child: child));
        },
        child: KeyedSubtree(key: ValueKey(step), child: stepBody),
      ),
    ),
  ]),
)
```

Keep the bottom primary button outside the switcher when it is the same control across steps — only its label/enabled state changes — so it does not flicker.

## 7. Returning with results

Do not pop with a payload and manually patch the previous screen. Write to shared state before popping; the previous screen is already watching (see `state.md`). The pop transition and the list's insert animation then overlap naturally, which is the "new transfer slides into the list as I come back" effect in the wallet reference.

When a flow should return several levels, use `popUntil`/`go('/home')` with `fadeThrough` so it reads as "finished", not "back, back, back".

## 8. Pitfalls

- A `Scaffold` FAB inside a tab page sits **under** a floating nav bar when the shell uses `extendBody: true` (the FAB ignores the bottom padding). Offset it with `floatingActionButtonLocation` or wrap in bottom `Padding` of `GlassNavBar.reservedHeight`.
- `AnimatedSwitcher` only animates when the child's **key or type changes**. Two `Column`s without keys will just swap silently.
- `pumpAndSettle` in tests never settles if a looping animation is mounted; pump fixed durations instead.
- Transparent `PageRouteBuilder(opaque: false)` keeps the route below painting — only use for real overlays.
- Keyboard: dismiss it (`FocusScope.of(context).unfocus()`) before pushing, or the incoming page animates while resizing.
