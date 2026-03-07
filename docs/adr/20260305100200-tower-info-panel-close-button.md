---
status: accepted
date: 2026-03-05
decision-makers: [Dev team]
consulted: [Game designer]
informed: [QA]
---

# Add close button and mobile bottom-docking to TowerInfoPanel

## Context and Problem Statement

On mobile devices, the TowerInfoPanel (which shows tower stats, upgrade/sell/fuse buttons) has no way to be dismissed. On desktop, clicking empty space deselects the tower, but on touch screens there is no equivalent gesture -- tapping empty grid space is ambiguous (could mean "place tower" or "deselect"). Players get stuck with the panel covering the playfield.

## Decision Drivers

* Mobile players need an explicit, discoverable way to close the panel
* Touch targets must meet minimum 64x64 size for reliable tapping
* The close button must not compete visually with action buttons (Upgrade, Sell, Fuse)
* Panel positioning on mobile should maximize playfield visibility

## Considered Options

* **Close button in header row** -- an "X" button alongside the tower name
* **Tap-away-to-dismiss** -- tap any non-UI area to deselect the tower
* **Swipe gesture** -- swipe down to dismiss the panel

## Decision Outcome

Chosen option: "Close button in header row", because it is the most discoverable and reliable approach. It works identically on all platforms, requires no gesture detection, and has no ambiguity with other tap/click actions on the grid.

The header row replaces the standalone NameLabel with an HBoxContainer containing the name label (left, expanding) and a close button (right, fixed size). The close button calls `UIManager.deselect_tower()`, which already handles hiding the panel and clearing selection state.

Additionally, on mobile the panel is docked at the bottom of the screen (above the build menu area) instead of floating beside the tower. This avoids the panel obscuring nearby towers and provides a consistent, predictable location.

### Consequences

* Good, because mobile players have an obvious way to dismiss the panel
* Good, because the close button reuses existing `UIManager.deselect_tower()` logic
* Good, because bottom-docking on mobile frees up playfield visibility
* Neutral, because desktop players gain a redundant close button (they can already click away)
* Bad, because the header row adds slight visual complexity to the panel layout

### Confirmation

Validated by GdUnit4 unit tests covering: close button existence, press behavior, mobile sizing, mobile bottom-dock positioning, and visual distinction from action buttons.

## Pros and Cons of the Options

### Close button in header row

* Good, because universally discoverable -- "X" button is a well-known UI pattern
* Good, because no platform-specific input handling needed
* Good, because sizing can be tuned per platform (64x64 mobile, 28x28 desktop)
* Neutral, because adds one node to the scene tree

### Tap-away-to-dismiss

* Good, because no additional UI chrome needed
* Bad, because ambiguous with tower placement -- tapping grid could mean "build here" or "deselect"
* Bad, because requires an invisible input layer or global input handler
* Bad, because not discoverable -- new players won't know to tap away

### Swipe gesture

* Good, because feels native on mobile
* Bad, because not discoverable without a tutorial
* Bad, because swipe direction could conflict with camera pan
* Bad, because desktop has no natural swipe equivalent

## More Information

The close button uses a subtle neutral StyleBoxFlat (dark gray background, light border) to visually distinguish it from the element-colored action buttons (Upgrade, Sell, Fuse). On mobile, minimum touch target is 64x64 (UIManager.MOBILE_BUTTON_MIN). On desktop, the button is 28x28.
