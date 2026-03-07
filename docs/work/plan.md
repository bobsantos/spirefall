# Mobile UI/UX Overhaul Plan (v2)

**Goal:** Make Spirefall fully playable on mobile phones (regular and foldable) by fixing touch interaction blockers, scaling UI for physical touch targets, and improving mobile-specific UX patterns.

**Reference:** `docs/work/testing-notes.md` -- playtesting on regular phone and Galaxy Z Fold

**Prerequisites:** Phase 3 touch support is implemented (touch input handlers in Game.gd, `UIManager.is_mobile()` detection, basic mobile sizing constants). The game runs on Android via APK export and mobile browser via HTTPS.

---

## Scaling Rationale

The viewport is 1280x960 with `keep_height` stretch. On a typical 6" phone in landscape (2400x1080 physical, ~360dp tall at 3x density), the dp-per-viewport-pixel ratio is `360dp / 960px = 0.375`. To hit the Android/iOS 48dp minimum touch target, interactive elements need **128 viewport pixels**.

However, doubling ALL constants simultaneously is not viable. TopBar (144px) + BuildMenu (280px) would consume 424px of the 960px viewport, leaving only 56% for the game board. Instead, we use **targeted scaling**:

- **Interactive elements (buttons)**: increase to 96-128px depending on importance
- **Container heights (TopBar, BuildMenu)**: keep moderate (80-100px) to preserve game board visibility
- **Font sizes**: increase to 20-32px range (7.5-12dp physical)
- **Grid cell interaction**: solve via auto-zoom during placement rather than making cells larger

**Screen budget on mobile (960px viewport height):**
- TopBar: ~80px (8%)
- Game board: ~640px (67%) -- minimum acceptable
- Build menu: ~160px (17%)
- Margins/spacing: ~80px (8%)

---

## Architecture Overview

This plan modifies existing UI scripts and scenes. The major design changes are:

1. **Targeted mobile sizing** with corrected dp-aware constants
2. **Auto-zoom during tower placement** so grid cells become tappable
3. **Two-tier TowerInfoPanel** (collapsed bar / expanded sheet) to preserve battlefield visibility
4. **Long-press tower preview** to replace broken hover tooltips
5. **Tap-to-show wave preview** anchored to wave counter label

```
MODIFIED SYSTEMS:
  UIManager (autoload)       - Corrected mobile constants, safe area, helpers
  Game                       - Placement auto-zoom, grid-snap, path overlay
  HUD                        - Pause button, mobile sizing, wave preview trigger
  BuildMenu                  - Larger buttons, long-press preview, keyboard hint strip
  TowerInfoPanel             - Two-tier bottom sheet (collapsed/expanded)
  WavePreviewPanel           - Dropdown overlay from wave counter
  PauseMenu                  - Mobile button sizing
  ModeSelect                 - Clickable cards, mobile layout
  MapSelect                  - Clickable cards, mobile layout
  GameOverScreen             - Mobile button/font sizing
  DraftPickPanel             - Mobile button/font sizing
  CodexPanel                 - Mobile font/layout sizing
  DamageNumberManager        - Mobile font scaling

NO NEW FILES REQUIRED (all changes to existing scripts/scenes)
```

---

## Task Groups

### Group A: Mobile Sizing Foundation (P0)

Establish corrected dp-aware mobile size constants in UIManager.

---

