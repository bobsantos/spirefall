# Mobile UI/UX Overhaul Plan

**Goal:** Make Spirefall fully playable on mobile phones (regular and foldable) by fixing touch interaction blockers, increasing UI element sizes, and improving menu navigation for finger-based input.

**Reference:** `docs/work/testing-notes.md` — playtesting on regular phone and Galaxy Z Fold

**Prerequisites:** Phase 3 touch support is implemented (touch input handlers in Game.gd, `UIManager.is_mobile()` detection, basic mobile sizing constants). The game runs on Android via APK export.

---

## Architecture Overview

This plan does not introduce new systems. It modifies existing UI scripts and scenes to be mobile-friendly. The core change is a systematic mobile sizing pass with centralized constants, plus targeted UX fixes for mobile-specific interaction gaps.

```
MODIFIED SYSTEMS:
  UIManager (autoload)       - Expanded mobile size constants, mobile scale factor
  HUD                        - Pause button, expanded mobile sizing for all elements
  BuildMenu                  - Larger buttons, fonts, spacing on mobile
  TowerInfoPanel             - Close button, bottom-docked layout on mobile
  PauseMenu                  - Mobile button sizing
  ModeSelect                 - Clickable cards, mobile layout
  MapSelect                  - Clickable cards, mobile layout
  GameOverScreen             - Mobile button/font sizing
  DraftPickPanel             - Mobile button/font sizing
  WavePreviewPanel           - Mobile font sizing
  CodexPanel                 - Mobile font/layout sizing

NO NEW FILES REQUIRED (all changes to existing scripts/scenes)
```

---

## Task Groups

### Group A: Mobile Sizing Foundation (P0)

Establish centralized mobile size constants and scale factor in UIManager. All subsequent tasks reference these constants.

---

#### Task A1: Mobile Size Constants in UIManager

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/autoload/UIManager.gd`

**Implementation notes:**
- Add `MOBILE_SCALE: float = 1.5` constant for systematic scaling
- Minimum mobile touch target: 100px in viewport coordinates (derived from 48dp physical minimum at ~56% viewport scale on typical phones with `keep_height` aspect)
- Updated constants:
  - `MOBILE_BUTTON_MIN`: 56x56 -> 64x64
  - `MOBILE_TOWER_BUTTON_MIN`: 128x80 -> 150x100
  - `MOBILE_ACTION_BUTTON_MIN_HEIGHT`: 48 -> 56
  - `MOBILE_START_WAVE_MIN`: 140x56 -> 160x64
  - Add `MOBILE_FONT_SIZE_BODY: int = 16` (minimum readable on phone)
  - Add `MOBILE_FONT_SIZE_LABEL: int = 14`
  - Add `MOBILE_FONT_SIZE_TITLE: int = 24`
  - Add `MOBILE_TOPBAR_HEIGHT: int = 72`
  - Add `MOBILE_BUILD_MENU_HEIGHT: int = 140`
  - Add `MOBILE_CARD_MIN_HEIGHT: int = 160`
- Rationale for 100px minimum touch target: viewport height 960 maps to ~1080 physical pixels on a typical 6.1" phone in landscape (2.7" physical height, 403 PPI). 1 viewport pixel = ~0.07mm. 7mm minimum touch target = 100 viewport pixels.

**Acceptance criteria:**
- [ ] `UIManager` has `MOBILE_SCALE` constant set to 1.5
- [ ] All existing mobile constants are updated to larger values
- [ ] New font size and layout constants are added
- [ ] `is_mobile()` continues to work correctly (no behavioral change)

---

### Group B: Critical Interaction Fixes (P0)

Fix the three mobile interaction blockers: no way to close tower info panel, no way to access pause menu, and build menu too small to use.

---

#### Task B1: Add Close Button to TowerInfoPanel

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scenes/ui/TowerInfoPanel.tscn`

**Implementation notes:**
- Add an "X" close button as a header row: replace standalone `NameLabel` with an `HBoxContainer` containing the name label (left, expand) and a close button (right, fixed)
- Close button calls `UIManager.deselect_tower()` which already handles hiding the panel
- On mobile: close button minimum size = `MOBILE_BUTTON_MIN` (64x64). On desktop: 28x28 or hidden
- Style the close button with a subtle neutral `StyleBoxFlat` (dark gray bg, light border) so it does not compete with Upgrade/Sell/Fuse action buttons
- On mobile, consider docking the panel at the bottom of the screen (above build menu) instead of floating beside the tower. The floating behavior works on desktop but obscures the game board on small screens. Add a mobile branch in `_reposition()` that sets `position` to bottom-center instead of beside-tower

