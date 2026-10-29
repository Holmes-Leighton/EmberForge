#!/usr/bin/env python3
"""Synthesises EmberForge's original sound effects and music loops (no samples, no licences to worry about) into audio/*.wav.

Usage:  python tools/make_audio.py            (writes audio/)
Then:   python tools/upload_audio.py          (uploads them to Roblox and writes src/Shared/Data/AudioIds.lua)

Pure Python (wave + math), so it runs anywhere. Every sound is mono 16-bit at 22.05 kHz.
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")
rng = random.Random(7)


# ── building blocks ───────────────────────────────────────────────────────────
def osc(kind, freq, n, phase=0.0):
    out = []
    for i in range(n):
        t = (i / SR) * freq + phase
        f = t - math.floor(t)
        if kind == "sine":
            v = math.sin(2 * math.pi * t)
        elif kind == "tri":
            v = 4 * abs(f - 0.5) - 1
        elif kind == "square":
            v = 1.0 if f < 0.5 else -1.0
        elif kind == "saw":
            v = 2 * f - 1
        else:
            v = 0.0
        out.append(v)
    return out


def sweep(kind, f0, f1, n):
    """An oscillator whose pitch glides from f0 to f1 (exponentially)."""
    out, ph = [], 0.0
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n - 1))
        ph += f / SR
        t = ph - math.floor(ph)
        if kind == "sine":
            v = math.sin(2 * math.pi * ph)
        elif kind == "square":
            v = 1.0 if t < 0.5 else -1.0
        elif kind == "saw":
            v = 2 * t - 1
        else:
            v = 4 * abs(t - 0.5) - 1
        out.append(v)
    return out


def noise(n):
    return [rng.uniform(-1, 1) for _ in range(n)]


def lowpass(x, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def env(x, attack=0.005, decay=0.1, sustain=0.0, release=0.0, hold=0.0):
    """ADSR-ish: attack up, decay to sustain level, hold, then release to zero over the final `release` seconds."""
    n = len(x)
    a, d, r, h = int(attack * SR), int(decay * SR), int(release * SR), int(hold * SR)
    out = []
    for i, v in enumerate(x):
        if i < a:
            g = i / max(1, a)
        elif i < a + d:
            g = 1 - (1 - sustain) * ((i - a) / max(1, d))
        elif i < a + d + h:
            g = sustain
        else:
            g = sustain
        if r and i > n - r:
            g *= (n - i) / r
        out.append(v * g)
    return out


def expdecay(x, tau):
    return [v * math.exp(-i / SR / tau) for i, v in enumerate(x)]


def mix(*tracks, gains=None):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for k, t in enumerate(tracks):
        g = gains[k] if gains else 1.0
        for i, v in enumerate(t):
            out[i] += v * g
    return out


def place(base, x, at, gain=1.0):
    """Mix x into base starting `at` seconds in (growing base if needed)."""
    start = int(at * SR)
    need = start + len(x)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, v in enumerate(x):
        base[start + i] += v * gain
    return base


def note(freq, dur, kind="sine", tau=0.25, attack=0.004, harm=(1.0,)):
    n = int(dur * SR)
    out = [0.0] * n
    for k, h in enumerate(harm):
        w = osc(kind if k == 0 else "sine", freq * (k + 1), n)
        for i in range(n):
            out[i] += w[i] * h
    out = expdecay(out, tau)
    return env(out, attack=attack, decay=0, sustain=1.0, release=min(0.03, dur / 3))


def normalise(x, peak=0.85):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def fade_ends(x, ms=6):
    n = int(ms / 1000 * SR)
    for i in range(min(n, len(x))):
        g = i / n
        x[i] *= g
        x[-1 - i] *= g
    return x


def write(name, x, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    x = fade_ends(normalise(x, peak))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print("  %-16s %5.2fs  %s" % (name, len(x) / SR, os.path.relpath(path)))


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'A4' -> 440, 'C#5', 'Bb3'"""
    n = NOTE[name[0]]
    i = 1
    if name[i] == "#":
        n += 1; i += 1
    elif name[i] == "b":
        n -= 1; i += 1
    octave = int(name[i:])
    return 440.0 * 2 ** ((n - 9 + 12 * (octave - 4)) / 12)


# ── user interface ────────────────────────────────────────────────────────────
def click():
    n = int(0.05 * SR)
    t = expdecay(osc("sine", 1400, n), 0.012)
    p = expdecay(highpass(noise(n), 2000), 0.004)
    write("Click", mix(t, p, gains=[0.8, 0.3]))


