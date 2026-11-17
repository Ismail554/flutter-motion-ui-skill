# State management for animated UI

## Contents
1. Which library
2. Three kinds of state and where each lives
3. Flow state as a sealed class
4. Shared data: one owner
5. Async: loading, failure, optimistic updates, undo
6. Live data (ETA, position, status)
7. Side effects
8. Forms and derived state
9. The same patterns in Bloc and ChangeNotifier
10. Rebuild hygiene
11. Smells

---

## 1. Which library

Use what the project uses. The patterns below are library-independent; only the syntax differs. For a new project default to **Riverpod 3 (`Notifier` / `AsyncNotifier`)**: no `BuildContext` needed to read state, providers auto-dispose with the screen, and one provider can depend on another, which is exactly what "flow writes to shared list" needs. `assets/examples/send_money_flow.dart` is the full worked example (verified against flutter_riverpod 3.5).

`setState` is still right for a single widget's ephemeral state (current tab, is-expanded, a text field's focus). Reach for a controller when state is shared, async, or has more than two modes.

## 2. Three kinds of state

| Kind | Examples | Lives in |
|---|---|---|
| **Animation state** | controller value, is-pressed, drag offset, caret blink | the widget (`State`, implicit animations) |
| **Screen/flow state** | editing / submitting / done, selected chip, current step, form values | a controller scoped to the screen (auto-dispose) |
| **App/shared state** | cart, cards, transfers, active order, session, theme mode | a long-lived provider/bloc/repository |

Keeping these apart is what lets animations be interrupted safely: the business layer flips from `Submitting` to `Done` whenever it likes, and widgets tween from wherever they currently are.

## 3. Flow state as a sealed class

```dart
sealed class OtpState { const OtpState(); }
class OtpEditing   extends OtpState { const OtpEditing({this.code = '', this.errorCount = 0, this.error});
  final String code; final int errorCount; final String? error; }
class OtpVerifying extends OtpState { const OtpVerifying(this.code); final String code; }
class OtpVerified  extends OtpState { const OtpVerified(); }
```

```dart
StateSwitcher(
  stateKey: state.runtimeType,
  child: switch (state) {
    OtpEditing(:final code, :final errorCount, :final error) => OtpForm(code, errorCount, error),
    OtpVerifying() => const VerifyingView(),
    OtpVerified()  => const VerifiedView(),
  },
)
```

Why this instead of `isLoading`, `hasError`, `isSuccess` booleans: three booleans describe eight combinations, five of them nonsense, and animations expose nonsense states visibly (spinner over a success tick). A sealed class makes the compiler insist every state is drawn, and gives `AnimatedSwitcher` a natural key.

Guidelines:

- States that share a layout and only differ in a control's status (editing vs submitting on the same form) can be *one visual state* — key the switcher on the layout, and feed the control an `ActionStatus`. See how the example keys on `state is SendDone`.
- Carry data in the state that needs it (`Done(transfer)`), so the success view never reads nullable fields.
- Failure is usually not its own screen: return to `Editing` with the input preserved and an `error`, bump an `errorCount` to trigger `Shake`.
- For plain fetches, `AsyncValue<T>` (Riverpod) or a generic `Loading/Data/Error` is enough — do not invent a class per screen.

## 4. Shared data: one owner

The wallet reference: send money, come back, the new transfer is already at the top of the list with updated balance. The delivery reference: the mini order bar on Home and the tracking screen always agree on status and ETA.

That happens when both screens watch the same source:

```dart
final transfersProvider = NotifierProvider<TransfersNotifier, List<Transfer>>(TransfersNotifier.new);

// flow controller, on success:
ref.read(transfersProvider.notifier).add(transfer);
state = SendDone(transfer);
```

- Lists are immutable; mutate by replacing (`state = [t, ...state]`). `AnimatedItems` diffs old vs new by id and animates the difference — controllers never call `insertItem`.
- Derive, do not duplicate: `final balanceProvider = Provider((ref) => ref.watch(transfersProvider).fold(...))`. A second stored copy will drift.
- Pass **ids** to detail screens and have them watch `itemProvider(id)`; passing the object snapshots it and the detail goes stale.
- Every model used in lists needs a stable `id` and value equality (`==`/`hashCode`, `freezed`, or `equatable`) — it is what keys, Heroes and diffing rely on.

## 5. Async patterns

**Standard submit**

```dart
Future<void> submit() async {
  final s = state; if (s is! Editing || !s.valid) return;   // guard re-entry
  state = Submitting(s.form);
  try {
    final result = await repo.send(s.form);
    if (!ref.mounted) return;                                // screen may be gone
    shared.add(result);
    state = Done(result);
  } catch (e) {
    if (!ref.mounted) return;
    state = Editing(form: s.form, error: messageFor(e), errorCount: s.errorCount + 1);
  }
}
```

**Minimum visible duration.** A spinner that flashes for 80 ms looks like a glitch. Race the work against a short floor so the loading phase is readable: `await Future.wait([work, Future.delayed(const Duration(milliseconds: 500))])`. Likewise hold success for `Motion.successHold` before navigating.

**Optimistic update with rollback** (toggles, likes, quantity, delete):

