---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos, Claude Code]
consulted: []
informed: []
---

# Apply Mobile Sizing to PauseMenu, GameOverScreen, DraftPickPanel, WavePreviewPanel, and CodexPanel

## Context and Problem Statement

Several overlay and panel UI screens -- PauseMenu, GameOverScreen, DraftPickPanel, WavePreviewPanel, and CodexPanel -- were designed for desktop mouse interaction. On mobile phones, their buttons are too small for reliable touch targeting (44px default height vs the 56px minimum needed), and font sizes are too small for comfortable reading on 5-6 inch screens. These panels need the same `_apply_mobile_sizing()` treatment already applied to BuildMenu and HUD.

## Decision Drivers

* Touch targets must be at least 56px tall for action buttons (Android Material Design minimum is 48dp; we use 56 for game UI comfort)
* Font sizes must be at least 16px for body text and 24px for titles on mobile to remain readable on phone screens
* DraftPickPanel element cards must be at least 100x100 for reliable touch picking
* CodexPanel close and tab buttons must be finger-accessible
* Changes should only apply on mobile -- desktop layout must remain unchanged
* Implementation should reuse UIManager constants (MOBILE_FONT_SIZE_BODY, MOBILE_FONT_SIZE_TITLE, MOBILE_ACTION_BUTTON_MIN_HEIGHT) as single source of truth

## Considered Options

* Uniform scale transform on each panel
* Explicit mobile sizes applied via `_apply_mobile_sizing()` methods
* Theme overrides with a mobile-specific Godot Theme resource

## Decision Outcome

Chosen option: "Explicit mobile sizes via _apply_mobile_sizing()", because it matches the established pattern from BuildMenu (Task B3) and HUD (Task C1), keeping mobile sizing logic consolidated in a single method per script. The UIManager constants provide a shared source of truth for minimum sizes and font scales.

### Consequences

* Good, because it follows the same pattern as BuildMenu and HUD, keeping the codebase consistent
* Good, because each panel can tune its specific elements (buttons, labels, cards) independently
* Good, because the method is called once during _ready() with no per-frame cost
* Good, because UIManager constants are reused across all panels
* Bad, because each new panel requires its own _apply_mobile_sizing() implementation

### Confirmation

Unit tests verify all mobile sizing properties for each panel:
- `tests/unit/ui/test_pause_menu_mobile.gd` -- PauseMenu button heights, widths, font sizes, panel padding
- `tests/unit/ui/test_game_over_mobile.gd` -- GameOverScreen button heights, font sizes for stats and title
- `tests/unit/ui/test_draft_pick_mobile.gd` -- DraftPickPanel card sizes, font sizes
- `tests/unit/ui/test_wave_preview_mobile.gd` -- WavePreviewPanel font sizes
- `tests/unit/ui/test_codex_mobile.gd` -- CodexPanel close button, tab buttons, font sizes

Tests call `_apply_mobile_sizing()` directly and assert minimum sizes, following the same pattern as `test_build_menu_mobile.gd`.

## Pros and Cons of the Options

### Uniform scale transform

Apply a 1.5x scale to each panel's root Control node on mobile.

* Good, because minimal code changes
* Bad, because scaling distorts pixel art and font rendering
* Bad, because it scales padding and margins too, wasting screen space
* Bad, because panels may overflow the viewport after scaling

### Explicit mobile sizes via _apply_mobile_sizing()

Conditionally apply larger sizes to each element using UIManager constants.

* Good, because precise per-element control
* Good, because no rendering artifacts from scaling
* Good, because constants centralized in UIManager
* Neutral, because requires touching multiple properties in one method per panel

### Theme overrides with mobile Theme resource

Create a separate .tres Theme for mobile and swap it at runtime.

* Good, because Godot's theme system is designed for this
* Bad, because themes control font/color/stylebox but not custom_minimum_size or card dimensions
* Bad, because requires maintaining a parallel theme file

## More Information

This ADR covers tasks D3 (PauseMenu), D4 (GameOverScreen), and D5 (DraftPickPanel, WavePreviewPanel, CodexPanel) from the Mobile UI/UX Overhaul Plan. All five panels follow the same `_apply_mobile_sizing()` pattern established by BuildMenu in ADR 20260305100300.