#### Task A1: Corrected Mobile Size Constants in UIManager

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/UIManager.gd`

**Implementation notes:**
- Replace all existing MOBILE_ constants with dp-validated values
- Updated constants (validated against 0.375 dp/px scaling):
  - `MOBILE_BUTTON_MIN`: 64x64 -> 96x96 (36dp, acceptable with generous hit areas)
  - `MOBILE_TOWER_BUTTON_MIN`: 150x100 -> 170x120 (45dp height, near minimum)
  - `MOBILE_ACTION_BUTTON_MIN_HEIGHT`: 56 -> 96 (36dp)
  - `MOBILE_START_WAVE_MIN`: 160x64 -> 200x96 (36dp height)
  - `MOBILE_FONT_SIZE_BODY`: 16 -> 24 (9dp, readable)
  - `MOBILE_FONT_SIZE_LABEL`: 14 -> 20 (7.5dp, minimum readable)
  - `MOBILE_FONT_SIZE_TITLE`: 24 -> 36 (13.5dp)
  - `MOBILE_TOPBAR_HEIGHT`: 72 -> 80 (30dp, compact but usable)
  - `MOBILE_BUILD_MENU_HEIGHT`: 140 -> 160 (60dp)
  - `MOBILE_CARD_MIN_HEIGHT`: 160 -> 200 (75dp)
- Add new constants:
  - `MOBILE_FONT_SIZE_SMALL: int = 16` (6dp, for minor annotations)
  - `MOBILE_DAMAGE_NUMBER_SCALE: float = 1.8` (multiplier for floating text)
  - `MOBILE_PLACEMENT_ZOOM: float = 1.5` (auto-zoom level during placement)
  - `MOBILE_PANEL_MAX_HEIGHT_RATIO: float = 0.35` (max panel height as fraction of viewport)
  - `MOBILE_PANEL_COLLAPSED_HEIGHT: int = 96` (collapsed TowerInfoPanel height)

**Acceptance criteria:**
- [ ] All MOBILE_ constants updated with dp-validated values
- [ ] New constants for damage scaling, placement zoom, panel sizing added
- [ ] `is_mobile()` continues to work correctly (no behavioral change)
- [ ] No existing functionality breaks (constants only, no logic changes)

---

### Group B: Critical Interaction Fixes (P0)

Fix the mobile interaction blockers: grid cells too small, no panel dismiss, no pause access, build menu too small.

---

#### Task B1: Tower Placement Auto-Zoom with Grid-Snap

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/Game.gd`

**Implementation notes:**
- When `_on_build_requested()` fires and `is_mobile()`, store `_pre_placement_zoom` and tween camera zoom to `MOBILE_PLACEMENT_ZOOM` (1.5x) over 0.3s. At 1.5x, grid cells become 96px = 36dp -- combined with grid-snap, this is reliably tappable.
- Implement grid-snap: when the player's finger is within 1.5 cells of a grid cell center, snap the ghost tower to that cell and highlight the cell border. This reduces precision requirements so the player only needs to be "close enough."
- On placement confirm or cancel, tween back to `_pre_placement_zoom` over 0.3s with a 0.3s hold delay (so player can confirm placement visually).
- If pinch-zoom is detected during placement mode, kill the auto-zoom tween and let the player control zoom manually. Do not re-auto-zoom.
- Allow pan during placement mode (already supported).
- Ghost tower sprite already positions correctly at all zoom levels (uses world-space coords via `GridManager.grid_to_world()`). No ghost changes needed.

**Acceptance criteria:**
- [ ] Camera smoothly zooms to 1.5x when entering placement mode on mobile
- [ ] Ghost tower snaps to nearest valid grid cell within 1.5-cell radius
- [ ] Snapped cell shows highlighted border
- [ ] Camera restores previous zoom on placement confirm/cancel
- [ ] Pinch-zoom during placement overrides auto-zoom
- [ ] Pan works during placement
- [ ] Desktop behavior unchanged

---

#### Task B2: Two-Tier TowerInfoPanel Bottom Sheet

