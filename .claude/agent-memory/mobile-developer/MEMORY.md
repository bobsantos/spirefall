# Mobile Developer Agent Memory

## Project Scaling Math (Critical)
- Viewport: 1280x960, `canvas_items` stretch, `keep_height` aspect, landscape
- On 360dp-tall phone (landscape): scale = 360/960 = **0.375 dp per viewport px**
- To hit 48dp minimum touch target: need **128px in viewport units**
- Current MOBILE_SCALE of 1.5 is insufficient; need ~2.67x multiplier
- Current MOBILE_BUTTON_MIN of 64px = only 24dp physical (half of minimum)

## Mobile Sizing Pattern
- All UI components use `_apply_mobile_sizing()` called from `_ready()` when `UIManager.is_mobile()`
- Constants centralized in `UIManager` (MOBILE_SCALE, button mins, font sizes, layout dims)
- See [mobile-sizing.md](mobile-sizing.md) for per-component details

## Touch Input Architecture (Game.gd)
- Touch handled in `_unhandled_input` via InputEventScreenTouch/ScreenDrag
- Tap: 150ms delay, 10px move threshold, processes on finger release
- Long press: 500ms, triggers cancel + haptic (50ms vibrate)
- Pinch-to-zoom: two-finger distance tracking with center-of-pinch zoom
- Two-finger drag: camera pan with zoom-adjusted delta
- Ghost tower tracks `_last_touch_screen_pos` during placement
- Placement cooldown: 2 frames after placing to prevent auto-select

## Key Mobile Issues Identified (2026-03-07)
1. Grid cells (64px = 24dp) are below 48dp minimum - placement unreliable
2. All MOBILE_ constants need ~2x increase to meet dp minimums
3. TowerInfoPanel consumes ~50% of screen, no swipe-to-dismiss
4. No safe area handling for notch/punch-hole displays
5. Tooltips on build buttons useless on mobile (no hover)
6. Keyboard hints shown on mobile ("Space", "C")
7. Floating gold text at 16px (6dp) is unreadable
8. No drag-to-place pattern for tower building

## File Locations
- UIManager: `scripts/autoload/UIManager.gd`
- Touch input: `scripts/main/Game.gd` (lines 237-337)
- HUD: `scripts/ui/HUD.gd`, `scenes/ui/HUD.tscn`
- TowerInfoPanel: `scripts/ui/TowerInfoPanel.gd`
- BuildMenu: `scripts/ui/BuildMenu.gd`
- WavePreview: `scripts/ui/WavePreviewPanel.gd`
- Testing notes: `docs/work/testing-notes.md`
- Mobile sizing ADR: `docs/adr/20260305100300-build-menu-mobile-sizing.md`
