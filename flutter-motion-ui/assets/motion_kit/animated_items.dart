import 'package:flutter/material.dart';

import 'motion.dart';

/// A list that animates rows in and out *by itself* whenever the [items] you
/// pass change. State stays a plain immutable list — no imperative
/// `insertItem` / `removeItem` calls leaking into controllers.
///
/// ```dart
/// AnimatedItems<Transfer>(
///   items: ref.watch(transfersProvider),
///   idOf: (t) => t.id,
///   itemBuilder: (context, t) => TransferTile(t),
/// )
/// ```
/// Added ids grow + fade in, removed ids shrink + fade out, surviving ids are
/// rebuilt in place with fresh data. A pure reorder falls back to a rebuild.
class AnimatedItems<T> extends StatefulWidget {
  const AnimatedItems({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.animateInitial = false,
  });

  final List<T> items;
  final Object Function(T item) idOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  /// Also animate the rows present on first build (staggered).
  final bool animateInitial;

  @override
  State<AnimatedItems<T>> createState() => _AnimatedItemsState<T>();
}

class _AnimatedItemsState<T> extends State<AnimatedItems<T>> {
  var _listKey = GlobalKey<AnimatedListState>();
  late List<T> _items = List.of(widget.items);

  @override
  void didUpdateWidget(AnimatedItems<T> old) {
    super.didUpdateWidget(old);
    final next = widget.items;
    final id = widget.idOf;
    final nextIds = {for (final x in next) id(x)};
    final list = _listKey.currentState;
    final d = Motion.of(context, Motion.base);

    // 1. removals, back to front so indices stay valid
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!nextIds.contains(id(_items[i]))) {
        final removed = _items.removeAt(i);
        list?.removeItem(
          i,
          (context, a) => _row(context, removed, a),
          duration: d,
        );
      }
    }

    // 2. insertions + in-place refresh
    final currentIds = {for (final x in _items) id(x)};
    var reordered = false;
    for (var i = 0; i < next.length; i++) {
      if (i < _items.length && id(_items[i]) == id(next[i])) {
        _items[i] = next[i];
      } else if (!currentIds.contains(id(next[i]))) {
        _items.insert(i, next[i]);
        list?.insertItem(i, duration: d);
      } else {
        reordered = true;
        break;
      }
    }

    // 3. order changed: rebuild the list from scratch (no animation)
    if (reordered || _items.length != next.length) {
      _items = List.of(next);
      _listKey = GlobalKey<AnimatedListState>();
    }
  }

  Widget _row(BuildContext context, T item, Animation<double> a) {
    // drive() creates no listener that would need disposing.
    final curved = a.drive(CurveTween(curve: Motion.enter));
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: widget.itemBuilder(context, item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      initialItemCount: _items.length,
      itemBuilder: (context, index, a) => KeyedSubtree(
        key: ValueKey(widget.idOf(_items[index])),
        child: _row(context, _items[index], a),
      ),
    );
  }
}
