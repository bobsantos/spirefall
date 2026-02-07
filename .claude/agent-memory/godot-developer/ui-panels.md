# UI Panel Implementation Details

## Tower Info Panel (P2-Task 12)
- TowerInfoPanel.gd emits `fuse_requested(tower)` signal, Game.gd connects once via `_connect_tower_info_fuse_signal()`
- Tier text derived from: tier==1 + upgrade_to!=null + upgrade_to.upgrade_to!=null => "Tier 1"; upgrade_to.upgrade_to==null => "Enhanced"; upgrade_to==null => "Superior". tier==2 => "Fusion". tier==3 => "Legendary"
- TargetMode dropdown indices match Tower.TargetMode enum (0-4). Tower.gd has NO class_name, so cannot reference Tower.TargetMode externally; just set int directly
- Fuse button visible when: Superior (tier 1, no upgrade_to) with dual partners OR legendary partners; OR tier 2 with legendary partners
- Panel dynamically updates on: gold_changed (upgrade affordability), phase_changed (sell value %), tower_upgraded, tower_fused
- Element-colored StyleBoxFlat applied to PanelContainer via add_theme_stylebox_override("panel", style)

## Wave Preview Panel (P2-Task 13)
- WavePreviewPanel.gd subscribes to GameManager.phase_changed directly (self-contained, no external trigger needed)
- BUILD_PHASE -> display_wave(current_wave). current_wave already incremented before signal.
- COMBAT_PHASE -> show_combat_message(). GAME_OVER -> hide.
- INCOME_PHASE transitions directly to BUILD_PHASE in same frame; panel ignores INCOME_PHASE (no match arm), then BUILD_PHASE triggers display.
- EnemySystem.get_wave_config(wave_number) returns raw wave_config.json entry; get_enemy_template(type) is public accessor for _load_enemy_template()
- Enemy rows built dynamically: TextureRect icon (24x24) + Label "Name xCount" + trait tags Label
- Swarm actual_count = config_count * template.spawn_count (same logic as EnemySystem._build_wave_queue)
- Boss name found by scanning enemy groups for types starting with "boss_", loading template, reading enemy_name
- Trait tags: BOSS, Flying, Stealth, Healer, Splits, Swarm, Armored, Elemental, Immune:Element -- each color-coded
- Panel has mouse_filter=2 (IGNORE) so clicks pass through to game board
- Old WavePreview.tscn stub (uid://wavepreview) still exists but is unused; new file is WavePreviewPanel.tscn (uid://wavepreviewpanel)
- UIManager.register_wave_preview() + wave_preview_panel var added; show_wave_preview() signature changed from Dictionary to int

## Fusion UX Flow (P2-Task 15)
- Game.gd fusion state: `_fusing_tower` holds the initiating tower, `_fuse_signal_connected` prevents duplicate connections
- Flow: Fuse button -> fuse_requested signal -> Game._on_fuse_requested() -> deselect tower, highlight partners -> player clicks partner -> _handle_fusion_click() -> TowerSystem.fuse_towers()/fuse_legendary() -> clear highlights, select result
- Partner highlighting: pulsing yellow tween on Sprite2D.modulate, stored as meta "_fuse_tween"/"_pre_fuse_modulate" for cleanup
- Right-click or Escape cancels fusion selection (same as tower placement cancel)
- Handles bidirectional legendary fusion: tries _fusing_tower as tier2 first, then target as tier2
- If _fusing_tower was consumed (reversed legendary), uses target as result_tower for post-fuse selection
