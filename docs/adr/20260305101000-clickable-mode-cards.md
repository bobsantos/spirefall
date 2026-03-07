---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos, Claude Code]
consulted: []
informed: []
---

# Make mode selection cards fully clickable with mobile touch support

## Context and Problem Statement

Mode selection cards (Classic, Draft, Endless) on the ModeSelect screen required users to tap a small "Select" button inside the card. On mobile devices, this button was a poor touch target -- users expected to tap anywhere on the card to select a mode, matching standard mobile UI patterns.

## Decision Drivers

* Mobile touch targets must be large enough for reliable finger tapping (minimum 48dp)
* Desktop users expect hover/pressed visual feedback on interactive elements
* Locked modes must remain non-interactive regardless of where the user taps
* Existing button-based selection must continue working (no desktop regression)

## Considered Options

* Connect `gui_input` signal on PanelContainer cards
* Wrap each card in a Button node
* Use `_input` / `_unhandled_input` with hit-testing

## Decision Outcome

Chosen option: "Connect `gui_input` signal on PanelContainer cards", because it requires no scene restructuring, keeps PanelContainer styling intact, and handles both mouse and touch events in a single handler.

### Consequences

* Good, because tapping anywhere on a card now selects the mode -- much better mobile UX
* Good, because locked cards are checked via `_is_mode_unlocked()` in the handler, preventing selection
* Good, because existing Select buttons still work as before (no desktop regression)
* Good, because cards now have `StyleBoxFlat` panel overrides with rounded corners, giving visual feedback
* Neutral, because the Select buttons are now somewhat redundant on mobile, but kept as visual anchors

### Confirmation

Validated by 18 new unit tests in `tests/unit/main/test_mode_select.gd` (sections 9-11) covering:
- `mouse_filter = MOUSE_FILTER_STOP` on all cards
- Left-click and touch selection for unlocked modes
- Locked mode rejection for both click and touch
- Right-click and release-event rejection
- Card StyleBoxFlat panel overrides
- Mobile minimum sizing for cards (160px) and buttons (56px)

## Pros and Cons of the Options

### Connect `gui_input` signal on PanelContainer cards

* Good, because no scene tree restructuring needed
* Good, because PanelContainer naturally handles stylebox overrides for visual feedback
* Good, because `gui_input` receives both mouse and touch events
* Neutral, because requires `mouse_filter = MOUSE_FILTER_STOP` to be set explicitly

### Wrap each card in a Button node

* Good, because Button has built-in hover/pressed/disabled states
* Bad, because requires restructuring the scene tree (Button > PanelContainer)
* Bad, because Button focus styling may conflict with card styling

### Use `_input` / `_unhandled_input` with hit-testing

* Good, because centralizes input handling
* Bad, because requires manual rect hit-testing for each card
* Bad, because more error-prone and harder to maintain

## More Information

Mobile card sizing uses `UIManagerClass.MOBILE_CARD_MIN_HEIGHT` (160px) and 56px minimum button height, applied conditionally via `UIManager.is_mobile()`. The `_apply_mobile_card_sizing()` method uses `maxf()` to ensure it only increases sizes, never shrinks them.
