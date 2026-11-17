import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'motion.dart';

/// Plays a one-shot fade + slide (optionally blur / scale) when first built.
///
/// Stagger siblings with [index]:
/// ```dart
/// Column(children: [
///   Entrance(index: 0, child: Header()),
///   Entrance(index: 1, child: BalanceCard()),
///   Entrance(index: 2, child: QuickActions()),
/// ])
/// ```
/// In lazy lists pass the item index; it is capped by [maxStaggered] so row 40
/// does not wait two seconds.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
    this.blur = 0,
    this.scaleFrom = 1,
    this.duration = Motion.slow,
    this.curve = Motion.enter,
    this.maxStaggered = 8,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final Duration delay;

  /// Starting displacement in logical pixels.
  final Offset offset;

  /// Starting blur sigma. 0 disables (cheapest). 6–10 gives the soft
  /// "focus in" look; avoid on long lists.
  final double blur;
  final double scaleFrom;
  final Duration duration;
  final Curve curve;
  final int maxStaggered;

  /// When false the child is shown immediately with no animation.
  ///
  /// Lazy lists rebuild rows that scroll back into view, which would
  /// replay the entrance. Keep a flag in the screen's state, pass
  /// `enabled: !entered`, and set it once the first stagger has played
  /// (or simply pass `enabled: index < firstScreenful` and never for
  /// rows created later).
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _t = CurvedAnimation(
    parent: _c,
    curve: widget.curve,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    final i = widget.index.clamp(0, widget.maxStaggered);
    final wait = widget.delay + Motion.staggerStep * i;
    if (wait == Duration.zero) {
      unawaited(_c.forward());
    } else {
      _timer = Timer(wait, () {
        if (mounted) unawaited(_c.forward());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        final inv = 1 - t;
        Widget out = Transform.translate(
          offset: widget.offset * inv,
          child: widget.scaleFrom == 1
              ? child
              : Transform.scale(
                  scale: lerpDouble(widget.scaleFrom, 1, t)!,
                  child: child,
                ),
        );
        if (widget.blur > 0) {
          final sigma = widget.blur * inv;
          out = ImageFiltered(
            enabled: sigma > 0.05,
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: out,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: out);
      },
    );
  }
}

/// Cross-fades between children when [stateKey] changes, with a small
/// directional slide. This is the workhorse for "state drives the UI":
///
/// ```dart
/// StateSwitcher(
///   stateKey: state.runtimeType,
///   child: switch (state) {
///     Loading() => const LoaderView(),
///     Success(:final data) => ResultView(data),
///     Failure(:final message) => ErrorView(message),
///   },
/// )
/// ```
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = Motion.base,
    this.slide = const Offset(0, 0.04),
    this.alignment = Alignment.center,
    this.animateSize = false,
  });

  final Object stateKey;
  final Widget child;
  final Duration duration;

  /// Fractional offset the incoming child travels from.
  final Offset slide;
  final Alignment alignment;

  /// Wraps in [AnimatedSize] so the container grows/shrinks with the content.
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, duration);
    final switcher = AnimatedSwitcher(
      duration: d,
      reverseDuration: d * 0.6,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        // ignore: use_null_aware_elements (keeps Dart < 3.8 compatibility)
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: slide, end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
    if (!animateSize) return switcher;
    return AnimatedSize(
      duration: d,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}
