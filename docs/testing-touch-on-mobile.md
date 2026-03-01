# Testing Touch Input on Mobile

Guide for testing Spirefall's touch support and mobile UI locally.

## 1. Desktop Touch Emulation (Fastest Iteration)

The project has `emulate_touch_from_mouse=true` in `project.godot`, so mouse clicks are forwarded as `InputEventScreenTouch` events and drags as `InputEventScreenDrag`.

**Steps:**
1. Press F5 to run the project in the editor
2. Click and drag to simulate touch and swipe
3. Use the Remote tab in the Scene dock to inspect live node sizes

**Limitations:**
- No multi-touch (pinch zoom, two-finger pan)
- `UIManager.is_mobile()` returns `false` on desktop, so mobile UI sizing won't activate

**To force mobile UI on desktop:**
- Go to Project > Project Settings > Application > Run > Custom User Feature Tags
- Add `mobile` as a tag
- `UIManager.is_mobile()` will now return `true` in the editor
- Remove the tag before shipping

## 2. Android Device via USB (Most Accurate)

Real touch, real `is_mobile()`, real performance. This is the gold standard.

### One-Time Setup

1. Install Android Studio or the Android SDK command-line tools (needed for `adb`)
2. In Godot: Editor > Export > Android — ensure the preset exists with your debug keystore configured
3. On your phone: Settings > About Phone > tap Build Number 7 times to unlock Developer Options
4. Enable USB Debugging in Developer Options
5. Connect phone via USB, accept the RSA key prompt on the phone
6. Verify in Terminal:
   ```bash
   adb devices
   ```
   Your device should appear as `authorized`.

### Method A: One-Click Deploy (Fastest)

1. In the Godot editor top-right, click the dropdown arrow next to the Run button
2. Select your Android device from the list
3. Godot builds a debug APK, pushes it via `adb install`, and launches it (~30 seconds)
4. The Godot debugger stays connected over USB — `print()` output and errors appear in the editor Output panel

### Method B: Export APK Manually

1. Project > Export > Android > Export Project (not "Export PCK/ZIP")
2. Choose a path, export as debug build
3. Install via Terminal:
   ```bash
   adb install -r /path/to/spirefall.apk
   ```

### What to Verify on Device

- `UIManager.is_mobile()` returns `true`
- Touch targets are finger-sized (48px minimum)
- Single tap places/selects towers correctly
- Two-finger drag pans the camera
- Pinch zoom works smoothly
- Long press (0.5s) cancels placement with haptic feedback
- No duplicate placements from double-events
- Frame rate stays above 30fps during combat waves

## 3. HTML5 Export on Phone Browser (Tests itch.io Target)

This tests the WebGL path. `OS.has_feature("web_android")` activates on Android browsers.

### Steps

1. Export the project: Project > Export > Web > Export Project to a local folder
2. Start a local HTTP server (browsers block `file://` for WebAssembly):
   ```bash
   python3 -m http.server 8080 --directory /path/to/web/export/
   ```
3. Find your Mac's local IP:
   ```bash
   ipconfig getifaddr en0
   ```
4. On your phone browser (Chrome recommended), navigate to:
   ```
   http://<your-mac-ip>:8080/index.html
   ```
5. Both devices must be on the same Wi-Fi network

### Caveats

- Safari on iOS has WebGL/WebAssembly quirks — test Chrome on Android first
- Audio may be blocked until the user taps once (browser autoplay policy)
- The `gl_compatibility` renderer targets WebGL 1/2 and should export cleanly

### Chrome DevTools Remote Debugging

Useful for catching JS/WebAssembly errors that don't appear in Godot's output:

1. Connect your Android phone via USB
2. On desktop Chrome, go to `chrome://inspect/#devices`
3. Enable port forwarding if needed
4. Inspect console errors and network requests from the phone's Chrome tab directly on your Mac

## 4. Debugging Tips

### Double-Event Problem

With both `emulate_touch_from_mouse` and `emulate_mouse_from_touch` enabled, a single physical touch on Android can generate both `InputEventScreenTouch` and `InputEventMouseButton`. The touch handler in `Game.gd` processes touch events first and returns immediately, which should prevent duplicates. If you see double placements, add this at the top of `_unhandled_input()` temporarily:

```gdscript
print(event)
```

### Verify Mobile Detection

Add temporarily to any `_ready()`:

```gdscript
print("is_mobile: ", UIManager.is_mobile())
```

If it prints `false` on a real Android device, ensure you're running the exported APK (not a desktop build forwarded over adb).

### Screen Coordinates

The viewport is 1280x960 stretched onto the phone screen. `event.position` from touch events is in viewport coordinates after Godot applies the stretch transform, so grid coordinate math should work unchanged. If placements appear offset, check that you're not mixing `get_global_mouse_position()` with raw `event.position`.

### Performance Baseline

During a real device run, watch the Godot Debugger > Monitors panel for:
- Draw calls: keep below 100
- Physics time: keep below 8ms per frame for 60fps
- Add an FPS display via `Engine.get_frames_per_second()` or enable Project Settings > Debug > Settings > Print FPS
