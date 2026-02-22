# Tower Fusion UX Improvements

**Goal:** Fix three usability gaps in the tower fusion and upgrade flow that leave players guessing: no fusion cost visibility, silent fusion failures, and inconvenient panel placement.

**Prerequisites:** Phase 2 gameplay systems are complete. TowerInfoPanel, TowerSystem, FusionRegistry, and the Game.gd fusion selection flow all exist and function correctly. The issues are purely UX -- the underlying mechanics work.

---

## Problem Summary

### 1. Fusion cost is invisible before attempting it

The TowerInfoPanel shows upgrade cost (`Upgrade: 80g`) and sell value, but the Fuse button shows only "Fuse..." or "Legendary Fuse..." with zero cost information. The player has no way to know how much gold a fusion will cost before clicking the button and selecting a partner. The cost lives in the result `TowerData.cost` field, which is only looked up inside `TowerSystem.fuse_towers()` / `fuse_legendary()` after partner selection.

**Current flow:** Player clicks Fuse -> selects partner -> `TowerSystem.fuse_towers()` loads result TowerData, checks `EconomyManager.can_afford(result.cost)` -> if too poor, returns `false` silently.

### 2. Zero feedback on fusion failure

When `TowerSystem.fuse_towers()` or `fuse_legendary()` returns `false` (e.g., insufficient gold), `Game._handle_fusion_click()` at line 351-362 simply clears highlights and sets `_fusing_tower = null`. Nothing is shown to the player. No error message, no sound, no visual indicator. The fusion just silently does not happen.

**Affected code paths in `TowerSystem.gd`:**
- `fuse_towers()` line 74: `if not EconomyManager.can_afford(fusion_cost): return false`
- `fuse_legendary()` line 100: `if not EconomyManager.can_afford(fusion_cost): return false`
- `fuse_towers()` line 65: `if not FusionRegistry.can_fuse(tower_a, tower_b): return false`
- `fuse_legendary()` line 93: `if not FusionRegistry.can_fuse_legendary(...): return false`

### 3. TowerInfoPanel is anchored to bottom-right corner

The panel uses `anchors_preset = 3` (bottom-right) in `TowerInfoPanel.tscn`, positioned at a fixed offset (`offset_left = -240, offset_top = -420`). This means the panel is always in the same screen corner regardless of where the selected tower is. On larger displays or when the tower is on the opposite side of the map, the player's eyes have to travel far between the tower and its info panel.

---

## Task Breakdown

### Task F1: Show Fusion Cost in TowerInfoPanel