def notify():
    x = []
    place(x, note(hz("E5"), 0.3, tau=0.12, harm=(1, 0.3)), 0)
    place(x, note(hz("A5"), 0.45, tau=0.18, harm=(1, 0.3)), 0.11)
    write("Notify", x)


def error():
    n = int(0.28 * SR)
    a = sweep("saw", 190, 120, n)
    b = sweep("square", 95, 70, n)
    write("Error", lowpass(env(mix(a, b, gains=[0.6, 0.4]), attack=0.005, decay=0.25, sustain=0.0), 1200))


def levelup():
    x = []
    for k, nm in enumerate(["C5", "E5", "G5", "C6"]):
        place(x, note(hz(nm), 0.5, tau=0.2, harm=(1, 0.4, 0.15)), k * 0.09)
    place(x, mix(note(hz("C6"), 0.9, tau=0.4, harm=(1, 0.4)), note(hz("E6"), 0.9, tau=0.4, harm=(1, 0.3)),
                 note(hz("G6"), 0.9, tau=0.4, harm=(1, 0.2))), 0.36, 0.7)
    write("LevelUp", x)


def achievement():
    x = []
    for k, nm in enumerate(["G4", "C5", "E5", "G5"]):
        place(x, note(hz(nm), 0.4, kind="tri", tau=0.18, harm=(1, 0.3)), k * 0.12)
    place(x, mix(note(hz("C5"), 1.0, kind="tri", tau=0.5, harm=(1, 0.3)), note(hz("G5"), 1.0, kind="tri", tau=0.5, harm=(1, 0.3)),
                 note(hz("C6"), 1.0, kind="tri", tau=0.5)), 0.5)
    write("Achievement", x)


# ── gameplay ──────────────────────────────────────────────────────────────────
def coin(name="CoinPop", f=1319.0, dur=0.22):
    n = int(dur * SR)
    a = expdecay(osc("sine", f, n), 0.06)
    b = expdecay(osc("sine", f * 1.5, n), 0.05)
    x = []
    place(x, mix(a, b, gains=[1, 0.5]), 0)
    place(x, mix(expdecay(osc("sine", f * 1.5, n), 0.08)), 0.06, 0.8)
    write(name, x)


def deploy():
    n = int(0.45 * SR)
    sw = lowpass(env(noise(n), attack=0.12, decay=0.3, sustain=0.0), 2500)
    th = expdecay(osc("sine", 70, n), 0.1)
    x = mix(sw, [0.0] * int(0.2 * SR) + th[: n - int(0.2 * SR)], gains=[0.7, 0.9])
    write("Deploy", x)


def clang(name, rare):
    x = []
    n = int(1.2 * SR)
    for f, g, tau in ((540, 1.0, 0.35), (1210, 0.6, 0.25), (1830, 0.4, 0.18), (2790, 0.25, 0.12)):
        place(x, expdecay(osc("sine", f, n), tau), 0, g)
    place(x, expdecay(highpass(noise(int(0.05 * SR)), 1500), 0.01), 0, 0.6)
    if rare:
        for k, nm in enumerate(["C6", "E6", "G6", "C7"]):
            place(x, note(hz(nm), 0.4, tau=0.15, harm=(1, 0.3)), 0.15 + k * 0.07, 0.5)
    write(name, x)


def neon():
    n = int(1.0 * SR)
    a = sweep("sine", 400, 1800, n)
    b = sweep("tri", 600, 2400, n)
    x = env(mix(a, b, gains=[0.7, 0.4]), attack=0.1, decay=0.8, sustain=0.0)
    sp = []
    for k in range(10):
        place(sp, expdecay(osc("sine", 2000 + 400 * k, int(0.1 * SR)), 0.03), 0.3 + k * 0.05, 0.3)
    write("Neon", mix(x, sp))


def smelt():
    n = int(0.9 * SR)
    hiss = env(highpass(noise(n), 3000), attack=0.05, decay=0.6, sustain=0.2, release=0.3)
    bub = []
    for k in range(6):
        f = rng.uniform(250, 520)
        m = int(0.08 * SR)
        place(bub, expdecay(sweep("sine", f, f * 1.8, m), 0.025), rng.uniform(0, 0.7), 0.7)
    write("Smelt", mix(hiss, bub, gains=[0.35, 1.0]))


