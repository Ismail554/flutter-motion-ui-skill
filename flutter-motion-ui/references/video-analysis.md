# Reference recordings: what they do and how to rebuild it

22 recordings were analysed frame by frame (sampled every ~0.27 s). Timings are approximate. "Kit" = `assets/motion_kit`, other pointers are to the reference files in this folder.

Patterns that recur in almost all of them (and are therefore the house style):

1. **Staggered entrance** of 3–7 blocks, small upward travel + fade, sometimes blur.
2. **Primary button is disabled-grey until the state is valid**, then tints in.
3. **Commit → in-place loader → success tick → auto-advance**, all without leaving context.
4. **Bottom sheet for every confirm/choose/rate**, content staggered, scrim dims the page.
5. **Numbers never jump**: they roll or count.
6. **One accent colour per app** used only for the primary action, selection and progress.
7. **Large radii, generous spacing, one type family**, strong size contrast between headline number and labels.
8. **Data stays consistent across screens** after an action.

---

## Flows with shared state

### screen_transition_state_data — wallet transfer
Home (balance card, transactions, floating dark pill nav) → Transfers tab (dark header with recipients collapses on scroll) → Send money (dark, custom keypad; amount digits roll in; quick-category chips; "Slide to send" thumb dragged right, track collapses to dots loader) → success (tick, amount, receipt rows, Done) → back to Transfers where **the new transfer is now first in the list**.
Rebuild: `assets/examples/send_money_flow.dart` is this flow. `GlassNavBar(tint: black)`, `RollingText`, `SlideToConfirm`, `StateSwitcher`, `AnimatedItems`; collapsing header in `motion-system.md`.

### delivery_app_ui — food delivery with live order
Home scrolls under a green header that collapses (search hides, address stays). A **mini order card pinned above the tab bar** shows status + ETA and keeps updating ("Preparing" 17 → 16 → 15 min → "Rider picked up" → "On the way"). Tap it → tracking screen: map with route and moving rider, draggable sheet with segmented progress, courier row, timeline, order items. Back on Home the mini card reflects the same new status.
Rebuild: `components.md` §10–11, `state.md` §6 (single stream, `select`), container transform in `navigation-transitions.md` §4.

### CRUD_animation — payment cards
Card carousel; page accent (slide button, dots) recolours per card. Close badge on a card → "Remove card?" sheet previewing that card, Cancel/Remove → sheet closes, card tilts/fades away, next card slides in and the accent changes.
Rebuild: `components.md` §4, `showAppSheet`, optimistic removal in `state.md` §5.

### confirmation_bottomshet_dialog — delivered → rate
Live card flips from dark "6 min" to green "Enjoy" (colour lerp + text switch), timeline completes. Rate → sheet: avatar, stars fill with reactive emoji/label, tag chips, button enables; submit collapses to a spinner; sheet content replaced by "Thanks for the feedback!" then dismisses.
Rebuild: `components.md` §3 and §9, sheet mini-flow in `navigation-transitions.md` §5, `MorphButton`.

### ride_sharing_app_ui / ride_sharing_app_ui_2 — ride lifecycle
Car detail (image heroes into the booking screen header) → Request to book (summary scrolls) → payment-method sheet (radio rows, Pay button → spinner → "Payment Successful" inside the same sheet) → map "Finding driver" with radar sweep → "On the way" (car glides along route, ETA box 3 → 2 → 1 → NOW) → "Arrived" → "In transit" (15 → 1) → "Completed" with Rate button → rating screen (stars, question changes with score, tags, tip amounts change the button label to "Submit & tip $10", note sheet) → "Thank you!" ring draws into a tick.
Rebuild: Hero rules in `navigation-transitions.md` §3; phases as one sealed `RideState`; `components.md` §2, §3, §10; loader→check in `motion-system.md`.

### ride_share_finding_driver — dark ride app
Pickup/destination chosen from inline sheets; tier cards selectable; "Find a driver" enables when both set. Finding (pulsing avatar) → driver arriving sheet with countdown → chat button morphs into "Slide to start trip" → map follows the route with progress bar and minutes left → "Trip completed" sheet with fare and stars.
Rebuild: same as above; `SlideToConfirm` for start trip.

### map_tracking_smooth_ui — parcel tracking
Home → Orders tab (cards stagger/skeleton in) → tap card: screen blurs with "Searching your parcel…" illustration → tracking: stylised map, route, truck glides while ETA chip counts 14 → 1 min, bottom panel with courier and step dots → status flips to green "Delivered", all dots filled.
Rebuild: blur overlay in `motion-system.md`, marker on path in `components.md` §10.

