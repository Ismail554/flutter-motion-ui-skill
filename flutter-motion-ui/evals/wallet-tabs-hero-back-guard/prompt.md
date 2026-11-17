---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Flutter wallet app, dark theme, no backend (fake data), use riverpod. Floating glass bottom bar with 3 tabs: Home, Cards, Activity. Each tab must keep its scroll position and its own navigation stack when I switch tabs. Home: balance that animates when it changes, a horizontally swipeable card carousel, tapping a card opens card details with a hero. A 'Send' button opens a transfer flow: enter amount on a keypad, slide to confirm, processing about 2s, then success. Amounts over 500 fail with 'insufficient funds' and let me fix the amount without retyping everything. While it's processing, back (gesture or button) must not leave the screen. After a successful transfer the balance and the Activity list both update. On Android, back on Cards or Activity should go to Home first instead of closing the app.
