---
status: accepted
date: 2026-03-05
decision-makers: [Claude Code]
consulted: [Mobile UI/UX Overhaul Plan]
informed: [Development team]
---

# Expand HUD mobile sizing to cover all elements

## Context and Problem Statement

The HUD `_apply_mobile_sizing()` method only adjusted the top bar height (to 56px) and set minimum sizes for action buttons. Top bar info labels (wave, timer, lives, gold, XP), wave controls labels (timer, enemy count), and notification labels (countdown, bonus, XP notification, overtime) were left at their desktop font sizes, which are too small for comfortable reading on mobile phone screens. Additionally, with 8+ items in the top bar HBoxContainer, larger mobile elements could overflow horizontally.

## Decision Drivers

* All HUD text must be readable on mobile phone screens (minimum 16px body text)
* Touch targets for action buttons must meet minimum 64x64px requirement
* Top bar must not overflow horizontally on wider mobile aspect ratios
* Desktop layout must not regress -- mobile sizing only applies when `UIManager.is_mobile()` is true

## Considered Options

* Scale all HUD elements uniformly by MOBILE_SCALE (1.5x)
* Set individual font sizes and layout properties per element category
* Use a separate mobile HUD scene/theme

## Decision Outcome

Chosen option: "Set individual font sizes and layout properties per element category", because it gives precise control over each element type without requiring a separate scene or theme resource, and uses the existing UIManager constants for consistency.

### Consequences

* Good, because all labels now have explicit font size overrides (>= MOBILE_FONT_SIZE_BODY) on mobile
* Good, because info labels use SIZE_EXPAND_FILL with clip_text to prevent horizontal overflow
* Good, because action buttons keep fixed sizes (no SIZE_EXPAND) so they maintain predictable touch targets
* Good, because desktop layout is completely unchanged -- no _apply_mobile_sizing() call on desktop
* Neutral, because font size overrides are applied at runtime in GDScript rather than through a theme resource

### Confirmation

Validated by `tests/unit/ui/test_hud_mobile_sizing.gd` (33 test cases) covering: top bar height (72px), all label font sizes, button touch targets, wave controls sizing, notification label sizing, expand/fill + clip_text on info labels, button fixed sizing, desktop regression, and source code verification.

## Pros and Cons of the Options

### Uniform MOBILE_SCALE

Apply 1.5x scaling to all font sizes and dimensions.

* Good, because simple to implement (one multiplier)
* Bad, because some elements need different scaling (countdown is already 64px, needs less than 1.5x)
* Bad, because does not address horizontal overflow (larger text without clip_text would overflow)

### Individual font sizes per category

Set specific font sizes and layout flags per element type.

* Good, because precise control over each category (top bar labels, notifications, countdown)
* Good, because can set clip_text and SIZE_EXPAND_FILL only where needed
* Neutral, because more lines of code in _apply_mobile_sizing()

### Separate mobile HUD scene

Create a second HUD.tscn for mobile with different layout properties baked in.

* Good, because layout is visible in the editor
* Bad, because duplicates the entire scene tree, creating a maintenance burden
* Bad, because any new HUD feature must be added to both scenes

## More Information

The implementation adds the following to `_apply_mobile_sizing()`:
- Top bar height: 72px (from `UIManager.MOBILE_TOPBAR_HEIGHT`)
- Top bar info labels: font size 16 (MOBILE_FONT_SIZE_BODY), SIZE_EXPAND_FILL, clip_text
- Wave controls: minimum height 64px, timer/enemy count labels font size 16
- Countdown label: font size 80 (up from desktop 64)
- Bonus label: font size 32 (unchanged, already >= 16)
- XP notification label: font size 16
- Overtime label: font size 28 (unchanged, already >= 16)
- Action buttons: SIZE_EXPAND flag cleared to prevent horizontal expansion