def tradedone():
    x = []
    for k in range(7):
        place(x, note(hz("E6") * (1 + 0.04 * (k % 3)), 0.2, tau=0.07, harm=(1, 0.4)), k * 0.06, 0.8)
    place(x, note(hz("A6"), 0.5, tau=0.2, harm=(1, 0.3)), 0.45)
    write("TradeDone", x)


def chest():
    x = []
    n = int(0.35 * SR)
    place(x, expdecay(osc("sine", 110, n), 0.1), 0, 1.0)
    place(x, lowpass(env(noise(n), attack=0.02, decay=0.25), 1800), 0.0, 0.4)
    for k, nm in enumerate(["G5", "B5", "D6", "G6", "B6"]):
        place(x, note(hz(nm), 0.5, tau=0.2, harm=(1, 0.4, 0.2)), 0.2 + k * 0.07, 0.8)
    place(x, mix(note(hz("G6"), 1.2, tau=0.6, harm=(1, 0.3)), note(hz("D7"), 1.2, tau=0.6)), 0.6, 0.6)
    write("RewardChest", x)


# ── Sky Tower ─────────────────────────────────────────────────────────────────
def tower_level():
    x = []
    place(x, note(hz("C6"), 0.35, tau=0.1, harm=(1, 0.4)), 0)
    place(x, note(hz("G6"), 0.5, tau=0.15, harm=(1, 0.3)), 0.07)
    write("TowerLevel", x)


def tower_fall():
    n = int(0.9 * SR)
    sl = env(sweep("tri", 900, 90, n), attack=0.01, decay=0.8, sustain=0.0)
    th = [0.0] * int(0.65 * SR) + expdecay(osc("sine", 60, int(0.4 * SR)), 0.08)
    write("TowerFall", mix(sl, th, gains=[0.7, 1.0]))


def tower_start():
    n = int(1.0 * SR)
    sw = env(lowpass(noise(n), 3000), attack=0.7, decay=0.3, sustain=0.0)
    rise = env(sweep("saw", 120, 600, n), attack=0.6, decay=0.4, sustain=0.0)
    x = mix(sw, lowpass(rise, 1500), gains=[0.5, 0.6])
    place(x, note(hz("C6"), 0.5, tau=0.2, harm=(1, 0.4)), 0.85)
    write("TowerStart", x)


def tower_summit():
    x = []
    for k, nm in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        place(x, note(hz(nm), 0.6, kind="tri", tau=0.3, harm=(1, 0.4, 0.2)), k * 0.1)
    for nm in ("C5", "E5", "G5", "C6"):
        place(x, note(hz(nm), 1.8, kind="tri", tau=0.9, harm=(1, 0.3)), 0.7, 0.55)
    for k in range(14):
        place(x, expdecay(osc("sine", rng.uniform(2200, 4200), int(0.12 * SR)), 0.04), 0.7 + k * 0.08, 0.25)
    write("TowerSummit", x)


def bounce():
    n = int(0.35 * SR)
    write("TowerBounce", env(sweep("sine", 180, 760, n), attack=0.003, decay=0.3, sustain=0.0))


# ── Hollow Maze ───────────────────────────────────────────────────────────────
def roar():
    n = int(1.8 * SR)
    f = sweep("saw", 70, 45, n)
    g = sweep("square", 52, 38, n)
    ns = lowpass(noise(n), 700)
    wob = [0.6 + 0.4 * math.sin(2 * math.pi * 11 * i / SR) for i in range(n)]
    x = [(a * 0.5 + b * 0.35 + c * 0.6) * w for a, b, c, w in zip(f, g, ns, wob)]
    x = lowpass(x, 900)
    write("MazeRoar", env(x, attack=0.15, decay=1.2, sustain=0.5, release=0.5))


def footstep():
    n = int(0.22 * SR)
    th = expdecay(osc("sine", 62, n), 0.05)
    sc = expdecay(lowpass(noise(n), 500), 0.035)
    write("MazeFootstep", mix(th, sc, gains=[1.0, 0.7]))


def heartbeat():
    x = []
    for at, g in ((0.0, 1.0), (0.22, 0.75)):
        n = int(0.2 * SR)
        place(x, expdecay(sweep("sine", 90, 48, n), 0.07), at, g)
    x.extend([0.0] * int(0.4 * SR))
    write("MazeHeartbeat", x)


