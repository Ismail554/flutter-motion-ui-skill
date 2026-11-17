# Flutter best practices

The engineering habits that keep animated UI correct, fast and maintainable. The kit and example in `assets/` follow all of these and pass the strict lint set in `assets/project_setup/analysis_options.yaml`; code written with this skill should too.

## Contents
1. Project structure
2. Widgets: composition, const, keys
3. Lifecycle and resources
4. Async and BuildContext
5. Dart 3 language habits
6. Layout that survives real devices
7. Performance
8. Theming, text and assets
9. Localization and accessibility
10. Errors, loading and empty states
11. Testing
12. Tooling

---

## 1. Project structure

Follow the project's existing layout. For a new project, feature-first with a thin shared core scales best:

```
lib/
  main.dart                 // runApp + ProviderScope / top-level providers only
  app.dart                  // MaterialApp, theme, router
  core/
    motion/                 // the motion kit
    theme/                  // tokens, buildTheme(), ThemeExtensions
    widgets/                // shared UI used by 2+ features
    utils/                  // formatters, extensions
  features/
    transfers/
      data/                 // repositories, DTOs, API/storage
      domain/               // models (immutable), business rules
      presentation/
        transfers_screen.dart
        send_money_screen.dart
        controllers/        // notifiers / cubits
        widgets/            // widgets private to this feature
```

- Dependencies point inward: presentation → domain ← data. Widgets never call HTTP or storage; they talk to a controller, which talks to a repository interface.
- A widget moves to `core/widgets` only when a second feature needs it. Premature sharing creates parameters nobody wants.
- One public widget/class per file, file named after it in `snake_case`. Private helpers (`_Tile`) can share the file.
- Keep `main.dart` free of UI so tests can pump `App` with overrides.

## 2. Widgets

**Compose small widgets; do not write helper methods that return widgets.** A `_buildHeader()` method rebuilds with its parent every time and cannot be `const`. A `_Header` widget class gets its own element, can be `const`, rebuilds only when its inputs change, and shows up in DevTools. This matters most on animated screens, where something rebuilds every frame.

**`const` everywhere it compiles.** Const widgets are canonicalised and skipped during rebuilds. The lints `prefer_const_constructors` and friends enforce it.

**`StatelessWidget` by default.** Reach for `StatefulWidget` only for things with a lifecycle: controllers, focus nodes, animation/gesture state. Business state does not live in `State` (see `state.md`).

**Keys**
- Dynamic lists: `ValueKey(item.id)` on each child. Never the index — reordering or removal would attach state and animations to the wrong row.
- `AnimatedSwitcher` children must have different keys (or types) to animate.
- `GlobalKey` only when you truly need cross-tree access (forms, `AnimatedList`); they are expensive and must be unique.
- Do not create keys inside `build` (`UniqueKey()` there destroys state every frame).

**Build methods are pure and cheap.** No I/O, no controller creation, no `Future`s started, no navigation. Build may run 60–120 times a second during an animation.

**Prefer the lightest widget**: `SizedBox` over `Container` for size, `ColoredBox`/`DecoratedBox` for paint, `Padding` for padding. `Container` is fine when you need several at once.

**Parameters**: required named parameters for what a widget needs, sensible defaults for the rest, callbacks typed (`VoidCallback`, `ValueChanged<T>`). Pass data and callbacks down, not controllers or `BuildContext`.

## 3. Lifecycle and resources

Everything created must be released, in `dispose`, in reverse order of creation:

| Create | Release |
|---|---|
| `AnimationController`, `CurvedAnimation` | `.dispose()` |
| `TextEditingController`, `FocusNode`, `ScrollController`, `PageController` | `.dispose()` |
| `StreamSubscription`, `Timer` | `.cancel()` |
| `addListener` | `removeListener` |
| `ChangeNotifier` / `ValueNotifier` you own | `.dispose()` |

- Create them as `late final` fields or in `initState`, never in `build`.
- `CurvedAnimation` registers a listener on its parent: keep it in a field and dispose it. For throw-away curved values inside builders use `animation.drive(CurveTween(curve: …))`, which holds nothing.
- `initState` cannot read inherited widgets (`Theme.of`, `MediaQuery.of`); use `didChangeDependencies` for that.
- When a widget's configuration can change, handle it in `didUpdateWidget` (update a controller's duration, restart an animation on a new trigger).
- Use `SingleTickerProviderStateMixin` for one controller, `TickerProviderStateMixin` for several; tickers pause automatically when the route is not visible.
- In Riverpod, clean up with `ref.onDispose`; in Bloc, override `close`.

## 4. Async and BuildContext

