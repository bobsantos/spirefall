# Pixel Artist Agent Memory

## Tile Conventions
- All tiles are 64x64 PNG, stored at `assets/sprites/tiles/`
- Base tiles use solid fill + 1px darker border (darkened 30% via `color.darkened(0.3)`)
- Map-specific tiles use 3-color scheme: border (1px), base fill, lighter inner area (inset 4px), plus a subtle pattern overlay
- Existing base tiles: buildable (#4a8c3f green), path (#b5a882 tan), unbuildable (#3d3225 dark brown), spawn (#cc00ff magenta), exit (#00cccc cyan)
- Map-specific tiles: mountain_wall (#4a4a5a slate gray), river (#2a6aaa blue), bridge (#8a6a3a warm brown), lava (#cc4422 red-orange)

## Godot Tile Generation
- Use `Image.create(64, 64, false, Image.FORMAT_RGBA8)` + `image.save_png()`
- Run headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path <project> --script res://path/to/script.gd`
- Script should extend `SceneTree` (not `EditorScript`) for headless CLI execution, call `quit()` in `_init()`
- Existing generator: `scripts/tools/PlaceholderGenerator.gd` (extends EditorScript, for in-editor use)
- Delete one-shot generation scripts after use; keep reusable generators

## Asset Pipeline
- Godot auto-generates `.import` files on next editor open
- Sprite paths use `res://` prefix in GDScript, map to project root on disk
- Project root: `/Users/bobsantos/spirefall/dev/spirefall/`

## Element Color Language (from GDD)
- Fire: red/orange/yellow | Water: blue/cyan/teal | Earth: brown/green/tan
- Wind: white/light green/silver | Lightning: yellow/purple/white | Ice: light blue/white/violet