def caught():
    n = int(1.3 * SR)
    sl = env(sweep("saw", 300, 50, n), attack=0.005, decay=1.2, sustain=0.0)
    th = expdecay(osc("sine", 55, n), 0.2)
    ns = expdecay(lowpass(noise(n), 1500), 0.1)
    write("MazeCaught", lowpass(mix(sl, th, ns, gains=[0.5, 1.0, 0.5]), 2500))


def escape():
    x = []
    for k, nm in enumerate(["G4", "B4", "D5", "G5", "B5", "D6"]):
        place(x, note(hz(nm), 0.5, kind="tri", tau=0.25, harm=(1, 0.4, 0.2)), k * 0.09)
    place(x, mix(note(hz("G5"), 1.6, kind="tri", tau=0.8, harm=(1, 0.3)), note(hz("D6"), 1.6, kind="tri", tau=0.8),
                 note(hz("B5"), 1.6, kind="tri", tau=0.8)), 0.55, 0.7)
    write("MazeEscape", x)


def maze_pickup():
    x = []
    for k, nm in enumerate(["E6", "G6", "B6", "E7"]):
        place(x, note(hz(nm), 0.3, tau=0.1, harm=(1, 0.3)), k * 0.05)
    write("MazePickup", x)


def hide():
    n = int(0.5 * SR)
    write("MazeHide", env(lowpass(noise(n), 900), attack=0.2, decay=0.3, sustain=0.0))


def freeze():
    x = []
    for k in range(9):
        place(x, expdecay(osc("sine", rng.uniform(2800, 5200), int(0.25 * SR)), 0.07), k * 0.045, 0.5)
    place(x, expdecay(highpass(noise(int(0.3 * SR)), 4000), 0.08), 0, 0.4)
    write("MazeFreeze", x)


def zap():
    n = int(0.5 * SR)
    a = sweep("saw", 1800, 200, n)
    b = highpass(noise(n), 2500)
    x = mix(a, b, gains=[0.5, 0.7])
    x = [v * (1 if int(i / SR * 60) % 2 == 0 else 0.4) for i, v in enumerate(x)]
    write("MazeStun", env(x, attack=0.002, decay=0.45, sustain=0.0))


def flash():
    n = int(0.9 * SR)
    sh = sweep("sine", 500, 1500, n)
    write("MazeLight", env(mix(sh, [0.4 * v for v in sweep("tri", 1000, 3000, n)]), attack=0.05, decay=0.8, sustain=0.0))


def thunder():
    n = int(1.6 * SR)
    ns = lowpass(noise(n), 300)
    write("MazeThunder", env(ns, attack=0.05, decay=1.4, sustain=0.0))


# ── ambience and music (loops) ────────────────────────────────────────────────
def pad_chord(freqs, dur, tau=None):
    n = int(dur * SR)
    out = [0.0] * n
    for f in freqs:
        for det in (-0.4, 0.4):
            w = osc("tri", f + det, n)
            for i in range(n):
                out[i] += w[i] * 0.2
    return lowpass(out, 1400)


def loop_seam(x, ms=120):
    """Crossfade the tail into the head so the loop has no click."""
    n = int(ms / 1000 * SR)
    head, tail = x[:n], x[-n:]
    body = x[: len(x) - n]
    for i in range(n):
        g = i / n
        body[i] = head[i] * g + tail[i] * (1 - g)
    return body