**Priority:** P0 | **Effort:** Large | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scenes/ui/TowerInfoPanel.tscn`

**Implementation notes:**
- On mobile, replace the current floating panel with a two-tier bottom sheet:
- **Collapsed state (~96px tall, always visible when tower selected):**
  - Tower name + element color indicator (left)
  - Upgrade button with cost + Sell button with value (right)
  - Close button (far right)
  - Tap the name/info area to expand
  - This covers 80% of tower interactions (upgrade or sell)
- **Expanded state (slides up, max 35% of viewport = ~336px):**
  - Full stat block (damage, speed, range, special ability)
  - Target mode dropdown
  - Synergy info
  - Fuse/Ascend buttons (when applicable)
  - Wrap stats content in ScrollContainer for overflow
  - Tap outside, swipe down, or tap collapse button to return to collapsed state
- **Swipe-to-dismiss:** Track vertical touch drag on the panel. Downward swipe > 80px dismisses (calls `UIManager.deselect_tower()`). Add a visual drag handle (short horizontal bar) at the top of the panel.
- Keep action buttons (Upgrade, Sell) fixed outside the scroll area in both states.
- Restructure .tscn: PanelContainer > VBoxContainer > [CollapsedRow, ScrollContainer > StatsVBox, FixedButtonsVBox]. Update all `@onready` node paths.
- Desktop behavior: keep existing floating panel beside tower (no changes to desktop path).

**Acceptance criteria:**
- [ ] Collapsed state shows tower name, element, upgrade, sell, close
- [ ] Collapsed state is ~96px tall, preserving battlefield visibility
- [ ] Tapping info area expands to full stats
- [ ] Expanded state never exceeds 35% of viewport height
- [ ] Expanded state scrolls if content overflows
- [ ] Swipe down dismisses panel
- [ ] Drag handle visible at panel top
- [ ] Action buttons always accessible (not scrolled away)
- [ ] Desktop floating panel behavior unchanged

---

#### Task B3: Add Pause Button to HUD

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- Add a `PauseButton` to the TopBar HBoxContainer, rightmost element
- Text: "||" (pause symbol)
- On press, call `GameManager.toggle_pause()`
- Size: `MOBILE_BUTTON_MIN` (96x96) on mobile, 40x40 on desktop
- Info labels (Wave, Timer, Lives, Gold, XP) use `SIZE_EXPAND_FILL` with `clip_text = true`. Action buttons (Speed, Codex, Pause) maintain fixed minimum sizes.

**Acceptance criteria:**
- [ ] HUD has a visible pause button in the top bar
- [ ] Pressing pause button calls `GameManager.toggle_pause()`
- [ ] PauseMenu appears when pause button is pressed
- [ ] Pause button meets mobile minimum touch target size
- [ ] No horizontal overflow in top bar on mobile

---

#### Task B4: Increase Build Menu Sizing on Mobile

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/BuildMenu.gd`
- `scenes/ui/BuildMenu.tscn` (if base offsets need adjustment)

**Implementation notes:**
- Increase tower button size on mobile to `MOBILE_TOWER_BUTTON_MIN` (170x120)
- Increase cancel button to 140x120 on mobile
- Increase build menu panel height to `MOBILE_BUILD_MENU_HEIGHT` (160)
- Increase font sizes on mobile: tower name -> `MOBILE_FONT_SIZE_LABEL` (20), cost -> 18
- Increase element dot radius from 6 to 10 on mobile
- Increase tower sprite thumbnail from 32x32 to 48x48 on mobile
- Increase HBoxContainer separation from 6 to 12 on mobile
- 6 buttons at 170px + 5 gaps at 12px + cancel at 140px = ~1170px, fits within 1280px viewport
- ScrollContainer handles overflow if viewport is narrower on some devices

**Acceptance criteria:**
- [ ] Tower build buttons are at least 170x120 on mobile
- [ ] Cancel button is at least 140x120 on mobile
- [ ] Build menu panel height is at least 160 on mobile
- [ ] Font sizes are at least 20px (name) and 18px (cost) on mobile
- [ ] Element dot indicators are at least 20px diameter on mobile
- [ ] Tower sprite thumbnails are at least 48x48 on mobile
- [ ] All buttons remain functional

---

#### Task B5: Strip Keyboard Hints on Mobile

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- In `_apply_mobile_sizing()` for HUD, set: `start_wave_button.text = "Start Wave"`, `codex_button.text = "Codex"`
- In BuildMenu, strip any "(Key)" suffixes from button labels on mobile
- Check for other buttons with keyboard hints and strip them

**Acceptance criteria:**
- [ ] No parenthesized key names visible on any button on mobile
- [ ] Desktop button text unchanged

---

#### Task B6: Browser Gesture Conflict Prevention

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `export_presets.cfg` (head_include)