- **Check after every await** before touching UI or state: `if (!context.mounted) return;` in widgets, `if (!ref.mounted) return;` in notifiers, `if (isClosed) return;` in cubits. The lint `use_build_context_synchronously` is set to error for this reason.
- Capture what you need *before* the await when possible: `final navigator = Navigator.of(context);`.
- **Never drop a Future silently.** Either `await` it or mark the intent with `unawaited(...)` (lints `unawaited_futures`, `discarded_futures`). Fire-and-forget haptics go through `Haptics.*`, which does this once.
- Prevent re-entry: ignore a second tap while a request is in flight (state is `Submitting`, button status is `loading`).
- `FutureBuilder`/`StreamBuilder` with a future created in `build` re-runs the request on every rebuild. Create it once (in `initState` or, better, a provider).
- Wrap risky async work in `try/catch` that converts exceptions into a state the UI can render. Catch specific exception types where the handling differs.
- Timeouts and cancellation: long requests need a timeout and should be abandoned when the screen goes away.

## 5. Dart 3 language habits

- **Sealed classes + exhaustive `switch` expressions** for state. No `default:` branch — you want the compiler error when a state is added.
- **Pattern matching** to destructure: `SendDone(:final transfer) => …`, `if (state case Editing(:final error?)) …`.
- **Records** for small multi-value returns `(double progress, String label)` instead of ad-hoc classes or lists.
- **Immutable models**: `final` fields, `const` constructors, `copyWith`, value equality (`==`/`hashCode`, or `freezed`/`equatable` if the project uses them). Mutable models break diffing, `select`, and animations keyed on equality.
- **Null safety without `!`**: prefer `?.`, `??`, early returns and pattern `case final x?`. A `!` is a claim that needs a reason.
- **Enhanced enums** for fixed sets with data (`enum OrderStatus { placed('Order placed'), … }`).
- **Extension types / extensions** for small helpers (`context.colors`, money/date formatting) instead of utility classes full of statics.
- `final` by default for locals; `var` only when reassigned. Type public APIs explicitly; let locals infer.
- Collections: collection-`if`/`for` and spreads instead of imperative list building in `build`.
- Avoid `dynamic`; enable `strict-casts`, `strict-inference`, `strict-raw-types`.

## 6. Layout that survives real devices

