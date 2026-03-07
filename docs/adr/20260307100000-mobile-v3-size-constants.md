---
status: "accepted"
date: 2026-03-07
decision-makers: Bob Santos
consulted: Mobile developer agent
informed: Godot developer agent
---

# Update mobile size constants for 270dp landscape worst-case

## Context and Problem Statement

The v2 mobile constants were calculated using 360dp as the reference phone height. However, on budget phones in landscape orientation the usable height is approximately 270dp (after system bars). At 0.281 dp/px, the v2 constants produce touch targets and fonts that are too small to be reliably usable on these devices. We need to recalculate all constants against 270dp to guarantee usability on worst-case hardware.

## Decision Drivers

* Budget Android phones in landscape have only ~270dp vertical space
* Android accessibility guidelines recommend 48dp minimum touch targets (128px at our density)
* Font sizes must remain legible at arm's length on small screens
* Build menu and panels must not exceed ~35% of screen height to keep the playfield visible

## Considered Options

* Option 1: Keep v2 values (360dp reference)
* Option 2: Update to 270dp-validated values
* Option 3: Use runtime dp calculation

## Decision Outcome

Chosen option: "Option 2: Update to 270dp-validated values", because it provides correct constants at build time with no runtime overhead, covers the worst-case device class, and keeps the codebase simple with static constants that are easy to audit and test.

### Consequences

* Good, because all touch targets meet 128px (36dp) minimum on worst-case devices
* Good, because font sizes are validated for readability at 270dp
* Good, because no runtime computation or device-detection logic needed
* Bad, because on larger devices the UI elements may appear slightly oversized (acceptable trade-off)

### Confirmation

Unit tests in `tests/unit/autoload/test_ui_manager_constants.gd` validate every constant against its expected value and enforce the 128px minimum touch target rule.

## Pros and Cons of the Options

### Option 1: Keep v2 values (360dp reference)

* Good, because no code changes required
* Bad, because touch targets are too small on 270dp devices (64px = 18dp, well below 48dp guideline)
* Bad, because fonts are barely readable on budget phones

### Option 2: Update to 270dp-validated values

* Good, because all sizes validated against worst-case hardware
* Good, because simple static constants with zero runtime cost
* Good, because easy to test and audit
* Neutral, because slightly oversized on tablets (not a target platform)

### Option 3: Use runtime dp calculation

* Good, because pixel-perfect sizing on every device
* Bad, because adds runtime complexity and potential for edge-case bugs
* Bad, because harder to test (device-dependent behavior)
* Bad, because over-engineered for our two target platforms (web + Android)

## More Information

Key constant changes: MOBILE_BUTTON_MIN 64->128, MOBILE_TOWER_BUTTON_MIN 150x100->170x128, MOBILE_ACTION_BUTTON_MIN_HEIGHT 56->128, fonts increased (body 16->24, label 14->20, title 24->36), topbar reduced 72->48, build menu expanded 140->300. New constants added for damage numbers, placement zoom, panel height ratios, and overflow buttons.