### profile_section — settings
Tap Profile in the glass tab bar (active tab shows label) → Settings rises in with staggered sections. Theme cards Daylight/Midnight: **whole UI cross-fades to dark and back**. Toggles animate; changing any reveals "Save changes" → collapses to spinner → green "Saved" → returns.
Rebuild: `GlassNavBar(showSelectedLabel: true)`, theme lerp in `motion-system.md`, draft/saved in `state.md` §5, `MorphButton`.

## Auth and onboarding

### splash_auth_ui — retail app
Launch → logos morph on white → hero photo welcome → Create account (fields get a dark focus border; button dark when valid) → loading sheet → "Successful!" tick → dark welcome with staggered text → preference grid → home: full-bleed hero image, product rails, **translucent glass tab bar** over scrolling content.
Rebuild: splash sequence in `motion-system.md`, `fadeThrough`, `GlassNavBar`.

### classic_splash_auth_ui_tansition_animation — coffee
Wordmark fades up, thin progress line fills, cross-fade to step 1/3 form (staggered). Send Code tints in when valid → step indicator advances, OTP boxes → cup fills while "Brewing your welcome cup" → home staggers in.
Rebuild: splash + `StepProgress` + `OtpBoxes`; themed loader = a fill animation driven by one controller.

### classic_sign_up_flow — light, 3 steps
Phone → confirm sheet ("Do you want to continue?") → OTP with custom keypad and resend timer → "You're verified" sheet → password with strength bar and match tick → button spinner → "Welcome" tick with particles.
Rebuild: one route with internal steps (`navigation-transitions.md` §6), `state.md` §8.

### start_onborading_auth — dark shipping
Country list (select highlights row, Continue tints) → phone with keypad → "Sending your code" ring → 5-digit OTP → "Verifying" → tick → region choice → "Locating your region" dotted map with pin drop → summary card + Start shipping.
Rebuild: selectable rows `components.md` §2; each waiting state is a `StateSwitcher` child.

### otp_confirmation_ui — dark, playful
Phone field (yellow focus border, Continue turns yellow when valid) → screen blurs, coloured bouncing dots "Sending code…" → Confirmation with animated illustration → digits pop in → "Verifying…" → **wrong code: boxes turn red, shake, message, clear** → retry → lock icon morphs into green tick → "You're verified".
Rebuild: `OtpBoxes` + `Shake` with `errorCount`; blur overlay.

### foody_app — onboarding carousel
Splash (logo pops, background warms) → 3 full-bleed onboarding pages swiped horizontally with text parallax and page dots; button label becomes "Get Started" on the last → login → home with banner and cards loading in.
Rebuild: `PageView` + per-page parallax from `controller.page`; dots as `AnimatedContainer`.

## Single-screen showpieces

### flutter_ui — coffee shop
Vertical product pager with scale/parallax, title/price cross-fade → Hero into detail (size options change price) → add-to-cart suggests a pairing (second pager beside the cup) → cart with both images → Checkout → receipt card scales in.
Rebuild: `components.md` §5, Hero, `RollingText`.

### app_fresh_load — fitness
Splash ring draws with logo → home: every block staggers, **calorie ring and number count up**, weekly bars grow → scroll → workout card image heroes to the detail header, exercises stagger → Start Workout → sheet "Workout started!" → back.
Rebuild: `Entrance`, `CountUpText`, progress ring and bar chart in `motion-system.md`, Hero.

### alarm_app_ui
Clock, time and slider blur/fade in one after another. Slide to stop: thumb drags, warm glow fills the track, thumb becomes a tick → whole scene cross-blurs from black to a blue morning sky, sun rises, greeting fades in.
Rebuild: `Entrance(blur: 8)`, `SlideToConfirm`, gradient lerp + blur cross-fade in `motion-system.md`.

### scan_to_pay_number_changing
Scan button expands into a QR frame; scan line sweeps with a glow; frame turns green on detect; ring loader → tick; **amount digits scramble/roll to the final value**; Done resets by reversing.
Rebuild: scanner loop + `ColorTween`, `RollingText`/`CountUpText`.

### smooth_list_loading — device pairing
"Connect Device" → button becomes "Scanning…" with spinner; devices **appear one by one** with a count; tap one → others dim, row highlights "Connecting…", button "Pairing…" → screen blurs to a centred success card → returns with the row green/connected and the button now "Disconnect".
Rebuild: `AnimatedItems` fed by a stream, `MorphButton`, blur overlay; one sealed `PairingState`.

### time_date_picker_ui — booking
Field tap → sheet with calendar; selected day indicator moves; month arrows slide the grid; header chip mirrors the choice → "Next · Pick time" switches the sheet to wheel pickers (hour/minute/AM-PM) with a centred highlight → Confirm.
Rebuild: `components.md` §6.

### expense_tracker_app_ui
Tab switches between Time, Reports (bars grow), Contacts (coloured header, leaderboard), Wallet — each tab's content animates in on first show; floating rounded tab bar.
Rebuild: `GlassNavBar`, bar chart, `Entrance` per tab.