**Acceptance criteria:**
- [ ] TowerInfoPanel has a visible close button
- [ ] Pressing close button calls `UIManager.deselect_tower()` and hides the panel
- [ ] Close button meets mobile minimum touch target size when `is_mobile()` is true
- [ ] On mobile, panel is positioned at bottom of screen instead of floating beside tower
- [ ] Close button does not visually compete with action buttons (Upgrade, Sell, Fuse)

---

#### Task B2: Add Pause Button to HUD

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- Add a `PauseButton` to the TopBar HBoxContainer, positioned as the rightmost element (after CodexButton)
- Text: "||" (pause symbol) — matches the simple text style of SpeedButton and CodexButton
- On press, call `GameManager.toggle_pause()` which triggers `paused_changed` signal that PauseMenu already listens to
- Size: `MOBILE_BUTTON_MIN` (64x64) on mobile, 40x40 on desktop
- The button does NOT need `PROCESS_MODE_WHEN_PAUSED` — it only needs to pause, not unpause. PauseMenu's Resume button handles unpausing
- The HUD top bar is getting crowded (8 items). On mobile, the info labels (Wave, Timer, Lives, Gold, XP) should be allowed to compress/truncate, and the action buttons (Speed, Codex, Pause) should maintain their minimum sizes
- Future polish: replace text with a 32x32 pixel art pause icon sprite

**Acceptance criteria:**
- [ ] HUD has a visible pause button in the top bar
- [ ] Pressing pause button calls `GameManager.toggle_pause()`
- [ ] PauseMenu appears when pause button is pressed
- [ ] Pause button meets mobile minimum touch target size
- [ ] Pause button is positioned at the right end of the top bar

---

#### Task B3: Increase Build Menu Sizing on Mobile

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/BuildMenu.gd`
- `scenes/ui/BuildMenu.tscn` (if base offsets need adjustment)

**Implementation notes:**
- Increase tower button size on mobile to `MOBILE_TOWER_BUTTON_MIN` (150x100)
- Increase cancel button to 130x100 on mobile
- Increase build menu panel height from 110 to `MOBILE_BUILD_MENU_HEIGHT` (140)
- Increase font sizes on mobile: tower name 11 -> 14, cost 10 -> 13
- Increase element dot radius from 6 to 8 on mobile
- Increase tower sprite thumbnail from 32x32 to 40x40 on mobile
- Increase HBoxContainer separation from 6 to 10-12 on mobile for easier targeting
- All 6 tower buttons at 150px + spacing = ~930px which fits within 1280px viewport without scrolling. If viewport is wider on phone (due to `keep_height`), even more room
- Consolidate mobile sizing into an `_apply_mobile_sizing()` method for consistency with HUD pattern

**Acceptance criteria:**
- [ ] Tower build buttons are at least 150x100 on mobile
- [ ] Cancel button is at least 130x100 on mobile
- [ ] Build menu panel height is at least 140 on mobile
- [ ] Font sizes are at least 14px (name) and 13px (cost) on mobile
- [ ] Element dot indicators are at least 16px diameter on mobile
- [ ] Tower sprite thumbnails are at least 40x40 on mobile
- [ ] All buttons remain functional and tower selection triggers placement mode

---

### Group C: Menu Screen Improvements (P1)

Make mode and map selection screens mobile-friendly with clickable cards and larger touch targets.

---

#### Task C1: Clickable Mode Selection Cards

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/main/ModeSelect.gd`
- `scenes/main/ModeSelect.tscn`

**Implementation notes:**
- Make each PanelContainer card clickable by connecting `gui_input` signal:
  ```gdscript
  func _on_card_input(event: InputEvent, mode_key: String) -> void:
      if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
          _select_mode(mode_key)
      elif event is InputEventScreenTouch and event.pressed:
          _select_mode(mode_key)
  ```
- Set `mouse_filter = MOUSE_FILTER_STOP` on each card PanelContainer
- On mobile: hide the separate "Select" button (redundant with clickable card) or keep as visual anchor
- Add card visual feedback: `StyleBoxFlat` overrides for hover (border glow, gold accent `Color(0.9, 0.75, 0.3)`) and pressed (darkened background) states on each PanelContainer
- On mobile: increase card minimum height to `MOBILE_CARD_MIN_HEIGHT` (160), increase button minimum height to 56px
- Consider vertical layout (1 column) on mobile instead of 3-across HBoxContainer, but test 3-across first — at 280px per card = 888px total, it fits in 1280px viewport with room
- Locked cards should not respond to `gui_input` — check `_is_mode_unlocked()` in the handler

