---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos, Claude Code]
consulted: []
informed: []
---

# TowerInfoPanel mobile sizing adjustments for touch usability

## Context and Problem Statement

The TowerInfoPanel displays tower stats, action buttons (Upgrade, Sell, Fuse, Ascend), and a target mode dropdown. On mobile devices, the default desktop sizing results in labels that are too small to read comfortably and interactive elements that are difficult to tap accurately. Task B1 added a close button and bottom-docking, but the remaining panel content still used desktop-scale sizing.

## Decision Drivers

* Touch targets must meet the 56px minimum height for reliable tapping (per UIManager constants)
* Label text must be at least 16px to remain legible on phone screens
* Panel must be wide enough to display enlarged text without clipping
* Bottom-docked mobile layout should use the full viewport width for maximum information density
* Desktop layout must remain unaffected

## Considered Options

* Expand `_apply_mobile_sizing()` to set font overrides and minimum widths in code
* Create a separate mobile theme resource for the panel
* Use Godot's theme inheritance with a mobile variant

## Decision Outcome

Chosen option: "Expand `_apply_mobile_sizing()` in code", because it keeps all mobile adaptations centralized in one method that is already called conditionally based on `UIManager.is_mobile()`. A separate theme would add file management overhead for a single panel.

### Consequences

* Good, because all mobile sizing logic lives in one method, easy to audit
* Good, because `_get_all_labels()` helper makes it trivial to add new labels in the future
* Good, because `_reposition_mobile()` now spans the full viewport width, giving more room for stats
* Neutral, because font size overrides replace any .tscn-defined sizes (acceptable since mobile needs larger text)
* Bad, because adding a new label to the panel requires updating `_get_all_labels()` -- though this is a minor maintenance cost

### Confirmation

Validated by 24 GdUnit4 tests in `tests/unit/ui/test_tower_info_panel_mobile_sizing.gd` covering:
- All four action buttons meet 56px minimum height
- Target mode dropdown meets 56px minimum height
- All 12 labels have font sizes >= 16 after mobile sizing
- Panel minimum width increases to 300 on mobile
- Bottom-dock spans full viewport width minus margins
- Desktop mode is unaffected (original sizes preserved)

## Pros and Cons of the Options

### Expand `_apply_mobile_sizing()` in code

* Good, because no additional files needed
* Good, because UIManager constants are referenced directly (single source of truth)
* Neutral, because font size overrides in code mask .tscn values on mobile
* Bad, because new labels must be added to the helper array manually

### Separate mobile theme resource

* Good, because Godot's theme system handles inheritance automatically
* Bad, because requires maintaining a parallel .tres file
* Bad, because theme overrides interact poorly with runtime color overrides already used in `_refresh()`

### Theme inheritance with mobile variant

* Good, because clean separation of concerns
* Bad, because Godot 4.x theme inheritance has limited support for per-platform variants
* Bad, because over-engineered for a single panel

## More Information

Related changes:
- Task B1 added the close button and `_reposition_mobile()` bottom-docking
- `_reposition_mobile()` was updated to set `custom_minimum_size.x` to full viewport width minus margins, replacing the previous center-dock approach
- `_get_all_labels()` returns a typed `Array[Label]` for safe iteration
