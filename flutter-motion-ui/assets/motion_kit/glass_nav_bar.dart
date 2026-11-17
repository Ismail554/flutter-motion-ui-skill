import 'dart:ui';

import 'package:flutter/material.dart';

import 'motion.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });
  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// Floating "liquid glass" navigation pill.
///
/// The glass look is four layers, back to front:
///  1. soft drop shadow (outside the clip),
///  2. backdrop blur + saturation boost of whatever scrolls underneath,
///  3. translucent tint with a top-left → bottom-right sheen,
///  4. 1px gradient rim that reads as a light edge.
/// The active indicator is a brighter lens that slides between items.
///
/// Usage — content must scroll *under* the bar or there is nothing to blur:
/// ```dart
/// Scaffold(
///   extendBody: true,
///   body: IndexedStack(index: tab, children: pages),
///   bottomNavigationBar: GlassNavBar(
///     items: items, currentIndex: tab, onTap: (i) => setState(() => tab = i),
///   ),
/// )
/// ```
/// Give scrollables `padding: EdgeInsets.only(bottom: GlassNavBar.reservedHeight(context))`.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 64,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 12),
    this.blur = 24,
    this.showSelectedLabel = false,
    this.tint,
    this.accent,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;
  final EdgeInsets margin;
  final double blur;

  /// When true the active item expands to show its label next to the icon.
  final bool showSelectedLabel;

  /// Glass body colour. Defaults to surface; opacity is applied internally.
  final Color? tint;

  /// Active icon / label colour. Defaults to `colorScheme.primary`.
  final Color? accent;

  /// Space a scroll view should leave at the bottom so the last item clears
  /// the bar.
  static double reservedHeight(BuildContext context, {double height = 64}) =>
      height + 12 + 16 + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final body = tint ?? scheme.surface;
    final active = accent ?? scheme.primary;
    final idle = scheme.onSurface.withValues(alpha: 0.55);
    final radius = BorderRadius.circular(height / 2);
    final d = Motion.of(context, Motion.slow);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                inner: const ColorFilter.matrix(_saturate),
              ),
              child: CustomPaint(
                foregroundPainter: _RimPainter(height / 2, dark),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        body.withValues(alpha: dark ? 0.50 : 0.72),
                        body.withValues(alpha: dark ? 0.30 : 0.52),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final n = items.length;
                      final w = c.maxWidth / n;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: d,
                            curve: Motion.overshoot,
                            left: w * currentIndex,
                            top: 0,
                            bottom: 0,
                            width: w,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                color: (dark ? Colors.white : active)
                                    .withValues(alpha: dark ? 0.14 : 0.12),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: dark ? 0.10 : 0.55,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < n; i++)
                                Expanded(
                                  child: _Item(
                                    item: items[i],
                                    selected: i == currentIndex,
                                    showLabel: showSelectedLabel,
                                    color: i == currentIndex ? active : idle,
                                    onTap: () {
                                      if (i != currentIndex) {
                                        Haptics.selection();
                                      }
                                      onTap(i);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 1.35× saturation so colours bleeding through the blur stay lively.
const List<double> _saturate = [
  1.276, -0.250, -0.025, 0, 0, //
  -0.074, 1.100, -0.025, 0, 0, //
  -0.074, -0.250, 1.325, 0, 0, //
  0, 0, 0, 1, 0,
];

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.color,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final bool showLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.base);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // excludeSemantics drops the GestureDetector's tap action along
      // with its label, so screen readers need it declared here.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            duration: d,
            tween: ColorTween(end: color),
            builder: (context, c, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: d,
                  curve: Motion.overshoot,
                  scale: selected ? 1.08 : 1,
                  child: Icon(
                    selected ? (item.activeIcon ?? item.icon) : item.icon,
                    color: c,
                    size: 24,
                  ),
                ),
                if (showLabel)
                  AnimatedSize(
                    duration: d,
                    curve: Motion.standard,
                    alignment: Alignment.centerLeft,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: c),
                            ),
                          )
                        : const SizedBox(height: 24),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, this.dark);
  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.28 : 0.85),
          Colors.white.withValues(alpha: dark ? 0.04 : 0.20),
          Colors.white.withValues(alpha: dark ? 0.14 : 0.55),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.dark != dark;
}