**Acceptance criteria:**
- [ ] Tapping anywhere on a mode card selects that mode (not just the button)
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible hover/pressed visual feedback
- [ ] Card touch targets meet mobile minimum sizes
- [ ] Mode selection still works correctly on desktop (no regression)

---

#### Task C2: Clickable Map Selection Cards

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/main/MapSelect.gd`
- `scenes/main/MapSelect.tscn`

**Implementation notes:**
- Same approach as Task C1: connect `gui_input` on each map card PanelContainer
- Set `mouse_filter = MOUSE_FILTER_STOP` on each card
- Add hover/pressed `StyleBoxFlat` visual feedback
- On mobile: increase card minimum height, increase select button minimum height to 56px
- The 2x2 GridContainer at 320px per card = ~664px total width — fits on phone with `keep_height` aspect
- Locked cards should not respond to `gui_input` — check `_is_map_unlocked()` in the handler

**Acceptance criteria:**
- [ ] Tapping anywhere on a map card selects that map (not just the button)
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible hover/pressed visual feedback
- [ ] Card touch targets meet mobile minimum sizes
- [ ] Map selection still works correctly on desktop (no regression)

---

### Group D: Comprehensive Mobile Sizing Pass (P1)

Apply mobile sizing to all remaining UI elements not covered by Groups A-C.

---

#### Task D1: HUD Mobile Sizing Expansion

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- Expand `_apply_mobile_sizing()` to cover all HUD elements:
  - Top bar height: 40 -> `MOBILE_TOPBAR_HEIGHT` (72)
  - All label font sizes: bump to `MOBILE_FONT_SIZE_BODY` (16) minimum
  - WaveControls area: increase height proportionally
  - Countdown label: increase font size on mobile
  - Bonus/XP notification labels: increase font size on mobile
- The top bar has 8+ items in an HBoxContainer. On mobile with larger elements, verify no overflow. Info labels (Wave, Timer, Lives, Gold, XP) should use `SIZE_EXPAND_FILL` and allow text truncation. Action buttons (Speed, Codex, Pause) should have fixed sizes.
- The `keep_height` stretch aspect gives MORE horizontal space on phones (wider aspect ratio), so horizontal overflow is unlikely

**Acceptance criteria:**
- [ ] Top bar height is at least 72px on mobile
- [ ] All HUD labels have font sizes >= 16px on mobile
- [ ] Action buttons maintain minimum touch target sizes
- [ ] No horizontal overflow or overlapping elements on mobile
- [ ] HUD remains functional on desktop (no regression)

---

#### Task D2: TowerInfoPanel Mobile Sizing

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scenes/ui/TowerInfoPanel.tscn`

**Implementation notes:**
- Expand `_apply_mobile_sizing()`:
  - All action buttons (Upgrade, Sell, Fuse, Ascend): height >= `MOBILE_ACTION_BUTTON_MIN_HEIGHT` (56)
  - Target mode dropdown: height >= 56 on mobile
  - All label font sizes: bump to `MOBILE_FONT_SIZE_BODY` (16) minimum
  - Panel minimum width: increase from 240 to 300 on mobile
- When docked at bottom (from Task B1), the panel should span the full viewport width minus margins and use a horizontal layout for action buttons

**Acceptance criteria:**
- [ ] All action buttons are at least 56px tall on mobile
- [ ] Target mode dropdown is at least 56px tall on mobile
- [ ] All labels have font sizes >= 16px on mobile
- [ ] Panel is wide enough to accommodate larger text without clipping

---

#### Task D3: PauseMenu Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/PauseMenu.gd`
- `scenes/ui/PauseMenu.tscn`

**Implementation notes:**
- Add `_apply_mobile_sizing()` to PauseMenu:
  - All buttons (Resume, Restart, Settings, Codex, Quit): minimum height 56 on mobile, minimum width 280
  - Button font sizes: bump to `MOBILE_FONT_SIZE_BODY` (16) minimum
  - Panel container: increase padding on mobile
- PauseMenu already has `PROCESS_MODE_WHEN_PAUSED`, so no process mode changes needed

**Acceptance criteria:**
- [ ] All PauseMenu buttons are at least 56px tall on mobile
- [ ] Button text is at least 16px font size on mobile
- [ ] Buttons are easily tappable on phone screens

---

#### Task D4: GameOverScreen Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/GameOverScreen.gd`
- `scenes/ui/GameOverScreen.tscn`

**Implementation notes:**
- Add `_apply_mobile_sizing()` with:
  - Button minimum heights: 56 on mobile
  - Font sizes: body text 16, title 24 on mobile
  - Ensure stats display and action buttons are finger-accessible

