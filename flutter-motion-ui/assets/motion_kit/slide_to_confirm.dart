import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'morph_button.dart' show ActionStatus;
import 'motion.dart';

/// Drag-to-commit control for actions that should not happen by accident
/// (send money, stop alarm, start trip, pay).
///
/// The thumb follows the finger 1:1, the fill grows behind it, the hint label
/// fades as you go. Release past [threshold] → snaps to the end and calls
/// [onConfirmed]; release earlier → springs back.
///
/// [status] lets the state layer show progress after the commit:
/// loading → the track collapses around a spinner, success → check mark.
/// When status returns to idle the thumb resets.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.status = ActionStatus.idle,
    this.enabled = true,
    this.height = 60,
    this.threshold = 0.85,
    this.trackColor,
    this.fillColor,
    this.thumbColor,
    this.thumbIconColor,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onConfirmed;
  final ActionStatus status;
  final bool enabled;
  final double height;
  final double threshold;
  final Color? trackColor;
  final Color? fillColor;
  final Color? thumbColor;
  final Color? thumbIconColor;
  final IconData icon;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _committed = false;
  bool _passedThreshold = false;

  @override
  void didUpdateWidget(SlideToConfirm old) {
    super.didUpdateWidget(old);
    final back =
        widget.status == ActionStatus.idle ||
        widget.status == ActionStatus.failure;
    if (old.status != widget.status && back && _committed) {
      _committed = false;
      _springBack();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Returns the thumb to the start on [Motion.spring].
  ///
  /// Not `fling`: `AnimationController.fling` asserts when given an
  /// under-damped spring, which [Motion.spring] is. The controller clamps to
  /// 0..1, so the spring's small overshoot simply rests at the start.
  void _springBack() {
    unawaited(_c.animateWith(SpringSimulation(Motion.spring, _c.value, 0, 0)));
  }

  void _update(DragUpdateDetails d, double travel) {
    if (!widget.enabled || _committed) return;
    _c.value += d.primaryDelta! / travel;
    final passed = _c.value >= widget.threshold;
    if (passed != _passedThreshold) {
      _passedThreshold = passed;
      Haptics.selection(); // tells the thumb "you can let go now"
    }
  }

  void _end(DragEndDetails d, double travel) {
    if (!widget.enabled || _committed) return;
    final v = (d.primaryVelocity ?? 0) / travel;
    if (_c.value >= widget.threshold || v > 2.5) {
      _committed = true;
      Haptics.success();
      unawaited(
        _c
            .animateTo(1, duration: Motion.fast, curve: Motion.standard)
            .whenComplete(widget.onConfirmed),
      );
    } else {
      _passedThreshold = false;
      _springBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = widget.height;
    final track = widget.trackColor ?? scheme.surfaceContainerHighest;
    final fill = widget.fillColor ?? scheme.primary.withValues(alpha: 0.25);
    final thumb = widget.thumbColor ?? scheme.primary;
    final onThumb = widget.thumbIconColor ?? scheme.onPrimary;
    final busy =
        widget.status == ActionStatus.loading ||
        widget.status == ActionStatus.success;
    final d = Motion.of(context, Motion.base);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled && !_committed
          ? () {
              // Assistive tech cannot drag; let it activate directly.
              _committed = true;
              _c.value = 1;
              widget.onConfirmed();
            }
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final full = box.maxWidth;
          return Center(
            child: AnimatedContainer(
              duration: d,
              curve: Motion.standard,
              width: busy ? h : full,
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.status == ActionStatus.success ? thumb : track,
                borderRadius: BorderRadius.circular(h / 2),
              ),
              child: busy
                  ? Center(
                      child: AnimatedSwitcher(
                        duration: d,
                        child: widget.status == ActionStatus.success
                            ? Icon(
                                Icons.check_rounded,
                                key: const ValueKey('ok'),
                                color: onThumb,
                              )
                            : SizedBox.square(
                                key: const ValueKey('spin'),
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: thumb,
                                ),
                              ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, inner) {
                        const pad = 5.0;
                        final size = h - pad * 2;
                        final travel = inner.maxWidth - size - pad * 2;
                        if (travel <= 0) return const SizedBox.shrink();
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (x) => _update(x, travel),
                          onHorizontalDragEnd: (x) => _end(x, travel),
                          child: AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) {
                              final t = _c.value;
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // fill trailing behind the thumb
                                  Container(
                                    width: pad * 2 + size + travel * t,
                                    decoration: BoxDecoration(
                                      color: fill,
                                      borderRadius: BorderRadius.circular(
                                        h / 2,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Opacity(
                                      opacity:
                                          (1 - t * 2).clamp(0.0, 1.0) *
                                          (widget.enabled ? 1 : 0.4),
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: size * 0.6,
                                        ),
                                        child: Text(
                                          widget.label,
                                          maxLines: 1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: scheme.onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: pad + travel * t,
                                    child: Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: widget.enabled
                                            ? thumb
                                            : scheme.onSurface.withValues(
                                                alpha: 0.2,
                                              ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: thumb.withValues(
                                              alpha: 0.35 * t,
                                            ),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        t >= widget.threshold
                                            ? Icons.check_rounded
                                            : widget.icon,
                                        color: onThumb,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
