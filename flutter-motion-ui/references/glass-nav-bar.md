# Liquid-glass navigation bar

`assets/motion_kit/glass_nav_bar.dart` → `GlassNavBar`.

## What makes it read as glass

Four layers, back to front. Remove any one and it looks like a grey pill.

1. **Drop shadow** outside the clip — lifts the bar off the content.
2. **Backdrop blur + saturation boost** (`ImageFilter.compose(blur, saturation matrix)`) — content scrolling underneath becomes soft colour, not grey mush. The saturation step is what gives the "liquid" vibrancy.
3. **Translucent tint with a diagonal sheen** — two alphas of the surface colour, top-left lighter.
4. **1 px gradient rim** — bright at top-left, nearly gone mid-way, a little light at bottom-right. This fake light edge is the single most important detail.

The active indicator is a brighter "lens" pill that slides between items with a slight overshoot; the icon scales up a touch and switches to its filled variant.

## Required scaffold setup

Glass only works if something is behind it:

```dart
Scaffold(
  extendBody: true,                       // body paints under the bar
  body: IndexedStack(index: tab, children: pages),
  bottomNavigationBar: GlassNavBar(
    items: const [
      GlassNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      GlassNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explore'),
      GlassNavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag, label: 'Bag'),
      GlassNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ],
    currentIndex: tab,
    onTap: (i) => setState(() => tab = i),
  ),
)
```

Every scrollable in a tab needs bottom padding so the last row can scroll clear:

```dart
ListView(padding: EdgeInsets.only(bottom: GlassNavBar.reservedHeight(context)), ...)
```

## Tuning

| Want | Change |
|---|---|
| More frosted | `blur: 30`, raise tint alphas |
| Clearer / more "liquid" | `blur: 16`, lower tint alphas, keep the rim |
| Dark pill on light app (wallet reference) | `tint: Colors.black`, `accent: Colors.white` |
| Label next to active icon (profile reference) | `showSelectedLabel: true` |
| Full-width docked instead of floating | `margin: EdgeInsets.zero`, reduce radius by wrapping/forking |
| Brand glow | add a second coloured `BoxShadow` with low alpha |

Keep 3–5 items. Icon-only is fine because each item exposes its `label` to semantics.

## Tab state

- `IndexedStack` keeps each tab alive (scroll position, form input). Tabs should not animate with a push transition; if a cross-fade is wanted, wrap the stack in a short `AnimatedSwitcher` keyed by index only when tabs are cheap to rebuild.
- Tab index is UI state: keep it in the shell widget, or in the router (`StatefulShellRoute`) when deep links must select a tab. Do not put it in a global provider unless another feature needs to switch tabs.
- Re-tapping the active tab should scroll that tab to top / pop its stack to root.

## Hide on scroll (optional)

```dart
NotificationListener<UserScrollNotification>(
  onNotification: (n) {
    if (n.direction == ScrollDirection.reverse) hide.value = true;
    if (n.direction == ScrollDirection.forward) hide.value = false;
    return false;
  },
  child: page,
)
// shell
ValueListenableBuilder(valueListenable: hide, builder: (_, h, child) =>
  AnimatedSlide(offset: h ? const Offset(0, 1.4) : Offset.zero, duration: Motion.base, curve: Motion.standard, child: child), child: navBar)
```

## Performance

- `BackdropFilter` re-blurs whatever is under it every frame that area changes. The pill is small, so this is cheap; a full-width, tall glass panel over a video or map is not.
- Never nest one `BackdropFilter` inside another, and do not put glass on list rows.
- On low-end Android, offer a fallback: if a frame-time check or a "reduce transparency" setting says so, render the same pill with an opaque `surface` colour at ~0.96 alpha and no filter. Keep the rim and shadow — it still looks intentional.
- Impeller handles backdrop blur well on iOS and modern Android; always test in profile mode on a real device.

## True refraction (optional upgrade)

The kit bar is blur-based "frosted" glass. Real lens-like refraction (content bending at the edges, like the iOS 26 look) needs a fragment shader. Community packages exist for this (the reference recordings import one named `liquid_glass_renderer`). Their APIs are young and change between releases, so if the user wants that look: check the package's current README and platform support (shader-based effects generally require Impeller and are weak or unsupported on web), wrap it behind the same `GlassNavBar` interface, and keep the blur version as the fallback.

## Pitfalls

- **Nothing blurs**: forgot `extendBody: true`, or the page has an opaque background the same colour as the bar — put imagery/colour under it or accept it reads as a soft pill.
- **Inner-page FAB hidden under the bar**: a nested `Scaffold`'s FAB does not respect the shell's bar; offset it by `GlassNavBar.reservedHeight`.
- **Snackbars/sheets under the bar**: show them from the shell's `ScaffoldMessenger`/root navigator, with `behavior: SnackBarBehavior.floating` and a bottom margin.
- **Keyboard pushes the bar up**: set `resizeToAvoidBottomInset: false` on the shell and let inner pages handle insets, or hide the bar while a text field is focused.
- **Hard edge on the blur**: the clip radius and the rim radius must match (`height / 2`).
