---
status: "accepted"
date: 2026-03-07
decision-makers: [game-developer]
consulted: [mobile-developer]
informed: []
---

# Prevent Browser Gestures from Interfering with Game Touch Controls

## Context and Problem Statement

On mobile web browsers, native gestures such as pinch-to-zoom, pull-to-refresh, swipe-back navigation, and elastic overscroll bounce interfere with Spirefall's in-game touch controls (tower placement, panning, multi-touch). These gestures cause unintended browser behavior during gameplay and degrade the mobile web experience.

## Decision Drivers

* Mobile web is a primary platform (itch.io HTML5 export)
* Touch controls must feel native and responsive without browser interference
* Solution must not break desktop browser playability
* Maintainability -- CSS rules should live alongside the HTML shell, not be split across settings

## Considered Options

* Option 1: Add CSS rules to `html/head_include` in export_presets.cfg
* Option 2: Custom HTML shell with embedded CSS
* Option 3: JavaScript `addEventListener` with `preventDefault()` on touch events

## Decision Outcome

Chosen option: "Custom HTML shell with embedded CSS", because `head_include` already contains the viewport meta tag and adding more markup makes it unwieldy to maintain as a single-line escaped string. A custom shell gives full control over the page structure, keeps CSS co-located with HTML, and is the Godot-recommended approach for customizing the web export page.

### Consequences

* Good, because all web page customizations live in one readable HTML file
* Good, because CSS `touch-action: none` and `overscroll-behavior: none` are declarative and performant (no JS overhead)
* Good, because the shell is version-controlled and easy to diff
* Bad, because we must maintain the shell if Godot's default shell template changes between versions

### Confirmation

Validated by unit tests in `tests/unit/systems/test_export_config.gd` that verify:
- The custom shell path is set in export_presets.cfg
- The shell file exists on disk
- The shell contains `touch-action: none`, `overflow: hidden`, `overscroll-behavior: none`, and the viewport meta tag

## Pros and Cons of the Options

### Option 1: Add CSS to head_include

Inject `<style>` block via the `html/head_include` export setting.

* Good, because no extra files needed
* Bad, because `head_include` is a single-line escaped string in `export_presets.cfg`, making it hard to read and maintain
* Bad, because it already contains the viewport meta tag; adding more makes it unwieldy

### Option 2: Custom HTML shell with embedded CSS

Create `export/web/custom_shell.html` with all CSS rules and Godot template placeholders.

* Good, because full control over page structure and styling
* Good, because CSS is readable and maintainable in a proper HTML file
* Good, because Godot officially supports custom HTML shells
* Bad, because requires updating if Godot changes its shell template API

### Option 3: JavaScript event prevention

Use `document.addEventListener('touchmove', e => e.preventDefault(), { passive: false })` and similar handlers.

* Good, because can be added anywhere (head_include or shell)
* Bad, because `preventDefault()` on touch events can cause jank and is fragile across browsers
* Bad, because CSS declarative approach is more reliable and performant
* Bad, because some browsers ignore non-passive touch event listeners for performance reasons

## More Information

Key CSS properties used:
- `touch-action: none` on `<canvas>` -- prevents all browser touch gestures on the game canvas
- `overflow: hidden` on `<body>` -- prevents scroll bounce and pull-to-refresh
- `overscroll-behavior: none` on `<body>` -- prevents elastic overscroll and navigation gestures