**Priority:** P1 | **Effort:** Medium

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scripts/autoload/FusionRegistry.gd` (new helper method)

**New test file:**
- `tests/unit/ui/test_tower_info_panel_fusion_cost.gd`

**Implementation notes:**
- Add a `FusionCostLabel` (Label node) to `TowerInfoPanel.tscn`, placed between `SellValueLabel` and `TargetModeDropdown`.
- In `_update_fuse_button()`, when the fuse button is visible, also compute and display the fusion cost:
  - For dual fusions: look up `FusionRegistry.get_fusion_result(element_a, element_b)` for each possible partner element and show the cost. Since multiple partners of different elements may exist, show the cost for the cheapest/most-common result, or show "Fuse: 120-200g" as a range if costs differ.
  - For legendary fusions: similarly look up `FusionRegistry.get_legendary_result()` and display the cost.
  - Simplification: since all dual fusions of a given pair share one result TowerData, the cost is deterministic per element pair. If the selected tower has exactly one fusion partner element available on the map, show the exact cost. If multiple different-element partners exist, show the range.
- Add `FusionRegistry.get_fusion_cost(element_a: String, element_b: String) -> int` convenience method that loads the result TowerData and returns its `.cost`, or `-1` if no fusion exists. Same for `get_legendary_cost(tier2_elements: Array[String], third_element: String) -> int`.
- Color the cost label gold if affordable, red if not (same pattern as `_update_upgrade_cost_label()`).
- Hide the fusion cost label when the fuse button is hidden.

**Acceptance criteria:**
- [ ] When a fusion-eligible tower is selected, the panel shows "Fuse cost: Xg" below sell value
- [ ] If multiple fusion partners exist with different costs, a range "Fuse cost: X-Yg" is shown
- [ ] Cost text is gold-colored when affordable, red when not
- [ ] Fusion cost label is hidden when the tower is not fusion-eligible
- [ ] `FusionRegistry.get_fusion_cost()` returns correct cost for valid pairs and `-1` for invalid
- [ ] `FusionRegistry.get_legendary_cost()` returns correct cost for valid triples and `-1` for invalid

**TDD approach:**
1. Write unit tests for `FusionRegistry.get_fusion_cost()` and `get_legendary_cost()` first
2. Write unit tests for `TowerInfoPanel._update_fuse_button()` verifying the label text and color for affordable/unaffordable/hidden cases
3. Implement the methods and UI changes to make tests pass

---

### Task F2: Feedback on Fusion Failure

**Priority:** P1 | **Effort:** Medium

**Modified files:**
- `scripts/autoload/TowerSystem.gd` (new signal)
- `scripts/main/Game.gd` (connect signal, show feedback)
- `scripts/ui/TowerInfoPanel.gd` (optional: inline error display)

**New files:**
- `scripts/ui/FusionErrorPopup.gd` (lightweight floating error label)
- `tests/unit/ui/test_fusion_error_popup.gd`
- `tests/unit/autoload/test_tower_system_fusion_errors.gd`

**Implementation notes:**

**Step 1 -- TowerSystem emits failure reasons:**
- Add a new signal: `signal fusion_failed(tower: Node, reason: String)`
- Add an enum or constants for failure reasons:
  ```gdscript
  const FUSE_FAIL_CANT_AFFORD := "Not enough gold"
  const FUSE_FAIL_INVALID_COMBO := "Invalid fusion combination"
  const FUSE_FAIL_NO_RESULT := "No fusion result exists"
  ```
- In `fuse_towers()`, before each `return false`, emit the signal with the relevant reason and include the required gold amount when applicable:
  ```gdscript
  # Line 74 equivalent:
  if not EconomyManager.can_afford(fusion_cost):
      fusion_failed.emit(tower_a, "Not enough gold -- need %dg" % fusion_cost)
      return false
  ```
- Same treatment for `fuse_legendary()`.

**Step 2 -- Game.gd shows the error:**
- Connect `TowerSystem.fusion_failed` in `_ready()`.
- On failure, spawn a `FusionErrorPopup` near the tower's screen position (similar to the existing `_spawn_gold_text()` pattern but with red text and longer duration).
- The popup is a simple Label that tweens upward and fades out over 1.5s.

**Step 3 -- Optional panel inline error:**
- If the TowerInfoPanel is visible when fusion fails, briefly flash the fuse button red and show the error text in the fusion cost label area.

**Acceptance criteria:**
- [ ] `TowerSystem.fusion_failed` signal is emitted with tower and reason string on every fusion failure path
- [ ] When fusion fails due to insufficient gold, the message includes the required amount (e.g., "Not enough gold -- need 320g")
- [ ] A red floating error label appears near the tower on the game board
- [ ] The error label fades out after ~1.5 seconds and is freed (no orphan nodes)
- [ ] When fusion fails for non-gold reasons (invalid combo), a generic error message is shown
- [ ] The fuse button briefly flashes red on failure (visual feedback on the panel itself)

**TDD approach:**
1. Write unit tests for `TowerSystem.fusion_failed` signal emission: verify signal is emitted with correct reason for each failure path (can't afford, invalid combo, no result)
2. Write unit tests for `FusionErrorPopup`: creation, text content, tween lifecycle, cleanup
3. Write integration test: attempt fusion with insufficient gold, verify both signal emission and popup spawn
4. Implement signal emission in TowerSystem, then the popup in Game.gd

**Dependencies:** None. Can be done independently of Task F1, but doing F1 first reduces the frequency of this error (players will see cost before attempting).

---

### Task F3: Position TowerInfoPanel Near Selected Tower

**Priority:** P2 | **Effort:** Medium-Large

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scenes/ui/TowerInfoPanel.tscn`
- `scripts/main/Game.gd` (pass tower screen position to panel)
- `scripts/autoload/UIManager.gd` (pass position context)

**New test file:**
- `tests/unit/ui/test_tower_info_panel_positioning.gd`

**Implementation notes:**