**Acceptance criteria:**
- [ ] All GameOverScreen buttons are at least 56px tall on mobile
- [ ] Text is readable on phone screens (font sizes >= 16px)

---

#### Task D5: DraftPickPanel and Other UI Mobile Sizing

**Priority:** P2 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- None

**Modified files:**
- `scripts/ui/DraftPickPanel.gd`
- `scripts/ui/WavePreviewPanel.gd`
- `scripts/ui/CodexPanel.gd`

**Implementation notes:**
- Apply consistent mobile sizing to remaining UI panels:
  - DraftPickPanel: element pick buttons minimum 100x100 on mobile, font sizes bumped
  - WavePreviewPanel: font sizes bumped for readability
  - CodexPanel: font sizes bumped, close/navigation buttons sized for touch
- These panels are less critical than the core gameplay UI but should still be usable

**Acceptance criteria:**
- [ ] DraftPickPanel buttons are finger-accessible on mobile
- [ ] WavePreviewPanel text is readable on mobile
- [ ] CodexPanel is navigable with touch on mobile

---

## Dependency Graph

```
A1 (UIManager Constants)
 |
 +-- B1 (TowerInfoPanel Close Button)
 |
 +-- B2 (HUD Pause Button)
 |
 +-- B3 (Build Menu Sizing)
 |
 +-- C1 (Mode Select Cards)
 |
 +-- C2 (Map Select Cards)
 |
 +-- D1 (HUD Mobile Sizing)
 |
 +-- D2 (TowerInfoPanel Mobile Sizing) -- depends on B1
 |
 +-- D3 (PauseMenu Mobile Sizing)
 |
 +-- D4 (GameOverScreen Mobile Sizing)
 |
 +-- D5 (Other UI Mobile Sizing)
```

All tasks depend on A1 for constants. D2 depends on B1 (close button must exist before sizing it). All other tasks are independent of each other and can be parallelized.

---

## Recommended Implementation Order

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 1 | A1 | A | P0 | Small | Mobile size constants in UIManager |
| 2 | B2 | B | P0 | Small | Add pause button to HUD |
| 3 | B1 | B | P0 | Small | Add close button to TowerInfoPanel |
| 4 | B3 | B | P0 | Medium | Increase build menu sizing on mobile |
| 5 | C1 | C | P1 | Medium | Clickable mode selection cards |
| 6 | C2 | C | P1 | Medium | Clickable map selection cards |
| 7 | D1 | D | P1 | Medium | HUD mobile sizing expansion |
| 8 | D2 | D | P1 | Medium | TowerInfoPanel mobile sizing |
| 9 | D3 | D | P1 | Small | PauseMenu mobile sizing |
| 10 | D4 | D | P1 | Small | GameOverScreen mobile sizing |
| 11 | D5 | D | P2 | Small | DraftPickPanel and other UI sizing |

### Milestone 1: Mobile Playable (Tasks 1-4)
Core interaction blockers removed. The game is functional on mobile with pause access, dismissible panels, and usable build menu.

### Milestone 2: Mobile Polished (Tasks 5-10)
All screens and panels are sized appropriately for phone screens. Menu navigation is finger-friendly.

### Milestone 3: Complete Coverage (Task 11)
Secondary panels (Draft, Wave Preview, Codex) are also mobile-friendly.

---

## Summary

| Metric | Count |
|--------|-------|
| Total tasks | 11 |
| P0 tasks | 4 |
| P1 tasks | 6 |
| P2 tasks | 1 |
| New files | 0 |
| Modified files | ~16 (scripts + scenes) |
| Small effort | 6 |
| Medium effort | 5 |
| Large effort | 0 |

### Key Design Decisions

1. **Minimum mobile touch target: 100 viewport pixels** — derived from 48dp physical minimum at ~56% viewport scale on a typical 6.1" phone in landscape with `keep_height` aspect
2. **TowerInfoPanel docks to bottom on mobile** instead of floating beside tower — prevents obscuring the game board
3. **Cards are fully clickable** via `gui_input` on PanelContainer — the separate "Select" button becomes optional/redundant on mobile
4. **No viewport resolution change** — the 1280x960 viewport with `canvas_items` stretch and `keep_height` aspect is preserved. All mobile fixes are done by scaling up UI elements within the existing viewport coordinate space
5. **No new art assets required** — all changes are programmatic (StyleBoxFlat, custom_minimum_size, font size overrides)

### Critical Path

A1 -> B2 -> B1 -> B3 (4 tasks to reach "mobile playable" milestone)
