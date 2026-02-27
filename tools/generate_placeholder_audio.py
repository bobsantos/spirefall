#!/usr/bin/env python3
"""Generate placeholder audio files for Spirefall tower defense game.

All files are 16-bit PCM mono WAV at 22050 Hz.
Uses only stdlib modules: wave, struct, math, random.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
MAX_AMP = 32767


def write_wav(filepath: str, samples: list[float]) -> None:
    """Write normalized float samples [-1, 1] to a 16-bit mono WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        data = b""
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            data += struct.pack("<h", int(clamped * MAX_AMP))
        wf.writeframes(data)
    size_kb = os.path.getsize(filepath) / 1024
    print(f"  {os.path.basename(filepath):.<30} {len(samples)/SAMPLE_RATE:.2f}s  {size_kb:.1f} KB")


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def sine(freq: float, duration: float, phase: float = 0.0) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    return [math.sin(2 * math.pi * freq * i / SAMPLE_RATE + phase) for i in range(n)]


def square(freq: float, duration: float) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    return [1.0 if math.sin(2 * math.pi * freq * i / SAMPLE_RATE) >= 0 else -1.0 for i in range(n)]


def noise(duration: float) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def silence(duration: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * duration)


def freq_sweep(f_start: float, f_end: float, duration: float) -> list[float]:
    """Linear frequency sweep."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        frac = i / max(n - 1, 1)
        freq = f_start + (f_end - f_start) * frac
        samples.append(math.sin(2 * math.pi * freq * t))
    return samples


def envelope_adsr(samples: list[float], attack: float, decay: float,
                  sustain_level: float, release: float) -> list[float]:
    """Apply ADSR envelope. Times in seconds."""
    n = len(samples)
    a_end = int(attack * SAMPLE_RATE)
    d_end = a_end + int(decay * SAMPLE_RATE)
    r_start = n - int(release * SAMPLE_RATE)
    out = []
    for i in range(n):
        if i < a_end:
            env = i / max(a_end, 1)
        elif i < d_end:
            frac = (i - a_end) / max(d_end - a_end, 1)
            env = 1.0 - frac * (1.0 - sustain_level)
        elif i < r_start:
            env = sustain_level
        else:
            frac = (i - r_start) / max(n - r_start, 1)
            env = sustain_level * (1.0 - frac)
        out.append(samples[i] * env)
    return out


def fade_out(samples: list[float], duration: float) -> list[float]:
    n = len(samples)
    fade_samples = int(duration * SAMPLE_RATE)
    start = n - fade_samples
    out = list(samples)
    for i in range(start, n):
        frac = (i - start) / max(fade_samples, 1)
        out[i] *= 1.0 - frac
    return out


def fade_in(samples: list[float], duration: float) -> list[float]:
    fade_samples = int(duration * SAMPLE_RATE)
    out = list(samples)
    for i in range(min(fade_samples, len(out))):
        out[i] *= i / max(fade_samples, 1)
    return out


def mix(*tracks: list[float]) -> list[float]:
    """Mix multiple sample lists, normalizing to avoid clipping."""
    max_len = max(len(t) for t in tracks)
    mixed = [0.0] * max_len
    for t in tracks:
        for i in range(len(t)):
            mixed[i] += t[i]
    # Normalize
    peak = max(abs(s) for s in mixed) if mixed else 1.0
    if peak > 1.0:
        mixed = [s / peak for s in mixed]
    return mixed


def scale(samples: list[float], vol: float) -> list[float]:
    return [s * vol for s in samples]


def overlay_at(base: list[float], overlay: list[float], offset_sec: float) -> list[float]:
    """Overlay samples on top of base at a time offset."""
    out = list(base)
    start = int(offset_sec * SAMPLE_RATE)
    for i in range(len(overlay)):
        idx = start + i
        if idx < len(out):
            out[idx] += overlay[i]
    return out


def low_pass_simple(samples: list[float], alpha: float = 0.1) -> list[float]:
    """Very simple single-pole low-pass filter."""
    out = [samples[0]]
    for i in range(1, len(samples)):
        out.append(out[-1] + alpha * (samples[i] - out[-1]))
    return out


def chord(freqs: list[float], duration: float) -> list[float]:
    """Stack sine waves at given frequencies."""
    tracks = [sine(f, duration) for f in freqs]
    return mix(*tracks)


# ---------------------------------------------------------------------------
# SFX generators
# ---------------------------------------------------------------------------

def gen_tower_place() -> list[float]:
    """Solid thud -- low sine burst + noise transient."""
    thud = envelope_adsr(sine(80, 0.2), 0.005, 0.05, 0.3, 0.1)
    click = envelope_adsr(low_pass_simple(noise(0.05), 0.3), 0.001, 0.02, 0.0, 0.02)
    return mix(scale(thud, 0.8), scale(click, 0.5))


def gen_tower_upgrade() -> list[float]:
    """Rising tone with sparkle."""
    sweep = envelope_adsr(freq_sweep(300, 800, 0.3), 0.01, 0.05, 0.7, 0.1)
    sparkle1 = envelope_adsr(sine(1200, 0.15), 0.005, 0.05, 0.3, 0.05)
    sparkle2 = envelope_adsr(sine(1600, 0.1), 0.005, 0.03, 0.2, 0.04)
    base = list(sweep)
    base = overlay_at(base, sparkle1, 0.12)
    base = overlay_at(base, sparkle2, 0.18)
    peak = max(abs(s) for s in base)
    if peak > 1.0:
        base = [s / peak for s in base]
    return base


def gen_tower_sell() -> list[float]:
    """Descending tone + coin-like ring."""
    sweep = envelope_adsr(freq_sweep(600, 250, 0.2), 0.01, 0.03, 0.5, 0.08)
    coin = envelope_adsr(sine(2000, 0.1), 0.002, 0.03, 0.2, 0.04)
    base = overlay_at(list(sweep), coin, 0.05)
    peak = max(abs(s) for s in base)
    if peak > 1.0:
        base = [s / peak for s in base]
    return base


def gen_tower_fuse() -> list[float]:
    """Dramatic rising whoosh with power chord at the end."""
    whoosh = envelope_adsr(freq_sweep(100, 1000, 0.4), 0.02, 0.05, 0.8, 0.1)
    noise_whoosh = envelope_adsr(low_pass_simple(noise(0.4), 0.05), 0.05, 0.1, 0.3, 0.15)
    power = envelope_adsr(chord([400, 500, 600], 0.2), 0.01, 0.05, 0.6, 0.08)
    base = mix(scale(whoosh, 0.6), scale(noise_whoosh, 0.3))
    base = overlay_at(base, scale(power, 0.5), 0.2)
    peak = max(abs(s) for s in base)
    if peak > 1.0:
        base = [s / peak for s in base]
    return base


def gen_enemy_death() -> list[float]:
    """Quick pop/burst."""
    pop = envelope_adsr(sine(400, 0.15), 0.002, 0.02, 0.0, 0.05)
    burst = envelope_adsr(noise(0.08), 0.001, 0.02, 0.0, 0.03)
    return mix(scale(pop, 0.6), scale(burst, 0.5))


def gen_enemy_leak() -> list[float]:
    """Negative buzz/alarm -- dissonant."""
    buzz = envelope_adsr(square(150, 0.3), 0.01, 0.05, 0.5, 0.1)
    high = envelope_adsr(sine(450, 0.3), 0.01, 0.05, 0.4, 0.1)
    return mix(scale(buzz, 0.4), scale(high, 0.3))


def gen_life_lost() -> list[float]:
    """Deeper negative tone -- descending minor."""
    tone1 = envelope_adsr(sine(250, 0.15), 0.01, 0.03, 0.6, 0.05)
    tone2 = envelope_adsr(sine(200, 0.15), 0.01, 0.03, 0.6, 0.05)
    return tone1 + tone2


def gen_wave_start() -> list[float]:
    """Alert horn -- two-tone."""
    horn1 = envelope_adsr(
        mix(sine(440, 0.2), scale(sine(880, 0.2), 0.3)),
        0.02, 0.03, 0.7, 0.05
    )
    horn2 = envelope_adsr(
        mix(sine(550, 0.2), scale(sine(1100, 0.2), 0.3)),
        0.02, 0.03, 0.7, 0.08
    )
    return horn1 + horn2


def gen_gold_clink() -> list[float]:
    """Bright coin clink."""
    clink = envelope_adsr(sine(3000, 0.1), 0.001, 0.02, 0.15, 0.05)
    overtone = envelope_adsr(sine(4500, 0.08), 0.001, 0.015, 0.1, 0.04)
    return mix(scale(clink, 0.7), scale(overtone, 0.4))


def gen_ui_click() -> list[float]:
    """Soft click."""
    click = envelope_adsr(sine(1000, 0.05), 0.001, 0.01, 0.0, 0.02)
    tap = envelope_adsr(noise(0.02), 0.001, 0.005, 0.0, 0.01)
    return mix(scale(click, 0.5), scale(tap, 0.3))


# -- New SFX (F3) -----------------------------------------------------------

def gen_tower_shoot_fire() -> list[float]:
    """Crackling burst -- fire element."""
    crackle = envelope_adsr(noise(0.12), 0.001, 0.02, 0.2, 0.06)
    crackle = low_pass_simple(crackle, 0.15)
    tone = envelope_adsr(sine(200, 0.08), 0.002, 0.02, 0.0, 0.03)
    return mix(scale(crackle, 0.6), scale(tone, 0.4))


def gen_tower_shoot_water() -> list[float]:
    """Splash whoosh -- water element."""
    whoosh = envelope_adsr(noise(0.15), 0.002, 0.03, 0.1, 0.08)
    whoosh = low_pass_simple(whoosh, 0.08)
    drip = envelope_adsr(sine(1800, 0.06), 0.001, 0.01, 0.0, 0.03)
    return mix(scale(whoosh, 0.5), scale(drip, 0.3))


def gen_tower_shoot_earth() -> list[float]:
    """Rocky thud -- earth element."""
    thud = envelope_adsr(sine(60, 0.12), 0.003, 0.03, 0.1, 0.05)
    grit = envelope_adsr(low_pass_simple(noise(0.08), 0.2), 0.001, 0.02, 0.0, 0.03)
    return mix(scale(thud, 0.7), scale(grit, 0.4))


def gen_tower_shoot_wind() -> list[float]:
    """Airy swoosh -- wind element."""
    swoosh = envelope_adsr(noise(0.18), 0.01, 0.05, 0.15, 0.08)
    swoosh = low_pass_simple(swoosh, 0.05)
    whistle = envelope_adsr(freq_sweep(800, 1200, 0.1), 0.005, 0.03, 0.1, 0.04)
    return mix(scale(swoosh, 0.4), scale(whistle, 0.3))


def gen_tower_shoot_lightning() -> list[float]:
    """Electric zap -- lightning element."""
    zap = envelope_adsr(square(300, 0.08), 0.001, 0.01, 0.1, 0.04)
    crackle = envelope_adsr(noise(0.06), 0.001, 0.01, 0.0, 0.03)
    high = envelope_adsr(sine(2500, 0.05), 0.001, 0.01, 0.0, 0.02)
    return mix(scale(zap, 0.5), scale(crackle, 0.3), scale(high, 0.3))


def gen_tower_shoot_ice() -> list[float]:
    """Crystalline ping -- ice element."""
    ping = envelope_adsr(sine(2200, 0.1), 0.001, 0.02, 0.15, 0.05)
    shimmer = envelope_adsr(sine(3300, 0.08), 0.001, 0.015, 0.1, 0.04)
    return mix(scale(ping, 0.6), scale(shimmer, 0.3))


def gen_wave_clear() -> list[float]:
    """Satisfying chime -- all enemies cleared."""
    c5 = envelope_adsr(sine(523.25, 0.2), 0.005, 0.03, 0.4, 0.08)
    e5 = envelope_adsr(sine(659.25, 0.2), 0.005, 0.03, 0.4, 0.08)
    g5 = envelope_adsr(sine(783.99, 0.3), 0.005, 0.05, 0.5, 0.12)
    chime = list(c5)
    chime = overlay_at(chime, e5, 0.08)
    chime = overlay_at(chime, g5, 0.16)
    peak = max(abs(s) for s in chime)
    if peak > 1.0:
        chime = [s / peak for s in chime]
    return scale(chime, 0.7)


def gen_error_buzz() -> list[float]:
    """Negative buzz -- insufficient funds / invalid action."""
    buzz = envelope_adsr(square(120, 0.15), 0.002, 0.03, 0.3, 0.05)
    return scale(buzz, 0.4)


def gen_draft_pick() -> list[float]:
    """Magical selection chime -- element drafted."""
    sweep = envelope_adsr(freq_sweep(400, 900, 0.25), 0.01, 0.05, 0.5, 0.08)
    sparkle = envelope_adsr(sine(1400, 0.15), 0.005, 0.03, 0.2, 0.06)
    base = overlay_at(list(sweep), sparkle, 0.1)
    peak = max(abs(s) for s in base)
    if peak > 1.0:
        base = [s / peak for s in base]
    return scale(base, 0.6)


def gen_synergy_activate() -> list[float]:
    """Power-up chord -- synergy threshold reached."""
    chord_tones = envelope_adsr(chord([440, 554.37, 659.25], 0.35), 0.02, 0.05, 0.6, 0.12)
    shimmer = envelope_adsr(sine(1318.5, 0.2), 0.005, 0.03, 0.2, 0.08)
    base = overlay_at(list(chord_tones), shimmer, 0.1)
    peak = max(abs(s) for s in base)
    if peak > 1.0:
        base = [s / peak for s in base]
    return scale(base, 0.65)


# ---------------------------------------------------------------------------
# Music generators
# ---------------------------------------------------------------------------

def gen_music_menu() -> list[float]:
    """Calm ambient loop ~8s. Gentle arpeggiated chords."""
    duration = 8.0
    # C major -> Am -> F -> G progression, 2s each
    progressions = [
        [261.63, 329.63, 392.00],  # C major
        [220.00, 261.63, 329.63],  # Am
        [174.61, 220.00, 261.63],  # F
        [196.00, 246.94, 293.66],  # G
    ]
    samples = []
    for chord_freqs in progressions:
        seg = envelope_adsr(chord(chord_freqs, 2.0), 0.1, 0.3, 0.5, 0.3)
        # Add gentle arpeggio on top
        for j, f in enumerate(chord_freqs):
            arp = envelope_adsr(sine(f * 2, 0.3), 0.01, 0.05, 0.2, 0.1)
            seg = overlay_at(seg, scale(arp, 0.2), 0.4 + j * 0.4)
        samples.extend(seg)
    # Normalize
    peak = max(abs(s) for s in samples)
    if peak > 1.0:
        samples = [s / peak for s in samples]
    return scale(samples, 0.7)


def gen_music_build_phase() -> list[float]:
    """Relaxed planning vibe ~6s. Soft pads with light melody."""
    duration = 6.0
    # Dm -> Bb -> C -> Am, 1.5s each
    progressions = [
        [146.83, 174.61, 220.00],  # Dm
        [233.08, 293.66, 349.23],  # Bb
        [261.63, 329.63, 392.00],  # C
        [220.00, 261.63, 329.63],  # Am
    ]
    samples = []
    for chord_freqs in progressions:
        pad = envelope_adsr(chord(chord_freqs, 1.5), 0.15, 0.2, 0.5, 0.2)
        # Light rhythmic pulse
        for beat in range(3):
            tick = envelope_adsr(sine(chord_freqs[1] * 2, 0.1), 0.005, 0.03, 0.1, 0.04)
            pad = overlay_at(pad, scale(tick, 0.15), beat * 0.5)
        samples.extend(pad)
    peak = max(abs(s) for s in samples)
    if peak > 1.0:
        samples = [s / peak for s in samples]
    return scale(samples, 0.6)


def gen_music_combat_phase() -> list[float]:
    """Energetic driving rhythm ~6s."""
    duration = 6.0
    n = int(SAMPLE_RATE * duration)
    # Driving bass line
    bass_notes = [110, 130.81, 146.83, 130.81]  # A2 C3 D3 C3
    bass = []
    for note in bass_notes:
        seg = envelope_adsr(
            mix(sine(note, 1.5), scale(square(note, 1.5), 0.15)),
            0.01, 0.05, 0.6, 0.1
        )
        bass.extend(seg)

    # Kick drum pattern (every 0.375s = 160bpm)
    kick_pattern = silence(duration)
    bpm_interval = 0.375
    t = 0.0
    while t < duration - 0.1:
        kick = envelope_adsr(freq_sweep(150, 40, 0.08), 0.001, 0.02, 0.0, 0.03)
        kick_pattern = overlay_at(kick_pattern, scale(kick, 0.6), t)
        t += bpm_interval

    # Melody stabs
    melody = silence(duration)
    stab_times = [0.0, 0.75, 1.5, 2.25, 3.0, 3.75, 4.5, 5.25]
    stab_freqs = [440, 523.25, 587.33, 523.25, 440, 392.00, 440, 523.25]
    for st, sf in zip(stab_times, stab_freqs):
        stab = envelope_adsr(sine(sf, 0.15), 0.005, 0.03, 0.3, 0.05)
        melody = overlay_at(melody, scale(stab, 0.35), st)

    result = mix(scale(bass, 0.5), kick_pattern, scale(melody, 0.4))
    return scale(result, 0.7)


def gen_music_boss_combat() -> list[float]:
    """Intense dramatic ~6s. Minor key, heavy bass, tension."""
    duration = 6.0
    # E minor power chords
    power_chords = [
        [82.41, 123.47, 164.81],   # Em
        [73.42, 110.00, 146.83],   # D
        [65.41, 98.00, 130.81],    # C
        [73.42, 110.00, 146.83],   # D
    ]
    bass = []
    for pc in power_chords:
        seg = envelope_adsr(
            mix(sine(pc[0], 1.5), scale(square(pc[0], 1.5), 0.2), scale(sine(pc[1], 1.5), 0.5)),
            0.02, 0.1, 0.6, 0.15
        )
        bass.extend(seg)

    # Aggressive kick pattern
    drums = silence(duration)
    t = 0.0
    while t < duration - 0.1:
        kick = envelope_adsr(freq_sweep(200, 30, 0.1), 0.001, 0.02, 0.0, 0.04)
        drums = overlay_at(drums, scale(kick, 0.7), t)
        # Snare on off-beats
        if int(t / 0.3) % 2 == 1:
            snare = envelope_adsr(noise(0.06), 0.001, 0.015, 0.0, 0.02)
            drums = overlay_at(drums, scale(snare, 0.4), t)
        t += 0.3

    # Tension melody -- chromatic rises
    tension = silence(duration)
    for i in range(8):
        freq = 330 + i * 30
        note = envelope_adsr(sine(freq, 0.2), 0.01, 0.05, 0.3, 0.06)
        tension = overlay_at(tension, scale(note, 0.25), i * 0.7)

    result = mix(scale(bass, 0.5), drums, scale(tension, 0.3))
    return scale(result, 0.75)


def gen_music_victory() -> list[float]:
    """Triumphant fanfare ~4s."""
    # Rising major arpeggios with horn-like tones
    fanfare = silence(4.0)
    notes = [
        (0.0, 261.63, 0.3),   # C
        (0.25, 329.63, 0.3),  # E
        (0.5, 392.00, 0.3),   # G
        (0.75, 523.25, 0.5),  # C5
        (1.3, 587.33, 0.3),   # D5
        (1.6, 659.25, 0.5),   # E5
        (2.2, 783.99, 1.5),   # G5 (sustained)
    ]
    for t, freq, dur in notes:
        # "Horn" = sine + slight square for richness
        horn = envelope_adsr(
            mix(sine(freq, dur), scale(square(freq, dur), 0.1)),
            0.02, 0.05, 0.7, 0.15
        )
        fanfare = overlay_at(fanfare, scale(horn, 0.5), t)

    # Final chord
    final = envelope_adsr(chord([523.25, 659.25, 783.99], 1.5), 0.05, 0.2, 0.6, 0.5)
    fanfare = overlay_at(fanfare, scale(final, 0.4), 2.5)

    peak = max(abs(s) for s in fanfare)
    if peak > 1.0:
        fanfare = [s / peak for s in fanfare]
    return scale(fanfare, 0.8)


def gen_music_defeat() -> list[float]:
    """Somber, downward progression ~4s."""
    # Descending minor chords
    chords_list = [
        [329.63, 392.00, 493.88],  # Em
        [293.66, 349.23, 440.00],  # Dm
        [261.63, 311.13, 392.00],  # Cm
        [220.00, 261.63, 329.63],  # Am low
    ]
    samples = []
    for ch in chords_list:
        seg = envelope_adsr(chord(ch, 1.0), 0.1, 0.15, 0.4, 0.3)
        samples.extend(seg)

    # Add a slow descending single note on top
    desc = freq_sweep(600, 200, 4.0)
    desc = envelope_adsr(desc, 0.2, 0.5, 0.2, 1.0)
    result = mix(scale(samples, 0.6), scale(desc, 0.25))
    return scale(result, 0.7)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sfx_dir = os.path.join(project_root, "assets", "audio", "sfx")
    music_dir = os.path.join(project_root, "assets", "audio", "music")

    print("Generating SFX...")
    sfx_files = {
        "tower_place.wav": gen_tower_place,
        "tower_upgrade.wav": gen_tower_upgrade,
        "tower_sell.wav": gen_tower_sell,
        "tower_fuse.wav": gen_tower_fuse,
        "enemy_death.wav": gen_enemy_death,
        "enemy_leak.wav": gen_enemy_leak,
        "life_lost.wav": gen_life_lost,
        "wave_start.wav": gen_wave_start,
        "gold_clink.wav": gen_gold_clink,
        "ui_click.wav": gen_ui_click,
        # New F3 SFX
        "tower_shoot_fire.wav": gen_tower_shoot_fire,
        "tower_shoot_water.wav": gen_tower_shoot_water,
        "tower_shoot_earth.wav": gen_tower_shoot_earth,
        "tower_shoot_wind.wav": gen_tower_shoot_wind,
        "tower_shoot_lightning.wav": gen_tower_shoot_lightning,
        "tower_shoot_ice.wav": gen_tower_shoot_ice,
        "wave_clear.wav": gen_wave_clear,
        "error_buzz.wav": gen_error_buzz,
        "draft_pick.wav": gen_draft_pick,
        "synergy_activate.wav": gen_synergy_activate,
    }
    for name, gen_func in sfx_files.items():
        write_wav(os.path.join(sfx_dir, name), gen_func())

    print("\nGenerating Music...")
    music_files = {
        "menu.wav": gen_music_menu,
        "build_phase.wav": gen_music_build_phase,
        "combat_phase.wav": gen_music_combat_phase,
        "boss_combat.wav": gen_music_boss_combat,
        "victory.wav": gen_music_victory,
        "defeat.wav": gen_music_defeat,
    }
    for name, gen_func in music_files.items():
        write_wav(os.path.join(music_dir, name), gen_func())

    print("\nDone! All placeholder audio files generated.")


if __name__ == "__main__":
    main()