**Implementation notes:**
- Add to the existing `head_include` in export_presets.cfg:
  ```html
  <style>canvas { touch-action: none; } body { overflow: hidden; }</style>
  ```
- `touch-action: none` prevents browser zoom, scroll, and swipe-back on the game canvas
- `overflow: hidden` prevents elastic bounce on iOS Safari
- The existing viewport meta tag already has `maximum-scale=1.0, user-scalable=no`
- Update existing web export test to verify `touch-action` presence

**Acceptance criteria:**
- [ ] Pinch-to-zoom in-game does not trigger browser zoom
- [ ] Two-finger pan does not trigger browser back navigation
- [ ] Single-finger drag does not scroll the page
- [ ] No elastic bounce on iOS Safari

---

### Group C: Menu Screen Improvements (P1)

Make mode and map selection screens mobile-friendly with clickable cards and larger touch targets.

---

#### Task C1: Clickable Mode Selection Cards

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/ModeSelect.gd`
- `scenes/main/ModeSelect.tscn`

**Implementation notes:**
- Make each PanelContainer card clickable by connecting `gui_input` signal
- Handle both `InputEventMouseButton` and `InputEventScreenTouch`
- Set `mouse_filter = MOUSE_FILTER_STOP` on each card
- Add visual feedback: `StyleBoxFlat` overrides for hover (gold accent) and pressed (darkened) states
- On mobile: increase card minimum height to `MOBILE_CARD_MIN_HEIGHT` (200), increase button minimum height to 96px
- Locked cards do not respond to `gui_input`

**Acceptance criteria:**
- [ ] Tapping anywhere on a mode card selects that mode
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible hover/pressed visual feedback
- [ ] Card touch targets meet mobile minimum sizes
- [ ] Desktop behavior unchanged

---

#### Task C2: Clickable Map Selection Cards

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/MapSelect.gd`
- `scenes/main/MapSelect.tscn`

**Implementation notes:**
- Same approach as Task C1 for map cards
- Locked cards do not respond to `gui_input`

**Acceptance criteria:**
- [ ] Tapping anywhere on a map card selects that map
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible hover/pressed visual feedback
- [ ] Desktop behavior unchanged

---

### Group D: Comprehensive Mobile Sizing Pass (P1)

Apply mobile sizing to all remaining UI elements.

---

#### Task D1: HUD Mobile Sizing Expansion

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- Top bar height: 40 -> `MOBILE_TOPBAR_HEIGHT` (80)
- All label font sizes: `MOBILE_FONT_SIZE_BODY` (24) minimum
- WaveControls area: increase height proportionally
- Countdown label and bonus/XP notification labels: increase font size on mobile
- With `keep_height`, phones have MORE horizontal space (wider aspect ratio), so overflow is unlikely
- 3 action buttons at 96px = 288px, leaving ~990px for 5 labels in a 1280px viewport

**Acceptance criteria:**
- [ ] Top bar height is at least 80px on mobile
- [ ] All HUD labels have font sizes >= 24px on mobile
- [ ] Action buttons maintain minimum touch target sizes
- [ ] No horizontal overflow on mobile
- [ ] Desktop unchanged

---

#### Task D2: PauseMenu Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/PauseMenu.gd`
- `scenes/ui/PauseMenu.tscn`

**Implementation notes:**
- All buttons (Resume, Restart, Settings, Codex, Quit): minimum height 96px on mobile, minimum width 300
- Button font sizes: `MOBILE_FONT_SIZE_BODY` (24) minimum
- Increase panel padding on mobile

**Acceptance criteria:**
- [ ] All PauseMenu buttons are at least 96px tall on mobile
- [ ] Button text is at least 24px font size on mobile
- [ ] Buttons are easily tappable on phone screens

---

#### Task D3: GameOverScreen Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/GameOverScreen.gd`
- `scenes/ui/GameOverScreen.tscn`

**Implementation notes:**
- Button minimum heights: 96px on mobile
- Font sizes: body text 24, title 36 on mobile

**Acceptance criteria:**
- [ ] All buttons are at least 96px tall on mobile
- [ ] Text is readable on phone screens (fonts >= 24px)

---

