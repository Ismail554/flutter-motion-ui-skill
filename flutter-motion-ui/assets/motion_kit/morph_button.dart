import 'package:flutter/material.dart';

import 'motion.dart';

enum ActionStatus { idle, loading, success, failure }

/// Scales its child down slightly while pressed. Wrap any tappable surface so
/// every touch in the app answers the finger the same way.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? Motion.instant : Motion.fast,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Primary button whose shape *is* the request state:
/// full-width label → collapses to a circle with a spinner → expands into a
/// success (or failure) bar → returns to idle.
///
/// Controlled: pass [status] from your state layer.
/// ```dart
/// MorphButton(
///   label: 'Save changes',
///   successLabel: 'Saved',
///   status: ref.watch(settingsProvider).saveStatus,
///   onPressed: dirty ? () => ref.read(settingsProvider.notifier).save() : null,
/// )
/// ```
/// `onPressed: null` renders the disabled look and animates in when it
/// becomes available (e.g. form turns valid).
class MorphButton extends StatelessWidget {
  const MorphButton({
    super.key,
    required this.label,
    required this.status,
    required this.onPressed,
    this.successLabel,
    this.failureLabel,
    this.icon,
    this.height = 56,
    this.color,
    this.foreground,
    this.successColor = const Color(0xFF1FA463),
    this.borderRadius,
  });

  final String label;
  final String? successLabel;
  final String? failureLabel;
  final IconData? icon;
  final ActionStatus status;
  final VoidCallback? onPressed;
  final double height;
  final Color? color;
  final Color? foreground;
  final Color successColor;

  /// Idle corner radius. Defaults to a pill.
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null || status != ActionStatus.idle;
    final bg = switch (status) {
      ActionStatus.success => successColor,
      ActionStatus.failure => scheme.error,
      _ =>
        enabled
            ? (color ?? scheme.primary)
            : scheme.onSurface.withValues(alpha: 0.12),
    };
    final fg = switch (status) {
      ActionStatus.success => Colors.white,
      ActionStatus.failure => scheme.onError,
      _ =>
        enabled
            ? (foreground ?? scheme.onPrimary)
            : scheme.onSurface.withValues(alpha: 0.38),
    };
    final loading = status == ActionStatus.loading;
    final d = Motion.of(context, Motion.base);

    final Widget content = switch (status) {
      ActionStatus.loading => SizedBox.square(
        key: const ValueKey('loading'),
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
      ),
      ActionStatus.success => _Label(
        key: const ValueKey('success'),
        icon: Icons.check_circle_rounded,
        text: successLabel ?? 'Done',
        color: fg,
      ),
      ActionStatus.failure => _Label(
        key: const ValueKey('failure'),
        icon: Icons.error_outline_rounded,
        text: failureLabel ?? 'Try again',
        color: fg,
      ),
      ActionStatus.idle => _Label(
        key: const ValueKey('idle'),
        icon: icon,
        text: label,
        color: fg,
      ),
    };

    return Semantics(
      button: true,
      enabled: enabled && !loading,
      label: label,
      child: LayoutBuilder(
        builder: (context, c) {
          final full = c.hasBoundedWidth ? c.maxWidth : 220.0;
          return Center(
            child: Pressable(
              onTap: status == ActionStatus.idle ? onPressed : null,
              child: AnimatedContainer(
                duration: d,
                curve: Motion.standard,
                width: loading ? height : full,
                height: height,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(
                    loading ? height / 2 : (borderRadius ?? height / 2),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: d,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({super.key, required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // FittedBox keeps the row from overflowing while the width is morphing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-contained version for places with no state layer (prototypes, one-off
/// dialogs): runs [action], shows the result, then resets.
class AsyncMorphButton extends StatefulWidget {
  const AsyncMorphButton({
    super.key,
    required this.label,
    required this.action,
    this.enabled = true,
    this.successLabel,
    this.onSuccess,
    this.icon,
  });

  final String label;
  final String? successLabel;
  final IconData? icon;
  final bool enabled;

  /// Return normally for success; throw for failure.
  final Future<void> Function() action;

  /// Called after the success state has been shown for [Motion.successHold].
  final VoidCallback? onSuccess;

  @override
  State<AsyncMorphButton> createState() => _AsyncMorphButtonState();
}

class _AsyncMorphButtonState extends State<AsyncMorphButton> {
  ActionStatus _status = ActionStatus.idle;

  Future<void> _run() async {
    setState(() => _status = ActionStatus.loading);
    var ok = true;
    try {
      await widget.action();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Haptics.success();
    } else {
      Haptics.error();
    }
    setState(() => _status = ok ? ActionStatus.success : ActionStatus.failure);
    await Future<void>.delayed(Motion.successHold);
    if (!mounted) return;
    if (ok) widget.onSuccess?.call();
    if (mounted) setState(() => _status = ActionStatus.idle);
  }

  @override
  Widget build(BuildContext context) => MorphButton(
    label: widget.label,
    successLabel: widget.successLabel,
    icon: widget.icon,
    status: _status,
    onPressed: widget.enabled ? _run : null,
  );
}
