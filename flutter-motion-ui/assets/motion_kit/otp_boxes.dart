import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

enum OtpStatus { editing, verifying, error, success }

/// Horizontal shake that fires every time [trigger] changes value.
/// Keep a counter in state (`errorCount++`) so the same error can shake twice.
class Shake extends StatefulWidget {
  const Shake({
    super.key,
    required this.trigger,
    required this.child,
    this.distance = 10,
    this.shakes = 3,
  });

  final int trigger;
  final Widget child;
  final double distance;
  final int shakes;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !Motion.reduced(context)) {
      Haptics.error();
      unawaited(_c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        // Decaying sine: big first swing, settles to rest.
        final dx =
            math.sin(t * widget.shakes * 2 * math.pi) *
            widget.distance *
            (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Display-only OTP cells driven entirely by state, so it works with the
/// system keyboard (hidden TextField) or a custom keypad.
///
/// * active cell gets the accent border and a blinking caret,
/// * each digit pops in,
/// * [OtpStatus.error] turns the borders red and shakes the row,
/// * [OtpStatus.success] turns them green.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.code,
    this.length = 6,
    this.status = OtpStatus.editing,
    this.errorCount = 0,
    this.boxSize = const Size(48, 56),
    this.spacing = 10,
    this.radius = 14,
    this.obscure = false,
    this.successColor = const Color(0xFF1FA463),
    this.semanticLabel,
  });

  /// Spoken description. Pass a localized string in translated apps.
  final String? semanticLabel;

  final String code;
  final int length;
  final OtpStatus status;

  /// Increment on every failed attempt to retrigger the shake.
  final int errorCount;
  final Size boxSize;
  final double spacing;
  final double radius;
  final bool obscure;
  final Color successColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Motion.of(context, Motion.fast);

    return Semantics(
      label:
          semanticLabel ??
          'Verification code, ${code.length} of $length digits entered',
      excludeSemantics: true,
      child: Shake(
        trigger: errorCount,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                _Cell(
                  char: i < code.length ? (obscure ? '•' : code[i]) : null,
                  active: status == OtpStatus.editing && i == code.length,
                  size: boxSize,
                  radius: radius,
                  duration: d,
                  border: switch (status) {
                    OtpStatus.error => scheme.error,
                    OtpStatus.success => successColor,
                    _ when i == code.length => scheme.primary,
                    _ when i < code.length => scheme.onSurface.withValues(
                      alpha: 0.28,
                    ),
                    _ => scheme.onSurface.withValues(alpha: 0.12),
                  },
                  fill: scheme.onSurface.withValues(alpha: 0.05),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.char,
    required this.active,
    required this.size,
    required this.radius,
    required this.duration,
    required this.border,
    required this.fill,
  });

  final String? char;
  final bool active;
  final Size size;
  final double radius;
  final Duration duration;
  final Color border;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.headlineSmall;
    return AnimatedContainer(
      duration: duration,
      curve: Motion.standard,
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: active ? 1.6 : 1.2),
      ),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.overshoot,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 0.5, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: char != null
            ? Text(char!, key: ValueKey(char), style: text)
            : active
            ? _Caret(color: border, height: size.height * 0.42)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.color, required this.height});
  final Color color;
  final double height;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(width: 2, height: widget.height, color: widget.color),
  );
}
