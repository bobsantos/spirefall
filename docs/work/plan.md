# Mobile UI/UX Overhaul Plan (v3 -- Hybrid Approach)

**Goal:** Make Spirefall fully playable on mobile phones (regular and foldable) by replacing persistent UI chrome with contextual/collapsible panels, maximizing game board visibility while meeting mobile touch target guidelines.

**Reference:** `docs/work/testing-notes.md` (playtesting), `docs/research/mobile-td-ux-analysis.md` (competitive analysis of Kingdom Rush, BTD6, Arknights, PvZ2, Infinitode 2, Random Dice, Element TD)

**Prerequisites:** Phase 3 touch support is implemented (touch input handlers in Game.gd, `UIManager.is_mobile()` detection, basic mobile sizing constants). The game runs on Android via APK export and mobile browser via HTTPS.

---

## Why v3? Lessons from v2

v2 proposed **targeted scaling** -- enlarging individual UI elements while keeping the same persistent layout (TopBar + BuildMenu always visible). Analysis revealed three problems:

1. **The dp math was wrong.** v2 used 360dp (portrait phone height) as the reference. In landscape, budget 16:9 phones are **270dp tall**. At `270dp / 960px = 0.281 dp/px`, v2's 96px buttons are only 27dp -- well below the 48dp guideline and even below the relaxed 36dp game target.

2. **Too much persistent chrome.** v2 allocated 33% of viewport to permanent UI (TopBar 80px + BuildMenu 160px + margins 80px), leaving only 67% for the game board. During tower inspection with expanded panel, board visibility dropped to ~40%. Top mobile TDs maintain 85-95% board visibility during combat.

3. **The layout was a desktop port, not a mobile design.** Successful mobile TDs (Kingdom Rush, BTD6, Arknights) use contextual/collapsible UI that appears only when needed. Persistent panels are minimal.

**v3 keeps v2's strong interaction patterns** (auto-zoom, two-tier TowerInfoPanel, long-press preview, tap-on-counter wave preview) but replaces the layout strategy with a collapsible/contextual approach inspired by industry-leading mobile TDs.

---

## Scaling Rationale (Corrected for v3)

The viewport is 1280x960 with `keep_height` stretch. On a budget 6.6" phone in landscape (e.g., Samsung Galaxy A14: 1080x2408, ~400 dpi):

- **Landscape dp height: ~270dp** (the SHORT side becomes height)
- **dp-per-viewport-pixel ratio: `270dp / 960px = 0.281`**
- To hit 48dp (Android/iOS guideline): need **171px** in viewport units
- To hit 36dp (relaxed game target, matching Kingdom Rush/BTD6): need **128px**
- To hit 32dp (absolute floor): need **114px**

**v3 targets 128px (36dp) as the minimum interactive element size**, with 114px acceptable for secondary controls. This matches what top-grossing mobile TDs actually ship.

**Screen budget by game phase (mobile):**

| Phase | Status Bar | Game Board | Bottom Panel | Board % |
|-------|-----------|------------|-------------|---------|
| Combat | 48px (5%) | 912px (95%) | none | **95%** |
| Build (browsing) | 48px | 612px | Build Sheet 300px | **64%** |
| Build (placing) | 48px | 848px | Cancel strip 64px | **88%** |
| Tower selected | 48px | ~752px | Collapsed TowerInfo 160px | **78%** |
| Tower detail | 48px | ~576px | Expanded TowerInfo 336px | **60%** |

Compare to v2: fixed 67% board visibility at all times, dropping to 40% during tower inspection.

---

## Architecture Overview

v3 shifts from "scale everything in place" to "show only what's needed, when it's needed."

```
MODIFIED SYSTEMS:
  UIManager (autoload)       - Corrected constants (128px min), safe area, helpers
  Game                       - Placement auto-zoom, grid-snap, BuildFAB management
  HUD                        - Minimal status bar (48px), overflow menu, wave preview trigger
  BuildMenu                  - Toggleable bottom sheet with slide_in/slide_out
  TowerInfoPanel             - Two-tier bottom sheet (collapsed/expanded/dismissed state machine)
  WavePreviewPanel           - Dropdown overlay from wave counter
  PauseMenu                  - Mobile button sizing
  ModeSelect                 - Clickable cards, mobile layout
  MapSelect                  - Clickable cards, mobile layout
  GameOverScreen             - Mobile button/font sizing
  DraftPickPanel             - Mobile button/font sizing
  CodexPanel                 - Mobile font/layout sizing
  DamageNumberManager        - Mobile font scaling

NEW FILES:
  scripts/ui/OverflowMenu.gd  - Speed/Codex/Pause behind menu icon
  scenes/ui/OverflowMenu.tscn
  scripts/ui/BuildFAB.gd      - Floating action button to toggle build sheet
  export/web/custom_shell.html - Browser gesture prevention CSS

NEW ASSETS:
  assets/sprites/ui/icon_gold.png     - 32x32 gold coin icon
  assets/sprites/ui/icon_lives.png    - 32x32 heart icon
  assets/sprites/ui/icon_wave.png     - 32x32 wave/flag icon
  assets/sprites/ui/icon_hammer.png   - 32x32 build hammer icon
```

