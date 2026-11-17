---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

building a reading list app in flutter. one screen for now: list of saved articles loaded from a fake api (800ms delay). need: loading skeleton, empty state, error state with retry (make the very first load fail so I can see it, retry then works), pull to refresh, tap the heart to favourite - should feel instant but the fake api fails for any article whose title starts with 'T' so it has to roll back with some feedback, swipe to delete with an undo snackbar, and an 'add article' sheet with a title field that adds to the top of the list. items should animate in and out, nothing should jump around. needs to hold up with big system font sizes too. use whatever state management you think is right.