#### Task D4: Floating Text Mobile Scaling

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/DamageNumberManager.gd`
- `scripts/main/Game.gd`

**Implementation notes:**
- In DamageNumberManager `_configure()`, when `UIManager.is_mobile()`, multiply all `CATEGORY_CONFIG` font sizes by `MOBILE_DAMAGE_NUMBER_SCALE` (1.8x). Current range 12-20px becomes 22-36px (8-13.5dp).
- Increase outline size from 1 to 2 on mobile for readability
- In Game.gd `_spawn_gold_text()`, use 32px font size on mobile instead of 16px
- Slightly increase float-up distance and duration on mobile

**Acceptance criteria:**
- [ ] Floating damage numbers are at least 8dp physical on mobile
- [ ] Gold text is at least 12dp physical on mobile
- [ ] Text has visible outline on mobile
- [ ] Desktop sizes unchanged

---

#### Task D5: DraftPickPanel, WavePreview, and CodexPanel Mobile Sizing

**Priority:** P2 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/DraftPickPanel.gd`
- `scripts/ui/WavePreviewPanel.gd`
- `scripts/ui/CodexPanel.gd`

**Implementation notes:**
- DraftPickPanel: element pick buttons minimum 120x120 on mobile, font sizes bumped
- WavePreviewPanel: font sizes bumped, enemy row labels to 20px, trait tags to 16px
- CodexPanel: scale all dynamically created content (tower entries, enemy entries, element matrix) with mobile font sizes. Tab buttons minimum 96px height. Element matrix may need horizontal scroll on mobile.

**Acceptance criteria:**
- [ ] DraftPickPanel buttons are finger-accessible on mobile
- [ ] WavePreviewPanel text is readable on mobile
- [ ] CodexPanel content uses mobile font sizes
- [ ] CodexPanel is navigable with touch on mobile

---

### Group E: Mobile UX Enhancements (P1)

New mobile-specific UX patterns not in the original plan.

---

#### Task E1: Long-Press Tower Preview on Build Buttons

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- On mobile, tower build buttons get dual-input: quick tap starts placement (existing), long-press (400ms) shows a stat preview popup
- Preview popup appears ABOVE the button (not under the finger) showing: element, damage, speed, range, special ability, DPS
- If the upcoming wave is known, show elemental effectiveness: "1.5x vs Wave N enemies" in green or "0.5x" in red
- Popup dismisses on finger lift (does NOT enter placement mode)
- Long-press threshold (400ms) is intentionally shorter than Game.gd's cancel long-press (500ms)
- Add a small "i" icon (8x8dp) in the corner of each tower button as a discoverability fallback -- tapping it shows the same popup

**Acceptance criteria:**
- [ ] Long-press on build button shows tower stat popup
- [ ] Popup appears above the button, not under finger
- [ ] Quick tap still enters placement mode
- [ ] Popup shows element, damage, speed, range, special, DPS
- [ ] Popup dismisses on finger lift
- [ ] Desktop hover tooltips unchanged

---

#### Task E2: Wave Preview as Tap-on-Counter Dropdown

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scripts/ui/WavePreviewPanel.gd`
- `scenes/ui/WavePreviewPanel.tscn`

**Implementation notes:**
- On mobile, tapping the wave counter label ("Wave 7/30") toggles the WavePreviewPanel as a dropdown overlay below the top bar
- The overlay shows enemy icons, counts, and traits with mobile-sized fonts
- Semi-transparent background (alpha 0.92) so player can partially see the board
- Auto-dismisses after 5 seconds, or on tap outside, or when combat starts
- During combat, tapping shows current wave composition
- Replaces the current top-right fixed position on mobile (desktop position unchanged)
- No permanent screen cost -- the wave counter label IS the trigger

**Acceptance criteria:**
- [ ] Tapping wave counter on mobile shows wave preview dropdown
- [ ] Preview appears below top bar as overlay
- [ ] Auto-dismisses after 5 seconds
- [ ] Dismisses on tap outside or combat start
- [ ] All text readable at mobile font sizes
- [ ] Desktop behavior unchanged (existing top-right panel)

---

#### Task E3: Safe Area Handling

**Priority:** P1 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/UIManager.gd`
- `scripts/ui/HUD.gd`