```dart
Future<void> remove(String id) async {
  final before = state;
  state = [for (final c in state) if (c.id != id) c];        // UI animates now
  try { await repo.delete(id); }
  catch (_) { state = before; onError('Could not remove card'); }  // animates back
}
```

**Delete with undo**: remove optimistically, show a snackbar with Undo for ~4 s, call the API only when the snackbar closes without undo.

**Settings toggles + explicit save** (profile reference): keep `saved` and `draft` in state; `dirty = draft != saved` reveals the Save button (`AnimatedSize` + `Entrance`); Save drives a `MorphButton` through loading → "Saved" → hidden again.

**Debounce** search input in the controller (Timer / `ref.debounce` helper), not in the widget.

## 6. Live data

Tracking, ETA countdowns, device scanning, order status:

```dart
final activeOrderProvider = StreamProvider.autoDispose<Order>((ref) => ref.watch(orderRepo).watchActive());
```

- The stream is the truth; widgets `watch` it. Both the mini bar and the full screen subscribe to the same provider, so they cannot disagree.
- **Interpolate between ticks in the widget.** Position updates arrive in jumps; tween the marker from the previous to the new position over the tick interval (`TweenAnimationBuilder<Offset>` or progress along a path) so it glides. Same for progress bars; use `RollingText` for the ETA minutes.
- Status changes are state transitions: `StateSwitcher` the header text ("Preparing" → "On the way"), animate the step indicator, fire a haptic in a listener.
- Devices appearing during a scan: emit a growing list; `AnimatedItems` inserts rows one by one.
- Timers (resend-code countdown): a `Stream.periodic` mapped to remaining seconds in the controller, cancelled on dispose (`ref.onDispose`). Never a `Timer` inside `build`.
- Use `select` so a ticking ETA does not rebuild the whole screen: `ref.watch(activeOrderProvider.select((o) => o.value?.etaMinutes))`.

## 7. Side effects

Navigation, dialogs, snackbars, haptics and sounds happen **once per transition**, so they belong in a listener:

```dart
ref.listen(otpControllerProvider, (prev, next) {
  if (next is OtpVerified) { Haptics.success(); context.go('/home'); }
  if (next is OtpEditing && next.errorCount > (prev is OtpEditing ? prev.errorCount : 0)) Haptics.error();
});
```

Putting these in `build` runs them on every rebuild — the classic "navigated twice" bug.

## 8. Forms and derived state

- Field text lives in `TextEditingController`s owned by the widget; the controller receives values `onChanged` and exposes **derived** `canSubmit`, strength, and per-field errors.
- The primary button's enabled state is derived, and its colour change is animated (`MorphButton(onPressed: canSubmit ? submit : null)`), which is the "button lights up when the form is valid" moment in every auth reference.
- Validate on blur or submit, not on first keystroke; clear a field's error as soon as the user edits it.
- Password strength: a `double 0..1` + label derived in the controller, rendered with an animated segmented bar.

## 9. Bloc and ChangeNotifier equivalents

**Cubit**

```dart
class SendCubit extends Cubit<SendState> {
  SendCubit(this._repo, this._transfers) : super(const SendEditing());
  Future<void> submit(String to) async {
    final s = state; if (s is! SendEditing || !s.canSend) return;
    emit(SendSubmitting(s.amount));
    try { final t = await _repo.send(to, s.amount); if (isClosed) return; _transfers.add(t); emit(SendDone(t)); }
    catch (_) { if (!isClosed) emit(SendEditing(digits: s.digits, error: 'Could not send')); }
  }
}
// UI: BlocBuilder<SendCubit, SendState> + switch; BlocListener for side effects;
// BlocSelector / buildWhen for narrow rebuilds. Shared list = a higher-scoped cubit or a repository stream.
```

**ChangeNotifier / ValueNotifier** (no packages)

```dart
class SendModel extends ChangeNotifier {
  SendState _state = const SendEditing();
  SendState get state => _state;
  void _set(SendState s) { _state = s; notifyListeners(); }
}
// UI: ListenableBuilder(listenable: model, builder: ...) ; provide via InheritedNotifier or constructor.
```

Still use the sealed state — the discipline matters more than the library.

## 10. Rebuild hygiene

- Watch the narrowest thing: `select`, `BlocSelector`, split big screens into small `ConsumerWidget`s so a ticking value rebuilds one `Text`.
- `const` constructors everywhere they apply.
- Never create controllers, futures or streams inside `build`.
- A widget that animates continuously should not be the same widget that watches frequently-changing state — separate them so each rebuild is cheap.
- Keys: `ValueKey(item.id)` on list children and on `AnimatedSwitcher` children; never index-based keys for dynamic lists.

## 11. Smells

- `bool isLoading; bool isError; bool isSuccess;` → sealed class.
- `Navigator.pop(context, result)` followed by `setState(() => items.add(result))` → shared provider.
- `Future.delayed` in a widget to "wait for the animation" → listen to state, or use `AnimationStatus` / `.whenComplete`.
- `setState` in a scroll listener rebuilding the page → `ValueNotifier` + small builder, or slivers.
- A provider holding an `AnimationController` or `BuildContext` → move the controller into the widget, expose plain state.
- Same number formatted in three places → one formatter/extension.
- `mounted` unchecked after `await` → guard it.
