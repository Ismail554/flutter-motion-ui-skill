// Reference implementation: a complete "state drives motion" flow.
//
//   Transfers list ──push──▶ Send money (keypad → slide → sending → success)
//        ▲                                                        │
//        └──────────── pop; new row animates into the list ◀──────┘
//
// What to copy from this file:
//  1. ONE provider owns the list (`transfersProvider`). The send screen never
//     hands a result back through Navigator.pop — it writes to the shared
//     state, and the list screen animates because its data changed.
//  2. The flow is a sealed class. The UI is a `switch` over it, so there is
//     no impossible combination like loading + error + success.
//  3. Widgets hold zero business state. They hold only animation state.
//
// Uses flutter_riverpod 3.x. The same shape maps 1:1 onto Bloc/Cubit
// (sealed state + emit) or ChangeNotifier — see references/state.md.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion_kit/motion_kit.dart';

// ── Domain ──────────────────────────────────────────────────────────────────

@immutable
class Transfer {
  const Transfer({required this.id, required this.name, required this.amount});
  final String id;
  final String name;
  final int amount;
}

// ── Shared state: the single source of truth for the list ───────────────────

class TransfersNotifier extends Notifier<List<Transfer>> {
  @override
  List<Transfer> build() => const [
    Transfer(id: 't1', name: 'Alex Morgan', amount: 299),
    Transfer(id: 't2', name: 'Priya Shah', amount: 64),
    Transfer(id: 't3', name: 'Sofia Reyes', amount: 38),
  ];

  void add(Transfer t) => state = [t, ...state];

  void remove(String id) => state = [
    for (final t in state)
      if (t.id != id) t,
  ];
}

final transfersProvider = NotifierProvider<TransfersNotifier, List<Transfer>>(
  TransfersNotifier.new,
);

// ── Flow state: every screen state is one named class ───────────────────────

sealed class SendState {
  const SendState();
}

class SendEditing extends SendState {
  const SendEditing({this.digits = '', this.error});
  final String digits;
  final String? error;
  int get amount => digits.isEmpty ? 0 : int.parse(digits);
  bool get canSend => amount > 0;
}

class SendSubmitting extends SendState {
  const SendSubmitting(this.amount);
  final int amount;
}

class SendDone extends SendState {
  const SendDone(this.transfer);
  final Transfer transfer;
}

class SendController extends Notifier<SendState> {
  @override
  SendState build() => const SendEditing();

  void digit(String d) {
    final s = state;
    if (s is! SendEditing || s.digits.length >= 6) return;
    if (s.digits.isEmpty && d == '0') return;
    state = SendEditing(digits: s.digits + d);
  }

  void backspace() {
    final s = state;
    if (s is! SendEditing || s.digits.isEmpty) return;
    state = SendEditing(digits: s.digits.substring(0, s.digits.length - 1));
  }

  Future<void> submit(String recipient) async {
    final s = state;
    if (s is! SendEditing || !s.canSend) return;
    state = SendSubmitting(s.amount);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1400)); // API
      if (!ref.mounted) return; // screen closed while the request was running
      final t = Transfer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: recipient,
        amount: s.amount,
      );
      ref.read(transfersProvider.notifier).add(t);
      state = SendDone(t);
    } catch (_) {
      if (!ref.mounted) return;
      // Back to editing with the input intact — never lose what was typed.
      state = SendEditing(
        digits: s.digits,
        error: 'Could not send. Try again.',
      );
    }
  }
}

final sendControllerProvider =
    NotifierProvider.autoDispose<SendController, SendState>(SendController.new);

// ── UI: list screen ─────────────────────────────────────────────────────────

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transfersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        actions: [
          IconButton(
            tooltip: 'Send',
            icon: const Icon(Icons.north_east_rounded),
            onPressed: () => unawaited(
              Navigator.of(context).push(
                AppRoute<void>(
                  page: const SendMoneyScreen(recipient: 'Alex Morgan'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedItems<Transfer>(
        items: transfers,
        idOf: (t) => t.id,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, t) => ListTile(
          leading: CircleAvatar(child: Text(t.name[0])),
          title: Text(t.name),
          trailing: Text('\$${t.amount}'),
          onLongPress: () => ref.read(transfersProvider.notifier).remove(t.id),
        ),
      ),
    );
  }
}

// ── UI: flow screen ─────────────────────────────────────────────────────────

class SendMoneyScreen extends ConsumerWidget {
  const SendMoneyScreen({super.key, required this.recipient});
  final String recipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendControllerProvider);
    final controller = ref.read(sendControllerProvider.notifier);

    // One-shot side effects (haptics, snackbars, navigation) live in a
    // listener, never inside build().
    ref.listen(sendControllerProvider, (prev, next) {
      if (next is SendDone) Haptics.success();
      if (next is SendEditing && next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: SafeArea(
        // Fills the screen when there is room, scrolls when there is not
        // (small phones, large text, landscape) instead of overflowing.
        child: LayoutBuilder(
          builder: (context, viewport) {
            final minHeight = viewport.maxHeight - 48;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              // Editing and Submitting share a layout (only the slider
              // changes), so they share a key; Done is a different screen.
              child: StateSwitcher(
                stateKey: state is SendDone,
                child: switch (state) {
                  SendDone(:final transfer) => _SuccessView(
                    transfer: transfer,
                    minHeight: minHeight,
                  ),
                  SendEditing() || SendSubmitting() => ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Text('To $recipient'),
                              const SizedBox(height: 12),
                              RollingText(
                                '\$${switch (state) {
                                  SendEditing(:final amount) => amount,
                                  SendSubmitting(:final amount) => amount,
                                  SendDone() => 0,
                                }}',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IgnorePointer(
                              ignoring: state is SendSubmitting,
                              child: AnimatedOpacity(
                                opacity: state is SendSubmitting ? 0.3 : 1,
                                duration: Motion.base,
                                child: _Keypad(
                                  onDigit: controller.digit,
                                  onBackspace: controller.backspace,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SlideToConfirm(
                              label: 'Slide to send',
                              enabled: state is SendEditing && state.canSend,
                              status: state is SendSubmitting
                                  ? ActionStatus.loading
                                  : ActionStatus.idle,
                              onConfirmed: () =>
                                  unawaited(controller.submit(recipient)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.transfer, required this.minHeight});
  final Transfer transfer;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox.shrink(),
          Column(
            children: [
              Entrance(
                scaleFrom: 0.6,
                offset: Offset.zero,
                curve: Motion.overshoot,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Entrance(
                index: 1,
                child: CountUpText(
                  value: transfer.amount.toDouble(),
                  from: 0,
                  format: (v) => '\$${v.round()}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Entrance(index: 2, child: Text('Sent to ${transfer.name}')),
            ],
          ),
          Entrance(
            index: 4,
            child: MorphButton(
              label: 'Done',
              status: ActionStatus.idle,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    return Column(
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final k in row)
                Expanded(
                  child: k.isEmpty
                      ? const SizedBox(height: 60)
                      : Semantics(
                          button: true,
                          label: k == '<' ? 'Delete' : k,
                          // excludeSemantics hides the child's tap
                          // action too, so restate it here.
                          onTap: () => k == '<' ? onBackspace() : onDigit(k),
                          excludeSemantics: true,
                          child: Pressable(
                            scale: 0.85,
                            onTap: () => k == '<' ? onBackspace() : onDigit(k),
                            child: SizedBox(
                              height: 60,
                              child: Center(
                                child: k == '<'
                                    ? const Icon(Icons.backspace_outlined)
                                    : Text(k, style: style),
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