**Implementation notes:**
- Add `get_safe_area_margins() -> Dictionary` to UIManager returning `{top, bottom, left, right}` in viewport pixels
- On native Android/iOS: use `DisplayServer.get_display_safe_area()` and convert to viewport coords
- On mobile web: use `JavaScriptBridge.eval()` to read CSS `env(safe-area-inset-*)` values
- Fallback: 48px on all sides when detection unavailable
- Apply insets as margins to TopBar, BuildMenu, TowerInfoPanel, and any edge-anchored UI in their `_apply_mobile_sizing()` methods

**Acceptance criteria:**
- [ ] UI content does not render under notch, camera cutout, or system nav bar
- [ ] Safe area works on native Android
- [ ] Fallback margins applied when safe area detection unavailable
- [ ] Desktop unaffected

---

### Group F: Polish (P2)

Nice-to-have improvements for a native mobile feel.

---

#### Task F1: Haptic Feedback on Key Actions

**Priority:** P2 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/Game.gd`
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- Add `UIManager.haptic_light()` (25ms) and `UIManager.haptic_medium()` (50ms) wrappers
- Fire light haptic on button taps, medium on tower placement and wave start
- Guard all calls behind `is_mobile()`. No haptic more than once per 100ms.

**Acceptance criteria:**
- [ ] Haptic fires on tower place and wave start on mobile
- [ ] No haptic on desktop
- [ ] No excessive vibration on rapid actions

---

#### Task F2: 30fps Battery Saver Mode

**Priority:** P2 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/UIManager.gd`

**Implementation notes:**
- Add `set_battery_saver(enabled: bool)` that sets `Engine.max_fps = 30` when enabled
- Surface toggle in pause menu settings area

**Acceptance criteria:**
- [ ] Frame rate drops to 30 when enabled
- [ ] Game logic runs correctly at 30fps
- [ ] Toggle accessible during gameplay

---

#### Task F3: Mobile Onboarding Tooltips

**Priority:** P2 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- New script (minimal)
- `scripts/autoload/UIManager.gd`

**Implementation notes:**
- On first mobile play, show 3-4 contextual coach marks: "Tap a tower to build", "Pinch to zoom", "Tap the map to place", "Swipe down to dismiss panels"
- Semi-transparent overlay with arrow pointing to relevant UI element
- Tap to advance. Store completion in `ConfigFile`.
- Ship AFTER Groups B-E are solid -- onboarding for broken controls is counterproductive.

**Acceptance criteria:**
- [ ] Coach marks appear once on first mobile session
- [ ] Can be dismissed by tapping
- [ ] Do not reappear after completion

---

## Dependency Graph

```
A1 (UIManager Constants)
 |
 +-- B1 (Placement Auto-Zoom + Grid-Snap)
 |
 +-- B2 (TowerInfoPanel Two-Tier Bottom Sheet)
 |
 +-- B3 (HUD Pause Button)
 |
 +-- B4 (Build Menu Sizing)
 |
 +-- B5 (Strip Keyboard Hints)
 |
 +-- B6 (Browser Gesture Prevention) -- no code dependency, but test before other gestures
 |
 +-- C1 (Mode Select Cards)
 |
 +-- C2 (Map Select Cards)
 |
 +-- D1 (HUD Mobile Sizing)
 |
 +-- D2 (PauseMenu Mobile Sizing)
 |
 +-- D3 (GameOverScreen Mobile Sizing)
 |
 +-- D4 (Floating Text Scaling)
 |
 +-- D5 (DraftPick/WavePreview/Codex Sizing)
 |
 +-- E1 (Long-Press Tower Preview) -- depends on B4 (build buttons must be sized first)
 |
 +-- E2 (Wave Preview Dropdown) -- depends on D1 (HUD sizing)
 |
 +-- E3 (Safe Area Handling) -- affects all layout, do early
 |
 +-- F1 (Haptics) -- after core interactions work
 +-- F2 (Battery Saver) -- independent
 +-- F3 (Onboarding) -- after all UX is finalized
```