**Positioning strategy:**
- When `display_tower()` is called, compute the tower's screen-space position using `Camera2D` and place the panel adjacent to it.
- Prefer placing the panel to the right of the tower. If that would clip off-screen, place it to the left. If the tower is near the top/bottom edge, shift vertically to keep the panel fully on-screen.
- The panel remains a child of `UILayer` (CanvasLayer), so its position is in screen-space coordinates, not world-space.

**Position calculation:**
- `UIManager.select_tower()` gains an optional `screen_position: Vector2` parameter, or the panel itself computes it:
  ```gdscript
  func _get_tower_screen_pos() -> Vector2:
      if not _tower or not is_instance_valid(_tower):
          return Vector2.ZERO
      var camera: Camera2D = get_viewport().get_camera_2d()
      var viewport_size: Vector2 = get_viewport().get_visible_rect().size
      var world_pos: Vector2 = _tower.global_position
      # Convert world -> screen using camera transform
      var screen_pos: Vector2 = (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5
      return screen_pos
  ```
- Add `_reposition()` called from `display_tower()` and also from `_process()` (so it tracks during camera pan/zoom).
- Add clamping logic: `position.x = clampf(target_x, margin, viewport_width - panel_width - margin)` and same for y.

**Scene changes:**
- Remove the fixed `anchors_preset = 3` (bottom-right) anchor from `TowerInfoPanel.tscn`.
- Set anchors to top-left (0,0,0,0) so `position` directly controls placement.
- Set `size` explicitly to the panel's minimum size (240 x ~420).

**Camera tracking:**
- During `_process()`, if visible, recalculate position so the panel follows the tower when the player pans or zooms the camera.
- Throttle repositioning to avoid jitter: only reposition if the tower's screen position has moved by more than 2px since last frame.

**Acceptance criteria:**
- [ ] TowerInfoPanel appears adjacent to the selected tower (right side preferred)
- [ ] Panel flips to left side when tower is near the right edge of the screen
- [ ] Panel stays fully on-screen (clamped to viewport bounds with 8px margin)
- [ ] Panel follows the tower when the camera pans or zooms
- [ ] Panel repositions correctly when a different tower is selected
- [ ] Panel hides correctly when tower is deselected (no position artifacts)
- [ ] Touch-friendly: panel does not overlap the tower sprite itself (offset by at least 40px)

**TDD approach:**
1. Write unit tests for the screen-position calculation helper: given mock camera position/zoom and tower world position, verify correct screen coordinates
2. Write unit tests for clamping logic: panel near each screen edge, verify it stays in bounds and flips sides correctly
3. Write unit tests for the "follow on camera move" behavior: change camera position, verify panel repositions
4. Implement the positioning logic and scene changes to make tests pass

**Dependencies:** Should be done after Tasks F1 and F2 since it changes the panel's layout anchoring, which could cause merge conflicts with label additions from F1. The repositioning logic also needs to account for any new labels added in F1 affecting panel height.

---

## Dependency Graph

```
F1 (fusion cost display)  ----\
                                >---> F3 (panel positioning)
F2 (fusion failure feedback) --/
```

- **F1 and F2** are independent of each other and can be done in parallel.
- **F3** depends on F1 and F2 being complete, because:
  - F1 adds a new label that changes the panel's total height (affects positioning/clamping math).
  - F3 changes the panel's anchor mode, which would conflict with F1's scene edits if done simultaneously.

---

## Key Files Reference

| File | Role |
|------|------|
| `scripts/ui/TowerInfoPanel.gd` | Panel script showing tower stats, upgrade/sell/fuse buttons |
| `scenes/ui/TowerInfoPanel.tscn` | Panel scene, currently anchored bottom-right |
| `scripts/autoload/TowerSystem.gd` | Tower creation, upgrade, sell, fusion logic |
| `scripts/autoload/FusionRegistry.gd` | Fusion recipe lookup (dual + legendary) |
| `scripts/autoload/UIManager.gd` | UI coordination, tower selection/deselection |
| `scripts/autoload/EconomyManager.gd` | Gold management, `can_afford()` checks |
| `scripts/main/Game.gd` | Game scene orchestrator, fusion click handling |
| `scenes/main/Game.tscn` | Game scene tree (UILayer contains TowerInfoPanel) |
