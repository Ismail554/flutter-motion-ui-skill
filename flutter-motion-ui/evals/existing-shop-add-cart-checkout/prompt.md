---
tags: [skill-creator]
max_turns: 80
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

this is my shop app (in the app folder, uses provider). I need you to add a cart and checkout to it. 'Add to cart' on the product page should actually work with some nice feedback, there should be a floating glass bottom bar with Shop and Cart tabs and a badge with the item count, cart page with quantity steppers and a total, then checkout: slide to pay -> processing (fake 2s) -> success screen. make any order over $300 fail with 'card declined' so I can see the error, and let me go back and fix the cart. also the list -> product page transition feels cheap, make the product image fly across. dont break what already works and keep my state management, I dont want to migrate anything.
