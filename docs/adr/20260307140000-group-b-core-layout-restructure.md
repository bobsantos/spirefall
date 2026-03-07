---
status: "proposed"
date: 2026-03-07
decision-makers: Bob Santos
consulted: Mobile developer agent, Godot developer agent
informed: ""
---

# Replace persistent TopBar + BuildMenu with contextual/collapsible layout

## Context and Problem Statement

Spirefall's mobile UI currently uses a persistent TopBar (72px, later reduced to 48px) and a persistent BuildMenu that together consume roughly 33% of the viewport. On 270dp worst-case landscape phones, this leaves only 67% of the screen for the game board, making it difficult to see enemy paths and plan tower placement during combat. The core layout needs to be restructured so that UI elements appear only when the player needs them, maximizing board visibility during the combat phase while keeping build and tower info workflows fully accessible.

## Decision Drivers

* 270dp worst-case landscape phones need 95%+ board visibility during active combat
* Touch targets must be 128px minimum (36dp) per v3 size constants
* Build sheet and TowerInfoPanel must be mutually exclusive at the bottom of the screen -- only one can be visible at a time
* Desktop behavior must remain completely unchanged; all layout changes are gated behind mobile detection
* Web compatibility constrains widget choices (no native Popup nodes)

## Considered Options

* Option 1: Contextual/collapsible UI -- hide UI when not needed, slide-in sheets from bottom
* Option 2: Persistent scaled UI -- keep same layout but scale everything up for touch targets

## Decision Outcome

Chosen option: "Option 1: Contextual/collapsible UI", because it is the only approach that achieves 95%+ board visibility during combat while still meeting the 128px minimum touch target requirement. The persistent layout inherently caps board visibility at 67%, which is insufficient on small screens.

### Consequences

* Good, because board visibility reaches 95%+ during combat when sheets are dismissed
* Good, because build and tower info workflows remain fully accessible via explicit user actions (FAB tap, tower selection)
* Good, because mutual exclusivity of bottom sheets prevents overlapping panels and simplifies state management
* Good, because desktop layout is entirely unaffected
* Bad, because build workflow gains one extra tap (FAB) compared to the always-visible menu
* Bad, because adds animation and state machine complexity to the UI layer

### Confirmation

Each component introduced by this ADR will have dedicated unit tests:
- `test_status_bar.gd` validates the 48px minimal status bar and overflow menu toggle
- `test_build_fab.gd` validates FAB positioning, tap to toggle build sheet, and mutual exclusivity with TowerInfoPanel
- `test_build_bottom_sheet.gd` validates slide_in/slide_out tween behavior and content layout
- `test_tower_info_panel_states.gd` validates the DISMISSED/COLLAPSED/EXPANDED state machine and swipe gestures
- Integration tests confirm that opening one bottom sheet dismisses the other

## Pros and Cons of the Options

### Option 1: Contextual/collapsible UI

Hide all non-essential UI during combat. A minimal 48px status bar shows gold, lives, and wave count. An overflow menu (three-dot button) reveals secondary info on demand. A floating action button (FAB) toggles a build bottom sheet that slides up from the screen edge. Tower selection opens a TowerInfoPanel bottom sheet with collapsed and expanded states. Only one bottom sheet is visible at a time.

* Good, because 95%+ board visibility during combat
* Good, because bottom sheets are a familiar mobile pattern players already understand
* Good, because swipe-to-expand on TowerInfoPanel allows progressive disclosure of tower stats
* Good, because PanelContainer-based overflow menu avoids Godot Popup web compatibility issues
* Neutral, because requires a FAB on screen at all times (small footprint, 128px)
* Bad, because build workflow requires one extra tap to open the sheet
* Bad, because swipe gesture detection in _gui_input must be carefully tuned to avoid conflicting with camera panning in _unhandled_input

### Option 2: Persistent scaled UI

Keep the existing TopBar + BuildMenu layout but scale all elements up to meet 128px touch targets. This was the v2 approach.

* Good, because no structural UI changes needed
* Good, because simpler implementation with no animations or state machines
* Bad, because board visibility is capped at ~67% -- fails the 95% requirement on 270dp devices
* Bad, because the scaled BuildMenu occupies ~300px of a 960px viewport, dominating the bottom of the screen
* Bad, because already rejected during v2 review for insufficient board visibility

## More Information

### Key technical decisions

**OverflowMenu uses PanelContainer, not Popup.** Godot's Popup node has known issues with HTML5 export (focus and z-order problems). The overflow menu is implemented as a PanelContainer whose visibility is toggled. Click-outside-dismiss is handled by an invisible full-screen ColorRect layered behind the menu that captures input and closes it.

**BuildMenu slide animation.** The build bottom sheet slides in/out via a Tween on `position.y`. The BuildFAB manages the open/close toggle. When the sheet opens, the FAB icon changes to indicate "close". The tween duration targets 200ms for responsive feel.

**TowerInfoPanel state machine.** The panel implements a `PanelState` enum with three states: `DISMISSED` (off-screen), `COLLAPSED` (shows tower name, element, and key stats in ~128px), and `EXPANDED` (full stats, upgrade/sell buttons, fills ~50% of viewport). Transitions between COLLAPSED and EXPANDED are driven by swipe gestures or a drag handle tap.

**Swipe detection in _gui_input.** Swipe gestures are detected on the PanelContainer via `_gui_input`, which fires before `_unhandled_input`. This ensures swipe-to-expand/collapse is consumed by the panel and does not propagate to the camera pan handler. A minimum swipe distance threshold (64px) and velocity check prevent accidental triggers.

**Mutual exclusivity of bottom sheets.** The build sheet and TowerInfoPanel coordinate through signals. When the BuildFAB opens the build sheet, it emits a signal that causes TowerInfoPanel to dismiss. When the player taps a tower and TowerInfoPanel opens, it emits a signal that causes the build sheet to slide out. This is managed at the UIManager level to keep the sheets decoupled from each other.

**Keyboard hints stripped on mobile.** All keyboard shortcut labels (e.g., "E to sell", "Q/W/E upgrade") are hidden when `UIManager.is_mobile()` returns true. Touch-equivalent actions use explicit buttons instead.