def music(name, bpm, bars, chords, lead, bass_kind, pad_gain, pluck_gain, drum=False, mood="major"):
    beat = 60.0 / bpm
    bar = 4 * beat
    total = bars * bar
    n = int(total * SR) + int(0.5 * SR)
    x = [0.0] * n
    for b in range(bars):
        ch = chords[b % len(chords)]
        t0 = b * bar
        pad = pad_chord([hz(c) for c in ch], bar + 0.4)
        place(x, [v * pad_gain for v in env(pad, attack=0.3, decay=0, sustain=1.0, release=0.4)], t0)
        # bass: root on every beat pair
        root = hz(ch[0]) / 2
        for k in range(4):
            if bass_kind == "walk" or k % 2 == 0:
                place(x, note(root * (1 if k != 3 else 1.5), beat * 0.9, kind="tri", tau=0.3), t0 + k * beat, 0.5)
        # arpeggio pluck
        steps = 8
        for k in range(steps):
            f = hz(ch[k % len(ch)]) * (2 if (k // len(ch)) % 2 == 0 else 1)
            place(x, note(f, beat * 0.5, kind="tri", tau=0.16, harm=(1, 0.3)), t0 + k * beat / 2, pluck_gain)
        if drum:
            for k in range(4):
                n_k = int(0.12 * SR)
                place(x, expdecay(sweep("sine", 130, 50, n_k), 0.05), t0 + k * beat, 0.7)
                if k % 2 == 1:
                    place(x, expdecay(highpass(noise(int(0.1 * SR)), 1800), 0.04), t0 + k * beat, 0.35)
            for k in range(8):
                place(x, expdecay(highpass(noise(int(0.04 * SR)), 5000), 0.01), t0 + k * beat / 2 + beat / 4, 0.12)
        # a little lead melody, one phrase per bar
        phrase = lead[b % len(lead)]
        for k, (nm, ln) in enumerate(phrase):
            if nm:
                place(x, note(hz(nm), ln * beat, kind="sine", tau=0.4, harm=(1, 0.25)), t0 + sum(l for _, l in phrase[:k]) * beat, 0.45)
    x = x[: int(total * SR) + int(0.15 * SR)]
    write(name, loop_seam(x), peak=0.6)


def ambient_forge():
    dur = 18.0
    n = int(dur * SR)
    low = lowpass(noise(n), 180)
    low = [v * (0.7 + 0.3 * math.sin(2 * math.pi * 0.17 * i / SR)) for i, v in enumerate(low)]
    x = [v * 1.2 for v in low]
    # a quiet crackle and the odd distant clang / drip
    for _ in range(40):
        place(x, expdecay(highpass(noise(int(0.03 * SR)), 2500), 0.008), rng.uniform(0, dur - 0.1), rng.uniform(0.04, 0.12))
    for _ in range(5):
        place(x, expdecay(osc("sine", rng.uniform(900, 1600), int(0.5 * SR)), 0.12), rng.uniform(0, dur - 0.6), 0.05)
    hum = osc("sine", 55, n)
    x = mix(x, hum, gains=[1.0, 0.18])
    write("AmbientForge", loop_seam(x, 400), peak=0.5)


def maze_drone():
    dur = 20.0
    n = int(dur * SR)
    a = osc("saw", 41.2, n)
    b = osc("saw", 41.9, n)
    c = osc("tri", 61.7, n)
    x = lowpass(mix(a, b, c, gains=[0.4, 0.4, 0.3]), 260)
    x = [v * (0.65 + 0.35 * math.sin(2 * math.pi * 0.11 * i / SR)) for i, v in enumerate(x)]
    for at in (3.0, 9.5, 15.0):
        place(x, note(hz("E6"), 1.6, tau=0.7, harm=(1, 0.2)), at, 0.07)
    for k in range(int(dur / 1.6)):
        place(x, expdecay(sweep("sine", 80, 45, int(0.2 * SR)), 0.07), k * 1.6, 0.25)
    write("MusicMaze", loop_seam(x, 400), peak=0.55)


def main():
    print("Writing audio to", OUT)
    click(); notify(); error(); levelup(); achievement()
    coin("Collect", 1175.0, 0.2); coin("CoinPop", 1568.0, 0.14)
    deploy(); clang("Craft", False); clang("CraftRare", True); neon(); smelt(); tradedone(); chest()
    tower_level(); tower_fall(); tower_start(); tower_summit(); bounce()
    roar(); footstep(); heartbeat(); caught(); escape(); maze_pickup(); hide(); freeze(); zap(); flash(); thunder()
    ambient_forge()
    # hub: warm, unhurried; tower: bright and driving; maze: a dark drone
    music("Music", 92, 8, [("A3", "C4", "E4"), ("F3", "A3", "C4"), ("C4", "E4", "G4"), ("G3", "B3", "D4")],
          [[("E5", 2), ("D5", 1), ("C5", 1)], [("A5", 1.5), (None, 0.5), ("G5", 2)], [("E5", 1), ("G5", 1), ("C6", 2)], [("B5", 2), (None, 2)]],
          "root", 0.5, 0.35)
    music("MusicTower", 124, 8, [("C4", "E4", "G4"), ("G3", "B3", "D4"), ("A3", "C4", "E4"), ("F3", "A3", "C4")],
          [[("G5", 1), ("E5", 1), ("C6", 2)], [("D6", 1), ("B5", 1), ("G5", 2)], [("E6", 1), ("C6", 1), ("A5", 2)], [("C6", 2), ("A5", 1), ("F5", 1)]],
          "walk", 0.4, 0.4, drum=True)
    maze_drone()
    print("Done.")


if __name__ == "__main__":
    main()
