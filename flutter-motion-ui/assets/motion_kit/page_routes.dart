import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'motion.dart';

/// The three navigation moves the app is allowed to make. Pick by meaning:
///
/// * [AppTransition.fadeThrough] – unrelated destinations (splash → home,
///   auth → app, success → back to list).
/// * [AppTransition.sharedAxisX] – next/previous step of the same flow
///   (phone → OTP → password).
/// * [AppTransition.sharedAxisY] – drilling into a detail when there is no
///   shared element to Hero.
enum AppTransition { fadeThrough, sharedAxisX, sharedAxisY }

Widget buildAppTransition(
  AppTransition type,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // drive() instead of CurvedAnimation: this runs on every transition build
  // and must not leave listeners behind.
  final enter = animation.drive(
    CurveTween(curve: const Interval(0.25, 1, curve: Motion.enter)),
  );
  // The page underneath reacts too, so both screens move as one gesture.
  final cover = secondaryAnimation.drive(
    CurveTween(curve: const Interval(0, 0.45, curve: Motion.exit)),
  );

  Offset inFrom;
  Offset outTo;
  double scaleFrom = 1;
  switch (type) {
    case AppTransition.fadeThrough:
      inFrom = Offset.zero;
      outTo = Offset.zero;
      scaleFrom = 0.96;
    case AppTransition.sharedAxisX:
      inFrom = const Offset(0.08, 0);
      outTo = const Offset(-0.08, 0);
    case AppTransition.sharedAxisY:
      inFrom = const Offset(0, 0.06);
      outTo = const Offset(0, -0.03);
  }

  return FadeTransition(
    opacity: ReverseAnimation(cover),
    child: SlideTransition(
      position: Tween(begin: Offset.zero, end: outTo).animate(cover),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(begin: inFrom, end: Offset.zero).animate(enter),
          child: ScaleTransition(
            scale: Tween(begin: scaleFrom, end: 1.0).animate(enter),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Imperative route: `Navigator.push(context, AppRoute(page: const X()))`.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({
    required Widget page,
    AppTransition transition = AppTransition.sharedAxisY,
    super.settings,
    super.fullscreenDialog,
    Duration duration = Motion.page,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration * 0.8,
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionsBuilder: (context, a, s, child) =>
             buildAppTransition(transition, a, s, child),
       );
}

/// Makes every plain `MaterialPageRoute` use the app transition, so screens
/// pushed without thinking still match:
///
/// ```dart
/// ThemeData(pageTransitionsTheme: AppPageTransitions.theme())
/// ```
/// iOS keeps the Cupertino builder by default so edge-swipe-back still works.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions([this.transition = AppTransition.sharedAxisY]);

  final AppTransition transition;

  static PageTransitionsTheme theme({bool customOnIOS = false}) {
    return PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: p == TargetPlatform.iOS && !customOnIOS
              ? const CupertinoPageTransitionsBuilder()
              : const AppPageTransitions(),
      },
    );
  }

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildAppTransition(transition, animation, secondaryAnimation, child);
}

/// One sheet style for the whole app: same radius, handle, scrim and timing.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool showHandle = true,
  Color? backgroundColor,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: showHandle,
    backgroundColor: backgroundColor ?? theme.colorScheme.surface,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: const AnimationStyle(
      duration: Motion.page,
      reverseDuration: Motion.base,
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    ),
    builder: (context) => Padding(
      // Sheet rides above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Hero flight that cross-fades and keeps rounded corners, so an image card
/// can grow into a full-bleed header without popping.
///
/// ```dart
/// Hero(
///   tag: 'workout-${w.id}',
///   flightShuttleBuilder: heroFadeShuttle,
///   child: ClipRRect(borderRadius: ..., child: Image(...)),
/// )
/// ```
Widget heroFadeShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final from = (fromContext.widget as Hero).child;
  final to = (toContext.widget as Hero).child;
  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(opacity: ReverseAnimation(animation), child: from),
      FadeTransition(opacity: animation, child: to),
    ],
  );
}

/// Curved hero path + matching duration. Put once on `MaterialApp`:
/// `MaterialApp(builder: (c, child) => HeroControllerScope(controller: appHeroController(), child: child!))`
HeroController appHeroController() => HeroController(
  createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
);
