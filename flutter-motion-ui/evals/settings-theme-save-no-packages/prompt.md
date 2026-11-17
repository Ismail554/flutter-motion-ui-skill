---
tags: [skill-creator]
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

I have a plain Flutter app with no extra packages and want to keep it that way. Build me a profile settings screen: profile card at top, light/dark theme picker that switches the whole app smoothly, 3 toggles (push notifications, face id, haptics), and a 'Save changes' button that only appears when something changed, shows a loading state when pressed (fake 1.5s save) and then a saved confirmation. Should also work on small phones.
