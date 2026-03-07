---
status: "accepted"
date: 2026-03-07
decision-makers: [Claude]
consulted: []
informed: []
---

# Auto-zoom camera and grid-snap hysteresis during tower placement on mobile

## Context and Problem Statement

On mobile devices at default zoom, Spirefall's 64px grid cells resolve to roughly 18dp on a budget 270dp-tall phone -- well below the 36dp touch target floor. Players frequently misplace towers because their finger occludes the target cell and neighboring cells are too small to distinguish. The current `_update_ghost()` implementation snaps the ghost tower to whichever cell is directly under the finger on every input event, which causes jitter when the finger rests near a cell border.

Desktop placement works well (mouse cursor is precise, cells are large on screen), so any solution must be mobile-only and leave desktop behavior unchanged.

## Decision Drivers

* Grid cells must be at least 27dp during placement to be reliably distinguishable under a fingertip (64px * 1.5x zoom = 96px = 27dp on worst-case phone)
* Ghost tower must not jitter when the player's finger rests near a cell border
* The zoom transition must feel intentional and smooth, not jarring
* Players who prefer manual pinch-zoom must not be locked out of camera control during placement
* Ghost sprite must appear at natural size regardless of zoom level so the player sees what will actually be placed
* Desktop behavior must remain completely unchanged -- no hysteresis, no auto-zoom, no scale adjustment

## Considered Options

* Option 1: Auto-zoom with grid-snap hysteresis in Game.gd
* Option 2: Dedicated PlacementController node with its own camera and overlay scene
* Option 3: Static zoom-in (no tween) with cell magnification tooltip

## Decision Outcome

Chosen option: "Option 1: Auto-zoom with grid-snap hysteresis in Game.gd", because it solves the problem with minimal new code in the existing placement flow, reuses the current `_zoom_camera()` infrastructure, and keeps all placement logic in a single file.

### Consequences

* Good, because grid cells reach ~96px (27dp) at 1.5x zoom, making them distinguishable under a fingertip
* Good, because hysteresis eliminates ghost jitter at cell borders without adding perceptible input lag
* Good, because the 0.3s ease-in-out tween provides a smooth, non-jarring transition
* Good, because pinch-zoom kills the tween and restores manual control, so players never feel locked in
* Good, because all changes are confined to `Game.gd` with no new scenes or nodes (aside from a lightweight overlay for cell highlighting)
* Bad, because `Game.gd` grows by roughly 40-60 lines of placement-zoom state management
* Bad, because the 0.15s hold delay before zoom-out on confirm adds a small perceptible pause

### Confirmation

Acceptance criteria validated by unit tests in `tests/unit/main/test_game_placement_zoom.gd`:

- Camera zoom reaches `min(current * 1.5, ZOOM_MAX)` within 0.3s of entering placement on mobile
- Ghost position only updates when finger moves >32px from the center of the currently snapped cell
- A dedicated overlay node draws a 3px cell border: green (#00CC66) pulsing for valid, red (#CC3333) steady for invalid
- Camera tweens back to `_pre_placement_zoom` after 0.15s hold delay on confirm or cancel
- Pinch-zoom during placement kills the auto-zoom tween
- Ghost sprite scale is 1.0x (not 1.5x) while auto-zoom is active
- On desktop (`is_mobile() == false`), none of the above behaviors activate

## Pros and Cons of the Options

### Option 1: Auto-zoom with grid-snap hysteresis in Game.gd

Extend existing `_on_build_requested()` and `_update_ghost()` methods. Add state variables for pre-placement zoom, snap position, and tween reference. Hysteresis threshold of 32px (half cell width). Cell highlight via lightweight `Node2D` overlay with `_draw()`.

* Good, because reuses existing `_zoom_camera()`, `_update_ghost()`, and pinch-zoom infrastructure
* Good, because no new scenes, autoloads, or node tree restructuring
* Good, because hysteresis threshold is a single constant, easy to tune
* Neutral, because adds ~5 state variables to Game.gd
* Bad, because Game.gd continues to grow as the central placement controller

### Option 2: Dedicated PlacementController node

Extract placement logic into a new scene with its own camera management.

* Good, because isolates placement complexity from Game.gd
* Bad, because dual-camera setups introduce rendering complexity and Z-order issues
* Bad, because signal wiring duplicates state already in Game.gd
* Bad, because over-engineered for a transient mode

### Option 3: Static zoom-in with cell magnification tooltip

Instantly set zoom to 1.5x. Show magnified preview tooltip offset from touch point.

* Good, because magnifier gives pixel-precise feedback
* Bad, because instant zoom is jarring
* Bad, because magnifier tooltip is non-standard in tower defense
* Bad, because real-time magnified sub-viewport is significantly more complex

## More Information

| Constant | Value | Location |
|---|---|---|
| `MOBILE_PLACEMENT_ZOOM` | 1.5 | `UIManager.gd:34` |
| `ZOOM_MAX` | Vector2(2.0, 2.0) | `Game.gd:27` |
| `CELL_SIZE` | 64 | `GridManager` |
| Hysteresis threshold | 32px (half cell) | New in `Game.gd` |
| Zoom tween duration | 0.3s ease-in-out | New in `Game.gd` |
| Restore hold delay | 0.15s | New in `Game.gd` |
| Valid cell color | #00CC66, alpha 0.5-0.8 pulsing | New overlay node |
| Invalid cell color | #CC3333, alpha 0.6 steady | New overlay node |
