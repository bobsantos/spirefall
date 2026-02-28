# Spirefall Audio Asset Manifest

All audio files in this directory are procedurally generated placeholders.
Replace them with production-quality assets before release.

## Technical Requirements

| Property | SFX | Music |
|----------|-----|-------|
| Format | WAV (OGG preferred for final) | OGG Vorbis (looping) |
| Channels | Mono | Stereo |
| Sample rate | 44100 Hz | 44100 Hz |
| Peak level | -3 dB (normalized) | -6 dB (leaves headroom for SFX) |
| Duration | < 1 second unless noted | 30-120 second seamless loops |

File names must match exactly -- AudioManager loads by string key.

## Volume Hierarchy

SFX loudness tiers (relative targets within the SFX bus):

| Tier | Target dB | Files | Rationale |
|------|-----------|-------|-----------|
| Loud | -3 dB | wave_start, life_lost, tower_fuse, wave_clear | Player attention alerts |
| Medium | -6 dB | tower_place, tower_upgrade, tower_sell, enemy_leak, error_buzz, draft_pick, synergy_activate | Action feedback |
| Quiet | -12 dB | enemy_death, gold_clink, ui_click, tower_shoot_* | High-frequency sounds that must not fatigue |

Music sits underneath SFX at all times. Players adjust master/SFX/music volumes independently.

## Pitch Variation

The engine applies random pitch variation to these SFX. Design the base sound at 1.0x pitch -- do not bake variation into the file:

| SFX | Pitch range | Reason |
|-----|-------------|--------|
| enemy_death | 0.85 - 1.15 | Fires 100-300 times per session |
| gold_clink | 0.9 - 1.1 | Throttled to 1/0.15s but still repetitive |

## SFX Files (20)

### Core gameplay (10 -- currently hooked)

| File | Duration | Trigger | Emotional tone |
|------|----------|---------|----------------|
| `sfx/tower_place.wav` | 0.2s | Tower placed on grid | Solid thud. Satisfying "locked in" feeling |
| `sfx/tower_upgrade.wav` | 0.3s | Tower tier upgraded | Rising sparkle. "Getting stronger" |
| `sfx/tower_sell.wav` | 0.2s | Tower sold for gold | Descending tone + coin ring. Bittersweet |
| `sfx/tower_fuse.wav` | 0.4s | Two towers fused into dual-element | Dramatic whoosh + power chord. Most exciting tower action |
| `sfx/enemy_death.wav` | 0.15s | Enemy killed | Quick pop. Must not annoy at 30+ plays/wave |
| `sfx/enemy_leak.wav` | 0.3s | Enemy reaches exit | Negative buzz. "Something got through" |
| `sfx/life_lost.wav` | 0.3s | Enemy leaks AND lives <= 50% | Deeper alarm. Escalation warning |
| `sfx/wave_start.wav` | 0.4s | New wave begins | Two-tone horn. Alert |
| `sfx/gold_clink.wav` | 0.1s | Gold earned (throttled 1/0.15s) | Bright coin clink |
| `sfx/ui_click.wav` | 0.05s | UI button pressed | Soft click. Subtle |

### New hooks (2 -- hooked in F3)

| File | Duration | Trigger | Emotional tone |
|------|----------|---------|----------------|
| `sfx/wave_clear.wav` | 0.2s | All enemies in wave killed | Ascending C-E-G chime. "Wave survived!" |
| `sfx/error_buzz.wav` | 0.15s | Insufficient funds / invalid action | Low square wave buzz. Clear negative feedback |

### Tower shoot per element (6 -- files only, hookup deferred)

| File | Duration | Element | Emotional tone |
|------|----------|---------|----------------|
| `sfx/tower_shoot_fire.wav` | 0.12s | Fire | Crackling burst |
| `sfx/tower_shoot_water.wav` | 0.15s | Water | Splash whoosh |
| `sfx/tower_shoot_earth.wav` | 0.12s | Earth | Rocky thud |
| `sfx/tower_shoot_wind.wav` | 0.18s | Wind | Airy swoosh |
| `sfx/tower_shoot_lightning.wav` | 0.08s | Lightning | Electric zap |
| `sfx/tower_shoot_ice.wav` | 0.10s | Ice | Crystalline ping |

### Draft & synergy (2 -- files only, hookup deferred)

| File | Duration | Trigger | Emotional tone |
|------|----------|---------|----------------|
| `sfx/draft_pick.wav` | 0.25s | Element drafted in Draft mode | Magical rising sweep + sparkle |
| `sfx/synergy_activate.wav` | 0.35s | Synergy threshold reached (3/5/8 towers) | Power-up chord. "New ability unlocked" |

## Music Files (6)

All music tracks loop seamlessly. Current placeholders are 4-8 seconds; final tracks should be 30-120 seconds.

| File | Duration | Context | Emotional tone |
|------|----------|---------|----------------|
| `music/menu.wav` | 8s loop | Main menu, mode/map select | Calm ambient. C-Am-F-G arpeggios. Inviting |
| `music/build_phase.wav` | 6s loop | Build/planning phase between waves | Relaxed, purposeful. Player is thinking. No urgency |
| `music/combat_phase.wav` | 6s loop | Normal wave combat (not boss) | Energetic, driving rhythm. 160 BPM feel |
| `music/boss_combat.wav` | 6s loop | Boss waves (10, 20, 30) | Intense, dramatic. Minor key, heavy bass. Clearly more urgent than combat_phase |
| `music/victory.wav` | 4s (one-shot) | Game won (all waves survived) | Triumphant fanfare. Rising major arpeggios |
| `music/defeat.wav` | 4s (one-shot) | Game over (lives depleted) | Somber descending minor chords |

## Future Audio (not yet in manifest)

These may be added in future tasks:

- `sfx/boss_spawn.wav` -- deep horn blast when boss appears (0.5-0.8s)
- Per-tower-type attack sounds for fusion and legendary towers
- Ambient map-specific background loops (river sounds, lava bubbling, wind)

## Crossfade Behavior

Music transitions use 0.5s fade-out + 0.5s fade-in crossfade. Design tracks to sound good when cut at any point.

## Generation

All placeholder files are generated by `tools/generate_placeholder_audio.py` using only Python stdlib (wave, struct, math). Re-run to regenerate:

```bash
python3 tools/generate_placeholder_audio.py
```