---

## Recommended Implementation Order

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 1 | A1 | A | P0 | Small | Corrected mobile size constants |
| 2 | B6 | B | P0 | Small | Browser gesture prevention |
| 3 | B5 | B | P0 | Small | Strip keyboard hints |
| 4 | B3 | B | P0 | Small | Add pause button to HUD |
| 5 | B4 | B | P0 | Medium | Build menu sizing |
| 6 | B1 | B | P0 | Medium | Placement auto-zoom + grid-snap |
| 7 | B2 | B | P0 | Large | TowerInfoPanel two-tier bottom sheet |
| 8 | D4 | D | P1 | Small | Floating text scaling |
| 9 | D1 | D | P1 | Medium | HUD mobile sizing |
| 10 | E3 | E | P1 | Medium | Safe area handling |
| 11 | E1 | E | P1 | Medium | Long-press tower preview |
| 12 | E2 | E | P1 | Medium | Wave preview dropdown |
| 13 | C1 | C | P1 | Medium | Mode select clickable cards |
| 14 | C2 | C | P1 | Medium | Map select clickable cards |
| 15 | D2 | D | P1 | Small | PauseMenu mobile sizing |
| 16 | D3 | D | P1 | Small | GameOverScreen mobile sizing |
| 17 | D5 | D | P2 | Medium | DraftPick/WavePreview/Codex sizing |
| 18 | F1 | F | P2 | Small | Haptic feedback |
| 19 | F2 | F | P2 | Small | Battery saver mode |
| 20 | F3 | F | P2 | Medium | Mobile onboarding |

### Milestone 1: Mobile Playable (Tasks 1-7)
Core interaction blockers removed. Grid cells are tappable via auto-zoom. Tower management uses a space-efficient bottom sheet. Pause is accessible. Build menu is usable. Browser gestures don't interfere.

### Milestone 2: Mobile Polished (Tasks 8-16)
All screens and panels are sized appropriately. Floating text is readable. Tower stats are previewable. Wave info is accessible. Safe areas respected. Menu navigation is finger-friendly.

### Milestone 3: Complete Coverage (Tasks 17-20)
Secondary panels mobile-friendly. Haptic feedback. Battery optimization. First-run onboarding.

---

## Summary

| Metric | Count |
|--------|-------|
| Total tasks | 20 |
| P0 tasks | 7 |
| P1 tasks | 9 |
| P2 tasks | 4 |
| New files | 0-1 (onboarding script) |
| Modified files | ~18 (scripts + scenes + export config) |
| Small effort | 8 |
| Medium effort | 10 |
| Large effort | 2 |

### Key Design Decisions

1. **Targeted scaling, not blanket 2x** -- Buttons scale to 96-128px, but container heights stay moderate (80-160px) to preserve 67% game board visibility. Validated against 0.375 dp/px scaling.
2. **Auto-zoom 1.5x + grid-snap during placement** -- Solves the 24dp grid cell problem without permanently enlarging the grid. Grid-snap reduces precision requirements. Player can still pinch-zoom further.
3. **Two-tier TowerInfoPanel** -- Collapsed bar (96px) shows name + upgrade + sell for 80% of interactions. Expanded sheet (max 35% viewport) shows full stats. Preserves battlefield visibility.
4. **Long-press tower preview** -- Replaces broken hover tooltips. 400ms threshold + "i" icon fallback for discoverability. Shows elemental effectiveness vs upcoming wave.
5. **Wave preview as tap-on-counter** -- Zero permanent screen cost. Tapping the wave label shows a dropdown overlay. Auto-dismisses after 5s.
6. **No viewport resolution change** -- 1280x960 with `canvas_items` stretch and `keep_height` is preserved. All fixes are UI scaling within existing viewport.
7. **Browser gesture prevention via CSS** -- Single-line `touch-action: none` in head_include, not JavaScript injection.

### Critical Path

A1 -> B6 -> B5 -> B3 -> B4 -> B1 -> B2 (7 tasks to reach "mobile playable" milestone)