- **Never assume screen height.** Any screen with a keypad, form or picker must scroll when space runs out: `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: viewport.maxHeight)` + `Column(mainAxisAlignment: spaceBetween)` gives "fills the screen when it can, scrolls when it can't". The example flow uses exactly this and is tested at 320×480.
- `SafeArea` for notches and the home indicator; `MediaQuery.viewInsetsOf(context).bottom` for the keyboard.
- Use the specific `MediaQuery.sizeOf / paddingOf / viewInsetsOf / platformBrightnessOf` accessors — `MediaQuery.of(context)` rebuilds on *any* media change (e.g. every keyboard animation frame).
- Text scales: test at 1.3× and 2×, and at 320 wide with 1.6× for every screen with rows of text. Use `Flexible`/`Expanded` + `maxLines` + `overflow`, or `FittedBox(fit: BoxFit.scaleDown)` for single-line hero numbers. Do not fix heights on containers that hold text.
- Adaptive, not fixed: breakpoints from `LayoutBuilder` constraints (the widget's own space), not device type. Cap content width on tablets/desktop (`ConstrainedBox(maxWidth: 600)`, centred).
- `Expanded`/`Flexible` only directly inside `Row`/`Column`/`Flex`; unbounded-height errors usually mean a scrollable inside a `Column` without `Expanded`.
- Avoid `IntrinsicHeight/Width` and `shrinkWrap: true` on long lists — both are O(n) or worse. Use slivers to combine scrolling sections.

## 7. Performance

- **Lazy lists**: `ListView.builder` / `SliverList.builder` / `GridView.builder` for anything that can exceed a screen. Set `itemExtent` or `prototypeItem` when rows are uniform.
- **Scope rebuilds**: watch state with `select`/`BlocSelector`; put the `Consumer`/builder as low as possible; split big screens.
- **Animate cheaply**: transform and opacity first; pass static subtrees as `child` to `AnimatedBuilder`/`TweenAnimationBuilder`; isolate continuous animations in `RepaintBoundary`.
- **Images**: specify `cacheWidth`/`cacheHeight` (or `ResizeImage`) near display size, `precacheImage` for hero/splash art, use placeholders with `frameBuilder`/`FadeInImage`, and a caching package for network images if the project has one. Prefer vector (SVG/icon fonts) for flat art.
- **Expensive effects are a budget**: blur, `saveLayer` (triggered by `Opacity` on complex subtrees, `ClipRRect` with `Clip.antiAliasWithSaveLayer`, `ShaderMask`), and large shadows. Use `Clip.antiAlias` at most, and only where needed.
- **Heavy computation off the UI thread**: `compute`/`Isolate.run` for JSON over a few hundred KB, image processing, sorting large lists.
- Do not call `setState` on a parent for something only a leaf shows; use `ValueNotifier` + `ValueListenableBuilder` for high-frequency local values (scroll offset, drag progress).
- Measure before optimising: profile mode, real device, DevTools performance overlay; look at build vs raster time to know which side to fix.

## 8. Theming, text and assets

- All colours, type and component styling come from `ThemeData` (+ `ThemeExtension`s). Feature code contains no hex values; this is what makes dark mode and animated theme switches work with zero per-screen effort.
- Build light and dark from one `buildTheme(Brightness)` function; style stock widgets through component themes instead of restyling at each call site.
- `ColorScheme.fromSeed` gives a coherent palette quickly; override individual roles to match a brand.
- Use `Color.withValues(alpha: …)` on current SDKs (`withOpacity` is deprecated).
- Fonts and images declared in `pubspec.yaml`; provide 2x/3x raster variants or vectors; reference paths through generated/central constants, not string literals scattered in widgets.
- System UI: set status/navigation bar styling via `AppBarTheme.systemOverlayStyle` or `AnnotatedRegion<SystemUiOverlayStyle>` per screen, so light-on-dark hero screens keep readable status icons.

## 9. Localization and accessibility

- No user-facing string literals in widgets when the project has l10n set up (`flutter_localizations` + ARB); follow it. The kit widgets take all visible text and semantic labels as parameters for this reason.
- Format numbers, currency and dates with `intl` and the active locale; never hand-build `"$" + amount`.
- Layout must tolerate longer translations and RTL: use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start/end`, and avoid hard-coded left/right.
- Every interactive custom control has `Semantics` (role, label, state: `button`, `selected`, `toggled`, `enabled`); decorative images are excluded; icon buttons have tooltips.
- Custom gestures need an accessible alternative (the kit's `SlideToConfirm` exposes a semantic tap).
- Minimum 48×48 dp touch targets on Android (44×44 pt iOS); contrast ≥ 4.5:1 for body text, including over images and glass.
- Respect `MediaQuery.disableAnimationsOf` (via `Motion.of`) and bold-text/high-contrast settings; never convey state by colour alone.
- Announce important async results for screen readers (`SemanticsService.announce`) when they are not otherwise focused.

## 10. Errors, loading and empty states

- Every data-backed screen designs four states: loading, content, empty, error. An empty list with no explanation is a bug.
- Errors are specific and actionable ("Couldn't load transfers · Retry"), keep prior content when a refresh fails, and never wipe user input.
- First load: skeleton shaped like the content. Refresh: keep content, show a subtle indicator (`RefreshIndicator`). Action: in-place button state.
- Map exceptions to user-facing messages in one place (repository/controller), not in widgets. Log the original with stack trace (`debugPrint`/logger, never `print`).
- Global safety nets: `FlutterError.onError` and `PlatformDispatcher.instance.onError` reporting to the project's crash tool; a friendly `ErrorWidget.builder` in release.

## 11. Testing

- **Controllers/notifiers**: plain unit tests of state transitions with fake repositories — fast, and where most logic lives when widgets are thin.
- **Widgets/flows**: `testWidgets` that drive the UI and assert on outcomes, not animation internals. `assets/examples/send_money_flow_test.dart` shows the pattern, including:
  - setting a phone-sized surface (`tester.view.physicalSize`),
  - fixed-time pumping instead of `pumpAndSettle` when loops are on screen,
  - a small-screen overflow test (`tester.takeException()` is null),
  - a reduced-motion test.
- Find by semantics label, tooltip or text rather than by widget type or key where possible — it tests accessibility for free.
- Override providers/inject fakes for network and time; never hit real services in tests.
- Golden tests are worth it for shared components and themes (light/dark), less so for whole animated screens.

## 12. Tooling

- `assets/project_setup/analysis_options.yaml`: `flutter_lints` plus strict analyzer modes and a curated rule set. Merge it into the project's file rather than overwriting team choices.
- `dart format .` before finishing; `flutter analyze` must be clean (no ignored warnings without a comment explaining why).
- `dart fix --apply` resolves most mechanical lint findings and API migrations after an SDK upgrade.
- Pin dependencies with caret ranges, keep `pubspec.lock` committed for apps, and prefer a framework solution over a new package for anything a few dozen lines can do.
- Flutter moves fast: when an API in this skill disagrees with the installed SDK, trust the SDK — check the deprecation message or `flutter analyze` output and adapt.
