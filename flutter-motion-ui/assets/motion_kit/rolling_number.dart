import 'package:flutter/material.dart';

import 'motion.dart';

/// Smoothly counts from the previous value to the new one.
/// Use for totals, balances, calories, prices — values with magnitude.
///
/// ```dart
/// CountUpText(value: cart.total, format: (v) => '\$${v.toStringAsFixed(2)}')
/// ```
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.from,
    this.style,
    this.duration = Motion.long,
    this.curve = Motion.standard,
  });

  final double value;

  /// Starting value for the very first build (e.g. 0 to count up on entry).
  /// Later changes always animate from whatever is currently displayed.
  final double? from;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from ?? value, end: value),
      duration: Motion.of(context, duration),
      curve: curve,
      builder: (context, v, _) => Text(
        format(v),
        // Tabular figures stop the text from jittering sideways as digits change.
        style: base.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Each character rolls independently when it changes (odometer style).
/// Use for values typed or ticking one step at a time: keypad amounts, ETA
/// minutes, countdowns, quantity steppers.
///
/// ```dart
/// RollingText('\$${state.amount}', style: display)
/// ```
class RollingText extends StatelessWidget {
  const RollingText(
    this.text, {
    super.key,
    this.style,
    this.duration = Motion.base,
    this.up = true,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;

  /// Direction new characters arrive from. Flip to false for decreasing values.
  final bool up;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final d = Motion.of(context, duration);
    final chars = text.characters.toList();
    final dy = up ? 0.6 : -0.6;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: AnimatedSize(
        duration: d,
        curve: Motion.standard,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chars.length; i++)
              AnimatedSwitcher(
                duration: d,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.center,
                  // ignore: use_null_aware_elements (keeps Dart < 3.8 compatibility)
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, a) {
                  final incoming = child.key == ValueKey('$i${chars[i]}');
                  return ClipRect(
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(0, incoming ? dy : -dy),
                        end: Offset.zero,
                      ).animate(a),
                      child: FadeTransition(opacity: a, child: child),
                    ),
                  );
                },
                child: Text(
                  chars[i],
                  key: ValueKey('$i${chars[i]}'),
                  style: base,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
