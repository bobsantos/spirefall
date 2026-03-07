---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos, Claude Code]
consulted: []
informed: []
---

# Increase Build Menu Sizing on Mobile for Touch Usability

## Context and Problem Statement

The build menu tower buttons, cancel button, font sizes, and element indicators were designed for desktop mouse interaction. On mobile phones, the buttons are too small for reliable touch targeting -- players frequently mis-tap adjacent towers or fail to register taps on the small 120x64 buttons. The build menu panel height of 90px leaves insufficient vertical space for the enlarged touch targets.

## Decision Drivers

* Touch targets must meet minimum 48x48dp recommended size (Android Material Design), ideally larger for a game UI
* All 6 tower buttons plus cancel must fit within the 1280px viewport width
* Font sizes must remain readable on 5-6 inch phone screens
* Changes should only apply on mobile -- desktop layout must remain unchanged
* Implementation should be maintainable and consolidated in one place

## Considered Options

* Uniform scale transform on the entire build menu
* Explicit mobile sizes applied via a dedicated `_apply_mobile_sizing()` method
* Theme overrides with a mobile-specific Godot Theme resource

## Decision Outcome

Chosen option: "Explicit mobile sizes via _apply_mobile_sizing()", because it gives precise control over each element's dimensions without affecting layout calculations or requiring a separate theme file. The sizing constants are already defined in UIManager (MOBILE_TOWER_BUTTON_MIN, MOBILE_BUILD_MENU_HEIGHT) establishing a single source of truth.

### Consequences

* Good, because each UI element (button size, font, dot radius, thumbnail) can be tuned independently
* Good, because the method is called once during _ready() with no per-frame cost
* Good, because UIManager constants provide a single source of truth shared across all mobile UI tasks
* Bad, because adding new elements to the build menu requires updating _apply_mobile_sizing() as well

### Confirmation

Unit tests in `tests/unit/ui/test_build_menu_mobile.gd` verify all mobile sizing properties. The `_apply_mobile_sizing()` method is tested by stubbing `UIManager.is_mobile()` or by calling the method directly and asserting minimum sizes on buttons, fonts, and layout containers.

## Pros and Cons of the Options

### Uniform scale transform

Apply a 1.5x scale to the entire BuildMenu Control node on mobile.

* Good, because it requires a single line of code
* Bad, because scaling distorts pixel art and font rendering
* Bad, because it scales padding and margins too, wasting space
* Bad, because collision/input rects may not scale correctly with Control transforms

### Explicit mobile sizes via _apply_mobile_sizing()

Conditionally apply larger sizes to each element using UIManager constants.

* Good, because precise per-element control
* Good, because no rendering artifacts from scaling
* Good, because constants centralized in UIManager
* Neutral, because requires touching multiple properties in one method

### Theme overrides with mobile Theme resource

Create a separate .tres Theme for mobile and swap it at runtime.

* Good, because Godot's theme system is designed for this
* Bad, because themes control font/color/stylebox but not custom_minimum_size or custom layout constants
* Bad, because requires maintaining a parallel theme file
* Bad, because element dot radius and thumbnail size are not theme properties

## More Information

Layout math: 6 tower buttons at 150px + 5 gaps at 12px + cancel button at 130px + margins = ~990px, fitting within 1280px viewport. The build menu panel height increases from 90px (desktop) to 140px on mobile to accommodate the taller buttons.
