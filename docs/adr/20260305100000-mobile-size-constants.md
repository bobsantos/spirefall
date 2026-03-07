---
status: accepted
date: 2026-03-05
decision-makers: [Bob Santos]
consulted: []
informed: []
---

# Centralize and enlarge mobile UI size constants in UIManager

## Context and Problem Statement

Playtesting on mobile devices revealed that UI elements (build menu buttons, tower cards, action buttons) are too small for comfortable touch interaction. The testing notes explicitly state "build interface is small on mobile, everything is small, maybe make components bigger?" We need to systematically increase mobile touch targets and introduce font size and layout constants that were previously missing.

## Decision Drivers

* Touch targets must meet minimum 100px in viewport coordinates for reliable finger tapping
* Font sizes must be legible on 5-6 inch phone screens at typical viewing distances
* Constants should be centralized so all UI components scale consistently
* Changes must not break desktop layout or existing `is_mobile()` behavior

## Considered Options

* Option 1: Update and add constants in UIManager (centralized)
* Option 2: Per-component hardcoded values
* Option 3: Theme-based approach using Godot Theme resources

## Decision Outcome

Chosen option: "Option 1: Update and add constants in UIManager", because it keeps all mobile sizing decisions in one place, matches the existing pattern already established in UIManager, and avoids the complexity of a Theme resource system that would require reworking how components reference sizes.

### Consequences

* Good, because all mobile size values live in a single file, making tuning easy
* Good, because a `MOBILE_SCALE` multiplier (1.5) documents the design intent and can be used for future constants
* Good, because no behavioral changes to `is_mobile()` or existing UI registration logic
* Bad, because components still need to import/reference UIManager constants explicitly (not automatic)

### Confirmation

A GdUnit4 test suite (`tests/unit/autoload/test_ui_manager_constants.gd`) will verify that all constants exist with the correct values. The test will also confirm `is_mobile()` remains a static function returning `bool`.

## Pros and Cons of the Options

### Option 1: Centralized constants in UIManager

* Good, because follows existing pattern (four constants already live here)
* Good, because single point of change for mobile tuning
* Bad, because components must explicitly read these constants

### Option 2: Per-component hardcoded values

* Good, because each component is self-contained
* Bad, because values would be scattered across many files
* Bad, because tuning requires editing every component individually

### Option 3: Theme-based approach

* Good, because Godot's Theme system is designed for UI styling
* Bad, because would require reworking all existing UI components to use theme overrides
* Bad, because disproportionate effort for the current need (just sizing constants)

## More Information

The constant values are derived from a 1.5x scale factor applied to the original values, rounded to clean numbers. The new font size constants (body 16, label 14, title 24) follow Android Material Design minimum recommendations for touch-screen readability.
