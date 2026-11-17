import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single source of truth for timing and easing.
///
/// Every animation in the app reads from here. A screen that invents its own
/// `Duration(milliseconds: 350)` is how an app stops feeling like one product.
abstract final class Motion {
  // ── Durations ────────────────────────────────────────────────────────────
  /// Press feedback, ripples, tiny colour ticks.
  static const instant = Duration(milliseconds: 100);

  /// Toggles, chips, checkbox, icon swaps, focus borders.
  static const fast = Duration(milliseconds: 180);

  /// Default for a single element changing state (button enable, card tint).
  static const base = Duration(milliseconds: 280);

  /// Element entering the screen, sheets content, expanding sections.
  static const slow = Duration(milliseconds: 420);

  /// Full page transitions and bottom sheets.
  static const page = Duration(milliseconds: 460);

  /// Hero / container transforms — the one "showpiece" per navigation.
  static const hero = Duration(milliseconds: 560);

  /// Count-ups, progress fills, route drawing.
  static const long = Duration(milliseconds: 900);

  /// Gap between siblings in a staggered entrance.
  static const staggerStep = Duration(milliseconds: 55);

  /// How long a success state stays on screen before the flow moves on.
  static const successHold = Duration(milliseconds: 900);

  // ── Curves ───────────────────────────────────────────────────────────────
  /// On-screen element moving from A to B.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Something arriving: fast start, long soft landing.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Something leaving: accelerates away, never lingers.
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Small celebratory pop (check marks, selected stars, badges). Use sparingly.
  static const Curve overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

  // ── Springs (for anything the finger drives) ─────────────────────────────
  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.82,
  );

  static final SpringDescription bouncy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.6,
  );

  // ── Accessibility ────────────────────────────────────────────────────────
  /// True when the OS asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Effectively-instant duration used when motion is reduced. Deliberately
  /// not [Duration.zero]: some framework widgets (AnimatedSize) assert when
  /// asked to animate over zero time.
  static const none = Duration(milliseconds: 1);

  /// Collapses [d] when the user prefers reduced motion. Use for every
  /// duration handed to an implicit animation or controller:
  /// `Motion.of(context, Motion.slow)`.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? none : d;
}

/// One vocabulary of haptics for the whole app, so the same kind of event
/// always feels the same. Fire-and-forget by design.
abstract final class Haptics {
  /// Ordinary tap on a button or tile.
  static void tap() => unawaited(HapticFeedback.lightImpact());

  /// Moving between options: tabs, chips, picker rows, slider detents.
  static void selection() => unawaited(HapticFeedback.selectionClick());

  /// Something was committed or succeeded.
  static void success() => unawaited(HapticFeedback.mediumImpact());

  /// Something was rejected: wrong code, failed request.
  static void error() => unawaited(HapticFeedback.heavyImpact());
}