### Key Design Decisions

1. **Speed button stays in the status bar** (not behind overflow). It's the most frequently toggled action control. Codex and Pause go behind the overflow menu icon.
2. **Build sheet and TowerInfoPanel are mutually exclusive** at the bottom. Opening one closes the other. They never stack.
3. **"Start Wave Early" embeds in the build sheet header**, making the sheet the single build-phase control center.
4. **No two-tap confirmation** for tower placement. The sell mechanic is the undo. Double-tapping adds friction to the most frequent interaction.
5. **Auto-zoom at 1.5x** (not 2.0x) to balance precision against seeing enough map for mazing decisions.
6. **Gold (#FFD700) as universal interactive accent** across FAB, card hover, coach marks, and dismiss buttons, tying into the gold economy theme.
7. **Programmatic art for all UI chrome** -- only 4 PNG icons needed. Everything else (handles, chevrons, highlights, pills) is drawn with StyleBoxFlat/`_draw()`.

---

## Task Groups

### Group A: Foundation (P0)

Corrected constants and browser gesture prevention. Prerequisites for all other groups.

---

#### Task A1: Corrected Mobile Size Constants in UIManager

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/UIManager.gd`

**Implementation notes:**
- Replace all existing MOBILE_ constants with 270dp-validated values (0.281 dp/px):
  - `MOBILE_BUTTON_MIN`: 64x64 -> **128x128** (36dp, meets relaxed target)
  - `MOBILE_TOWER_BUTTON_MIN`: 150x100 -> **170x128** (36dp height)
  - `MOBILE_ACTION_BUTTON_MIN_HEIGHT`: 56 -> **128** (36dp)
  - `MOBILE_START_WAVE_MIN`: 160x64 -> **200x128** (36dp height)
  - `MOBILE_FONT_SIZE_BODY`: 16 -> **24** (6.7dp, readable)
  - `MOBILE_FONT_SIZE_LABEL`: 14 -> **20** (5.6dp, minimum readable)
  - `MOBILE_FONT_SIZE_TITLE`: 24 -> **36** (10dp)
  - `MOBILE_TOPBAR_HEIGHT`: 72 -> **48** (13.5dp, display-only content)
  - `MOBILE_BUILD_MENU_HEIGHT`: 140 -> **300** (84dp, room for 128px buttons + padding)
  - `MOBILE_CARD_MIN_HEIGHT`: 160 -> **200** (56dp)
- Add new constants:
  - `MOBILE_FONT_SIZE_SMALL: int = 16` (4.5dp, minor annotations)
  - `MOBILE_DAMAGE_NUMBER_SCALE: float = 1.8`
  - `MOBILE_PLACEMENT_ZOOM: float = 1.5`
  - `MOBILE_PANEL_MAX_HEIGHT_RATIO: float = 0.35`
  - `MOBILE_PANEL_COLLAPSED_HEIGHT: int = 160` (45dp, fits buttons inside)
  - `MOBILE_OVERFLOW_BUTTON_SIZE: Vector2 = Vector2(96, 48)` (fits in status bar)
- Add helper: `static func format_hint(desktop_text: String, mobile_text: String) -> String`
- Add helper: `static func haptic(duration_ms: int) -> void` (calls `Input.vibrate_handheld()` only on mobile)

**Acceptance criteria:**
- [x] All MOBILE_ constants recalculated for 270dp worst-case (0.281 dp/px)
- [x] Minimum interactive element size is 128px (36dp)
- [x] Status bar height reduced to 48px (display-only, no interactive elements in the bar itself)
- [x] `is_mobile()` continues to work correctly
- [x] No existing functionality breaks (constants only, no logic changes)

---

#### Task A2: Browser Gesture Prevention

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**New files:**
- `export/web/custom_shell.html`

**Modified files:**
- `export_presets.cfg`

**Implementation notes:**
- Copy Godot's default HTML shell template, add CSS rules:
  ```html
  <style>canvas { touch-action: none; } body { overflow: hidden; overscroll-behavior: none; }</style>
  ```
- Verify existing viewport meta tag has `maximum-scale=1.0, user-scalable=no`
- Set `html/custom_html_shell` in export_presets.cfg to point to custom shell
- `touch-action: none` prevents browser zoom, scroll, and swipe-back on the game canvas
- `overflow: hidden` and `overscroll-behavior: none` prevent elastic bounce on iOS Safari

**Acceptance criteria:**
- [x] Pinch-to-zoom in-game does not trigger browser zoom
- [x] Two-finger pan does not trigger browser back navigation
- [x] Single-finger drag does not scroll the page
- [x] No elastic bounce on iOS Safari
- [x] Custom shell path correctly set in export config

---

### Group B: Core Layout Restructure (P0)

Replace persistent TopBar + BuildMenu with contextual/collapsible approach. This is the heart of v3.

---

#### Task B1: Minimal Status Bar with Overflow Menu

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- `scripts/ui/OverflowMenu.gd`
- `scenes/ui/OverflowMenu.tscn`
- `assets/sprites/ui/icon_gold.png` (32x32)
- `assets/sprites/ui/icon_lives.png` (32x32)
- `assets/sprites/ui/icon_wave.png` (32x32)

**Modified files:**
- `scripts/ui/HUD.gd`
- `scenes/ui/HUD.tscn`

**Implementation notes:**
- On mobile, restructure the TopBar HBoxContainer:
  - **Always visible (left to right):** Gold icon + number, Lives icon + number, Wave counter ("W3/30"), Speed button
  - **Behind overflow menu icon (top-right):** Codex button, Pause button
  - Timer info merges into wave counter during combat: "W3/30 42s"
- TopBar height: `MOBILE_TOPBAR_HEIGHT` (48px). Content is display-only labels + speed button + overflow icon
- Speed button stays in the bar because it's the most frequently toggled control
- Icons are 32x32 PNG sprites in TextureRect + Label pairs
- Overflow menu icon: programmatic hamburger (3 horizontal bars via `_draw()`)
- **Overflow menu implementation:**
  - PanelContainer > VBoxContainer > [CodexButton, PauseButton]
  - NOT a Popup node (web compatibility issues)
  - Toggle visibility on overflow icon press
  - Click-outside-to-dismiss via invisible full-screen ColorRect dimmer behind it
  - `process_mode = PROCESS_MODE_WHEN_PAUSED` (since PauseButton lives inside)
- `_apply_mobile_sizing()` hides XP label, TopBarTimerLabel from the bar on mobile
- Countdown label remains as the existing centered overlay (no TopBar space needed)
- Desktop: no changes to existing TopBar layout

**Acceptance criteria:**
- [x] Mobile TopBar shows only: gold, lives, wave counter, speed button, overflow icon
- [x] TopBar is 48px tall on mobile
- [x] Overflow icon opens menu with Codex and Pause buttons
- [x] Overflow menu dismisses on tap outside or button press
- [x] Overflow menu works when game is paused (process_mode)
- [x] Timer info shown in wave counter text on mobile
- [x] Desktop TopBar unchanged
- [x] No horizontal overflow on any mobile device

---

#### Task B2: Toggleable Build Bottom Sheet

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- `scripts/ui/BuildFAB.gd`
- `assets/sprites/ui/icon_hammer.png` (32x32)

**Modified files:**
- `scripts/ui/BuildMenu.gd`
- `scripts/main/Game.gd`

**Implementation notes:**
- **Build FAB (Floating Action Button):**
  - Circular button, 128x128px, gold (#FFD700) background, hammer icon
  - Positioned bottom-right corner, 16px margin from edges
  - Toggles BuildMenu `slide_in()` / `slide_out()`
  - Hidden during combat phase (connect to `GameManager.phase_changed`)
  - Hidden during placement mode (connect to `UIManager.build_requested` / `placement_ended`)
  - Managed by Game.gd (instantiated on mobile in `_ready()`)
  - Pressed state: darkened 20% (#CCB000). Disabled during combat: grayed (#666666)
- **BuildMenu modifications:**
  - Add `slide_in()` / `slide_out()` methods that tween `position.y`
  - On mobile, start hidden (position off-screen below viewport)
  - Tween duration: 0.25s, ease out
  - Auto-dismiss after tower selection: connect to `tower_build_selected`, call `slide_out()` after 0.1s delay
  - Add "Start Wave" button in sheet header (making the sheet the build-phase control center)
  - Add drag handle at top of sheet (40x4px rounded rect, #666666)
  - Sheet height: `MOBILE_BUILD_MENU_HEIGHT` (300px)
  - Tower buttons at `MOBILE_TOWER_BUTTON_MIN` (170x128) with 48x48 thumbnails
  - Element dot indicators: upgrade from ColorRect to `draw_circle()`, 20px diameter on mobile
  - Button font sizes: tower name 20px, cost 18px on mobile
  - HBoxContainer separation: 12px on mobile
  - 6 buttons at 170px + 5 gaps at 12px + cancel 140px = ~1170px, fits in 1280px viewport
  - ScrollContainer handles overflow on narrower devices
- Desktop: no changes to existing BuildMenu behavior

**Acceptance criteria:**
- [x] Build FAB visible during build phase, hidden during combat
- [x] Tapping FAB slides build menu up from bottom
- [x] Tapping FAB again or tapping outside slides menu back down
- [x] Selecting a tower auto-dismisses the sheet
- [x] "Start Wave" button accessible from sheet header
- [x] Drag handle visible at top of sheet
- [x] Tower buttons are at least 170x128 on mobile
- [x] Tower sprite thumbnails are at least 48x48 on mobile
- [x] Element dot indicators are at least 20px diameter circles on mobile
- [x] Cancel button is at least 140x128 on mobile
- [x] Desktop BuildMenu behavior unchanged

---

#### Task B3: Two-Tier TowerInfoPanel Bottom Sheet

**Priority:** P0 | **Effort:** Large | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/TowerInfoPanel.gd`
- `scenes/ui/TowerInfoPanel.tscn`

**Implementation notes:**
- On mobile, implement a state machine for the panel:
  ```
  enum PanelState { DISMISSED, COLLAPSED, EXPANDED }
  ```
  - `DISMISSED -> COLLAPSED`: tower selected (UIManager.tower_selected)
  - `COLLAPSED -> EXPANDED`: tap on collapsed info area, or swipe up
  - `EXPANDED -> COLLAPSED`: swipe down (partial), tap collapse chevron
  - `COLLAPSED -> DISMISSED`: swipe down from collapsed, close button, deselect
  - `EXPANDED -> DISMISSED`: close button, deselect
- **Collapsed state (160px tall):**
  - Tower name + element color dot (left)
  - Upgrade button with cost + Sell button with value (right)
  - Close button (far right)
  - Tap the name/info area to expand
  - Covers 80% of tower interactions (upgrade or sell)
  - Buttons at 128px height inside the collapsed row
- **Expanded state (slides up, max 35% of viewport = ~336px):**
  - Full stat block (damage, speed, range, special ability)
  - Target mode dropdown
  - Synergy info
  - Fuse/Ascend buttons (when applicable)
  - Wrap stats content in ScrollContainer for overflow
  - Action buttons (Upgrade, Sell) fixed outside scroll area
- **Drag handle:** 40x4px rounded rect centered at panel top, with subtle upward chevron when collapsed
- **Swipe gesture detection:** Use `_gui_input(event)` on the PanelContainer (fires before `_unhandled_input`, preventing camera pan conflict). Track vertical touch drag. Threshold: 40px vertical movement triggers state change. Call `accept_event()` to prevent propagation.
- **Mutual exclusion with BuildMenu:** Opening TowerInfoPanel calls BuildMenu `slide_out()`. UIManager.select_tower already hides build menu conceptually.
- Tween transitions between states: 0.2s ease out
- Desktop: keep existing floating panel behavior (no state machine)

**Acceptance criteria:**
- [x] Collapsed state shows tower name, element, upgrade, sell, close
- [x] Collapsed state is 160px tall
- [x] Tapping info area expands to full stats
- [x] Expanded state never exceeds 35% of viewport height
- [x] Expanded state scrolls if content overflows
- [x] Swipe down from collapsed dismisses panel
- [x] Swipe down from expanded collapses panel
- [x] Drag handle and chevron visible at panel top
- [x] Action buttons always accessible (not scrolled away)
- [x] Build sheet auto-closes when TowerInfoPanel opens
- [x] `_gui_input` prevents swipe from being interpreted as camera pan
- [x] Desktop floating panel behavior unchanged

---

#### Task B4: Strip Keyboard Hints on Mobile

**Priority:** P0 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- Audit all button text for keyboard references. Current state appears clean:
  - HUD buttons: "1x", codex icon, pause icon -- no key hints
  - BuildMenu: tower names and costs only -- no key hints
  - TowerInfoPanel: "Upgrade", "Sell", "Fuse..." -- no key hints
- If any "(Key)" suffixes exist, strip them using `UIManager.format_hint()`
- If this is a no-op, mark as done after audit confirms no keyboard text on mobile

**Acceptance criteria:**
- [x] No parenthesized key names visible on any button on mobile
- [x] Desktop button text unchanged

---

### Group C: Critical Interaction Improvements (P0)

Fix mobile interaction patterns: grid cell precision, placement flow.

---

#### Task C1: Tower Placement Auto-Zoom with Grid-Snap

**Priority:** P0 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/Game.gd`

**Implementation notes:**
- When `_on_build_requested()` fires and `is_mobile()`:
  - Store `_pre_placement_zoom: Vector2 = camera.zoom`
  - Tween camera zoom to `min(current_zoom.x * MOBILE_PLACEMENT_ZOOM, ZOOM_MAX.x)` over 0.3s, ease in-out
  - Zoom target point: finger/cursor position, not viewport center
- At 1.5x zoom, grid cells become ~96px = 27dp. Combined with grid-snap hysteresis, this is reliably tappable.
- **Grid-snap hysteresis** (in `_update_ghost()`):
  - Add `_snap_grid_pos: Vector2i` state variable
  - Only update snap target when finger moves > 32px (half cell width) from center of current snapped cell
  - Prevents jitter when finger is near cell borders
  - Highlight the snapped cell border: 3px green (#00CC66) pulsing alpha 0.5-0.8 for valid, 3px red (#CC3333) steady alpha 0.6 for invalid
  - Cell highlight is programmatic `draw_rect(filled=false)` on a dedicated overlay node
  - Desktop: keep instant snap (current behavior), no hysteresis needed
- On placement confirm or cancel, tween back to `_pre_placement_zoom` over 0.3s with 0.15s hold delay
- If pinch-zoom detected during placement mode, kill the auto-zoom tween and let player control zoom manually
- Ghost tower sprite: when auto-zoom is active, render ghost at 1.0x sprite scale (instead of 1.5x) so it appears at natural zoom size

**Acceptance criteria:**
- [x] Camera smoothly zooms to 1.5x when entering placement mode on mobile
- [x] Ghost tower snaps to nearest valid grid cell with hysteresis (32px threshold)
- [x] Snapped cell shows highlighted border (green valid, red invalid)
- [x] Camera restores previous zoom on placement confirm/cancel
- [x] Pinch-zoom during placement overrides auto-zoom
- [x] Pan works during placement
- [x] Ghost sprite scaled correctly during auto-zoom
- [x] Desktop behavior unchanged

---

### Group D: Menu Screen Improvements (P1)

Make mode and map selection screens mobile-friendly with clickable cards.

---

#### Task D1: Clickable Mode Selection Cards

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/ModeSelect.gd`
- `scenes/main/ModeSelect.tscn`

**Implementation notes:**
- On mobile, overlay a transparent full-rect Button on each card PanelContainer
- Button triggers `_select_mode()` for that card
- Locked cards: overlay button disabled
- Visual feedback: StyleBoxFlat overrides -- gold (#FFD700) 2px border on hover/focus, darkened 15% + slight scale(0.98) on pressed
- Card minimum height: `MOBILE_CARD_MIN_HEIGHT` (200px) on mobile
- Desktop: no changes

**Acceptance criteria:**
- [ ] Tapping anywhere on a mode card selects that mode
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible pressed visual feedback
- [ ] Card touch targets meet mobile minimum sizes
- [ ] Desktop behavior unchanged

---

#### Task D2: Clickable Map Selection Cards

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/MapSelect.gd`
- `scenes/main/MapSelect.tscn`

**Implementation notes:**
- Same approach as Task D1 for map cards
- Locked cards do not respond to taps

**Acceptance criteria:**
- [ ] Tapping anywhere on a map card selects that map
- [ ] Locked cards do not respond to taps
- [ ] Cards have visible pressed visual feedback
- [ ] Desktop behavior unchanged

---

### Group E: Comprehensive Mobile Sizing Pass (P1)

Apply corrected mobile sizing to all remaining UI elements.

---

#### Task E1: HUD Mobile Sizing (Status Bar Integration)

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`

**Implementation notes:**
- Update `_apply_mobile_sizing()` to work with the new minimal status bar from B1
- All label font sizes: `MOBILE_FONT_SIZE_BODY` (24) minimum
- WaveControls area (when visible): proportional height increase
- Countdown label: scale up from 64 to 80 for mobile readability
- Notification labels (bonus, XP, overtime): font sizes 28-32 on mobile
- This task handles the sizing constants; B1 handles the layout restructure

**Acceptance criteria:**
- [ ] All HUD labels have font sizes >= 24px on mobile
- [ ] Countdown and notification labels are readable on phone screens
- [ ] No horizontal overflow on mobile
- [ ] Desktop unchanged

---

#### Task E2: PauseMenu Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/PauseMenu.gd`
- `scenes/ui/PauseMenu.tscn`

**Implementation notes:**
- All buttons (Resume, Restart, Settings, Codex, Quit): minimum height 128px on mobile, minimum width 300px
- Button font sizes: `MOBILE_FONT_SIZE_BODY` (24) minimum
- Increase panel padding on mobile

**Acceptance criteria:**
- [ ] All PauseMenu buttons are at least 128px tall on mobile
- [ ] Button text is at least 24px font size on mobile
- [ ] Buttons are easily tappable on phone screens

---

#### Task E3: GameOverScreen Mobile Sizing

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/GameOverScreen.gd`
- `scenes/ui/GameOverScreen.tscn`

**Implementation notes:**
- Button minimum heights: 128px on mobile
- Font sizes: body text 24, title 36 on mobile
- Add haptic feedback on game over: `UIManager.haptic(200)`

**Acceptance criteria:**
- [ ] All buttons are at least 128px tall on mobile
- [ ] Text is readable on phone screens (fonts >= 24px)

---

#### Task E4: Floating Text Mobile Scaling

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/DamageNumberManager.gd`
- `scripts/main/Game.gd`

**Implementation notes:**
- In DamageNumberManager `_configure()`, when `UIManager.is_mobile()`, multiply all `CATEGORY_CONFIG` font sizes by `MOBILE_DAMAGE_NUMBER_SCALE` (1.8x). Current range 12-20px becomes 22-36px (6-10dp).
- Increase outline size from 1 to 2 on mobile for readability
- In Game.gd `_spawn_gold_text()`, use 28px font size on mobile instead of 16px
- Scale float-up distance proportionally (30px -> 54px on mobile)

**Acceptance criteria:**
- [ ] Floating damage numbers are at least 6dp physical on mobile
- [ ] Gold text is at least 8dp physical on mobile
- [ ] Text has visible 2px outline on mobile
- [ ] Desktop sizes unchanged

---

#### Task E5: DraftPickPanel, WavePreview, and CodexPanel Mobile Sizing

**Priority:** P2 | **Effort:** Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/DraftPickPanel.gd`
- `scripts/ui/WavePreviewPanel.gd`
- `scripts/ui/CodexPanel.gd`

**Implementation notes:**
- DraftPickPanel: element pick buttons minimum 128x128 on mobile, font sizes bumped
- WavePreviewPanel: font sizes bumped, enemy row labels to 20px, trait tags as pill-shaped badges (StyleBoxFlat with element color bg at alpha 0.3, 2px corner radius, 4px padding), enemy icons 32x32 on mobile
- CodexPanel: scale all dynamically created content with mobile font sizes. Tab buttons minimum 128px height. Element matrix may need horizontal scroll on mobile.

**Acceptance criteria:**
- [ ] DraftPickPanel buttons are finger-accessible on mobile
- [ ] WavePreviewPanel text is readable on mobile
- [ ] WavePreviewPanel trait tags are pill-shaped badges on mobile
- [ ] CodexPanel content uses mobile font sizes
- [ ] CodexPanel is navigable with touch on mobile

---

### Group F: Mobile UX Enhancements (P1)

New mobile-specific UX patterns for better touch interaction.

---

#### Task F1: Long-Press Tower Preview on Build Buttons

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/BuildMenu.gd`

**Implementation notes:**
- On mobile, tower build buttons get dual-input: quick tap starts placement (existing), long-press (400ms) shows a stat preview popup
- Use a shared Timer node: starts on button press, fires callback to show preview
- On button release before timer: normal tap (select tower)
- On button release after timer: dismiss preview, don't select
- Preview popup: PanelContainer > Label positioned ABOVE the button (not under finger)
- Popup content: element, damage, speed, range, special ability, DPS
- If the upcoming wave is known, show elemental effectiveness in green/red
- Popup styled like existing tooltips (StyleBoxFlat, dark bg alpha 0.95, 1px border #444466, corner radius 6px)
- Small downward-pointing triangle connecting popup to button (programmatic `draw_polygon()`)
- Add a small "i" icon (16x16px) in top-right corner of each tower button as discoverability hint -- visual only, not a separate tap target
- Desktop hover tooltips unchanged (native `tooltip_text`)
- Long-press threshold (400ms) is intentionally shorter than Game.gd's cancel long-press (500ms)

**Acceptance criteria:**
- [ ] Long-press on build button shows tower stat popup
- [ ] Popup appears above the button, not under finger
- [ ] Quick tap still enters placement mode
- [ ] Popup shows element, damage, speed, range, special, DPS
- [ ] Popup dismisses on finger lift
- [ ] "i" badge visible on tower buttons on mobile
- [ ] Desktop hover tooltips unchanged

---

#### Task F2: Wave Preview as Tap-on-Counter Dropdown

**Priority:** P1 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/ui/HUD.gd`
- `scripts/ui/WavePreviewPanel.gd`
- `scenes/ui/WavePreviewPanel.tscn`

**Implementation notes:**
- On mobile, tapping the wave counter label toggles the WavePreviewPanel as a dropdown overlay below the status bar
- Make wave_label clickable: add `_gui_input` handler on the Label that calls `UIManager.show_wave_preview()`
- The overlay shows enemy icons, counts, and traits with mobile-sized fonts
- Full-screen semi-transparent backdrop (#000000 alpha 0.4) behind the panel
- Panel bg at 0.95 alpha with slide-down animation (0.2s)
- Auto-dismisses after 5 seconds, or on tap outside, or when combat starts
- During combat, tapping shows current wave composition
- No permanent screen cost -- the wave counter IS the trigger
- Desktop position unchanged (existing top-right panel)

**Acceptance criteria:**
- [ ] Tapping wave counter on mobile shows wave preview dropdown
- [ ] Preview appears below status bar as overlay with backdrop
- [ ] Slide-down animation on open
- [ ] Auto-dismisses after 5 seconds
- [ ] Dismisses on tap outside or combat start
- [ ] All text readable at mobile font sizes
- [ ] Desktop behavior unchanged (existing top-right panel)

---

#### Task F3: Safe Area Handling

**Priority:** P1 | **Effort:** Small-Medium | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/UIManager.gd`
- `scripts/ui/HUD.gd`
- `scripts/ui/BuildMenu.gd`
- `scripts/ui/TowerInfoPanel.gd`

**Implementation notes:**
- Add `get_safe_area_margins() -> Dictionary` to UIManager returning `{top, bottom, left, right}` in viewport pixels
- On native Android/iOS: use `DisplayServer.get_display_safe_area()` and convert screen-space Rect2i to viewport coords using viewport stretch factor
- On mobile web: safe area handled by browser chrome, return zeros
- Fallback: zeros when detection unavailable (desktop, web)
- Apply insets as margins to StatusBar (top), BuildMenu (bottom), TowerInfoPanel (bottom), and any edge-anchored UI in their `_apply_mobile_sizing()` methods

**Acceptance criteria:**
- [ ] UI content does not render under notch, camera cutout, or system nav bar
- [ ] Safe area works on native Android
- [ ] Fallback (zero margins) applied when safe area detection unavailable
- [ ] Desktop unaffected

---

### Group G: Polish (P2)

Nice-to-have improvements for a native mobile feel.

---

#### Task G1: Haptic Feedback on Key Actions

**Priority:** P2 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/main/Game.gd`
- `scripts/ui/BuildMenu.gd`
- `scripts/ui/HUD.gd`
- `scripts/ui/GameOverScreen.gd`

**Implementation notes:**
- Use `UIManager.haptic(duration_ms)` wrapper (added in A1)
- Haptic events:
  - Tower placed: 30ms
  - Tower upgraded/fused: 50ms
  - Wave started: 20ms
  - Enemy leaked (life lost): 100ms
  - Game over: 200ms
- All calls guarded behind `is_mobile()` via the wrapper
- No haptic more than once per 100ms (debounce in the wrapper)

**Acceptance criteria:**
- [ ] Haptic fires on tower place, upgrade, wave start, life lost, game over on mobile
- [ ] No haptic on desktop
- [ ] No excessive vibration on rapid actions

---

#### Task G2: Battery Saver / Smart Frame Rate

**Priority:** P2 | **Effort:** Small | **GDD Ref:** N/A

**Modified files:**
- `scripts/autoload/GameManager.gd`

**Implementation notes:**
- On mobile, reduce frame rate when game is paused or in build phase with no active animations
- Paused / Build phase: `Engine.max_fps = 30`
- Combat phase: `Engine.max_fps = 60`
- Connect to `phase_changed` and pause state changes
- Only active on mobile

**Acceptance criteria:**
- [ ] Frame rate drops to 30 when paused or in build phase on mobile
- [ ] Frame rate returns to 60 during combat
- [ ] Game logic runs correctly at 30fps
- [ ] Desktop unaffected

---

#### Task G3: Mobile Onboarding Tooltips

**Priority:** P2 | **Effort:** Medium | **GDD Ref:** N/A

**New files:**
- `scripts/ui/OnboardingOverlay.gd`
- `scenes/ui/OnboardingOverlay.tscn`

**Modified files:**
- `scripts/main/Game.gd`

**Implementation notes:**
- On first mobile play, show contextual coach marks:
  - "Tap the hammer to build" (pointing at Build FAB)
  - "Drag to place" (pointing at game board)
  - "Pinch to zoom" (center of screen)
  - "Tap a tower for info" (pointing at a placed tower)
  - "Long-press for details" (pointing at a build button)
- Semi-transparent overlay (#000000 alpha 0.6) with cutout around target element
- Arrow pointing to target (white, pulsing/bobbing animation)
- Text bubble (StyleBoxFlat, dark bg, gold border, 16px text)
- "Got it" dismiss button (gold bg, dark text)
- Step indicator dots (active #FFD700, inactive #555555)
- Tap to advance. Store completion in ConfigFile/SaveSystem.
- Ship AFTER Groups B-F are solid

**Acceptance criteria:**
- [ ] Coach marks appear once on first mobile session
- [ ] Can be dismissed by tapping "Got it"
- [ ] Do not reappear after completion
- [ ] Cutout overlay highlights the correct UI element

---

## Dependency Graph

```
A1 (UIManager Constants) --+-- A2 (Browser Gesture Prevention)
 |
 +-- B1 (Minimal Status Bar + Overflow Menu)
 |    |
 |    +-- F2 (Wave Preview Dropdown) -- depends on B1 (status bar must exist)
 |    +-- E1 (HUD Mobile Sizing) -- depends on B1 (sizing the new layout)
 |
 +-- B2 (Build Bottom Sheet + FAB)
 |    |
 |    +-- F1 (Long-Press Tower Preview) -- depends on B2 (buttons must be sized)
 |
 +-- B3 (TowerInfoPanel Two-Tier Bottom Sheet)
 |
 +-- B4 (Strip Keyboard Hints) -- no code deps, audit after B1/B2
 |
 +-- C1 (Placement Auto-Zoom + Grid-Snap)
 |
 +-- D1 (Mode Select Cards)
 +-- D2 (Map Select Cards)
 |
 +-- E2 (PauseMenu Sizing)
 +-- E3 (GameOverScreen Sizing)
 +-- E4 (Floating Text Scaling)
 +-- E5 (DraftPick/WavePreview/Codex Sizing)
 |
 +-- F3 (Safe Area Handling) -- affects all panels, do early in P1
 |
 +-- G1 (Haptics) -- after core interactions work
 +-- G2 (Battery Saver) -- independent
 +-- G3 (Onboarding) -- after all UX is finalized
```

---

## Recommended Implementation Order

| Order | Task | Group | Priority | Effort | Description |
|-------|------|-------|----------|--------|-------------|
| 1 | A1 | A | P0 | Small | Corrected mobile size constants (128px min) |
| 2 | A2 | A | P0 | Small | Browser gesture prevention |
| 3 | B4 | B | P0 | Small | Strip keyboard hints (likely no-op) |
| 4 | B1 | B | P0 | Medium | Minimal status bar + overflow menu |
| 5 | B2 | B | P0 | Medium | Build bottom sheet + FAB |
| 6 | C1 | C | P0 | Medium | Placement auto-zoom + grid-snap |
| 7 | B3 | B | P0 | Large | TowerInfoPanel two-tier bottom sheet |
| 8 | F3 | F | P1 | Small-Med | Safe area handling |
| 9 | E1 | E | P1 | Small | HUD mobile sizing |
| 10 | E4 | E | P1 | Small | Floating text scaling |
| 11 | F1 | F | P1 | Small | Long-press tower preview |
| 12 | F2 | F | P1 | Small | Wave preview dropdown |
| 13 | D1 | D | P1 | Small | Mode select clickable cards |
| 14 | D2 | D | P1 | Small | Map select clickable cards |
| 15 | E2 | E | P1 | Small | PauseMenu mobile sizing |
| 16 | E3 | E | P1 | Small | GameOverScreen mobile sizing |
| 17 | E5 | E | P2 | Medium | DraftPick/WavePreview/Codex sizing |
| 18 | G1 | G | P2 | Small | Haptic feedback |
| 19 | G2 | G | P2 | Small | Battery saver / smart frame rate |
| 20 | G3 | G | P2 | Medium | Mobile onboarding tooltips |

### Milestone 1: Mobile Playable (Tasks 1-7)
Core layout restructured. Status bar is minimal and contextual. Build menu is a toggleable bottom sheet. Grid cells tappable via auto-zoom + grid-snap. Tower management uses space-efficient two-tier bottom sheet. Browser gestures don't interfere. **Combat: 95% board visibility. Build phase: 64-88% board visibility.**

### Milestone 2: Mobile Polished (Tasks 8-16)
Safe areas respected. All screens and panels sized appropriately. Floating text readable. Tower stats previewable via long-press. Wave info accessible via tap-on-counter. Menu navigation is finger-friendly.

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
| New files | 6 scripts/scenes + 4 PNG icons + 1 HTML shell |
| Modified files | ~18 (scripts + scenes + export config) |
| Small effort | 11 |
| Medium effort | 5 |
| Small-Medium | 1 |
| Large effort | 1 |
| New sprite assets | 4 PNGs (32x32 icons: gold, heart, wave, hammer) |

### Key Design Decisions (v3)

1. **Contextual over persistent** -- Build menu hidden during combat (95% board visibility). TopBar collapsed to 48px status bar. UI appears only when needed, matching top mobile TDs.
2. **270dp worst-case dp math** -- All constants validated against budget 16:9 landscape phones (0.281 dp/px). 128px minimum interactive elements (36dp). v2's 96px was only 27dp.
3. **Speed button stays visible** -- Most frequently toggled control stays in the status bar. Codex and Pause behind overflow menu.
4. **Build sheet + TowerInfo are mutually exclusive** -- Never stack bottom panels. Opening one closes the other.
5. **Auto-zoom 1.5x + grid-snap hysteresis** -- Solves grid cell precision without permanent layout changes. Hysteresis prevents jitter near cell borders.
6. **Two-tier TowerInfoPanel with state machine** -- Collapsed (160px) for quick upgrade/sell, expanded (max 35%) for full stats. Swipe gestures via `_gui_input()` prevent camera pan conflicts.
7. **Gold accent (#FFD700) as interactive color** -- Consistent visual language: gold = tappable/interactive, ties into the gold economy theme.
8. **Programmatic art for UI chrome** -- Only 4 small PNG icons needed. All handles, chevrons, highlights, pills drawn in code for instant iteration.
9. **No two-tap confirmation** -- Sell is the undo. Double-tapping adds friction to the most frequent interaction.

### Critical Path

A1 -> B1 -> B2 -> C1 -> B3 (5 tasks to reach "mobile playable" milestone, plus A2 and B4 as parallel quick wins)
