---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos, Claude Code]
consulted: []
informed: []
---

# Clickable Map Selection Cards

## Context and Problem Statement

On mobile devices, the MapSelect screen required users to tap a small "Select" button inside each map card to choose a map. This created a poor touch experience because the tap target was too small relative to the large card area surrounding it. Users expected to tap anywhere on the card to select a map, consistent with standard mobile UI patterns.

## Decision Drivers

* Mobile touch targets must be large enough for reliable finger input (minimum 48-56px height)
* The entire card area should be tappable, not just the small button
* Locked maps must remain non-interactive to prevent confusion
* Desktop mouse interaction must not regress (hover feedback, button clicks still work)
* Visual feedback (hover, pressed states) needed on cards for both desktop and mobile

## Considered Options

* Connect `gui_input` signal on each PanelContainer card
* Wrap each card in a Button node
* Use `_unhandled_input` with hit-testing

## Decision Outcome

Chosen option: "Connect `gui_input` signal on each PanelContainer card", because it requires no scene tree restructuring, handles both `InputEventMouseButton` (desktop) and `InputEventScreenTouch` (mobile) in a single handler, and allows lock-checking before acting on the input. The existing button inside each card continues to work for desktop users who prefer precise clicks.

### Consequences

* Good, because tapping anywhere on an unlocked card now selects that map
* Good, because locked cards silently ignore all input (checked via `_is_map_unlocked()`)
* Good, because cards get StyleBoxFlat visual feedback (gold border on hover, darkened bg on press)
* Good, because mobile card height and button height are increased via `apply_mobile_card_sizing()`
* Neutral, because the "Select" button inside each card remains functional (redundant with card tap, but provides a clear visual affordance)
* Bad, because each card needs a separate handler function to bind its map key (4 thin wrappers)

### Confirmation

Confirmed by 28 new unit tests in `tests/unit/main/test_map_select.gd` covering: gui_input connection on all 4 cards, mouse_filter = STOP, left-click selection, touch selection, locked card rejection (3 maps), right-click rejection, release rejection, card styles (normal/hover/pressed), mobile sizing, and idempotent setup.

## Pros and Cons of the Options

### Connect `gui_input` on PanelContainer

* Good, because no scene tree changes needed
* Good, because PanelContainer already exists as the card root
* Good, because `mouse_filter = MOUSE_FILTER_STOP` ensures the card intercepts input
* Neutral, because hover/pressed styles must be managed manually (mouse_entered/mouse_exited signals)
* Bad, because requires 4 handler wrappers (one per card) to bind the map key

### Wrap each card in a Button

* Good, because Button has built-in hover/pressed/focus states
* Bad, because requires restructuring the scene tree (PanelContainer inside Button or vice versa)
* Bad, because Button accessibility semantics may conflict with inner button

### Use `_unhandled_input` with hit-testing

* Good, because single handler for all cards
* Bad, because requires manual Rect2 hit-testing and breaks if layout changes
* Bad, because `_unhandled_input` runs after all gui_input handlers, causing ordering issues

## More Information

This follows the same pattern established in Task C1 (Clickable Mode Selection Cards) for the ModeSelect screen. Both use `gui_input` on PanelContainer cards with `_is_*_unlocked()` guards.
