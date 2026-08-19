#!/usr/bin/env python3
"""Procedural sound effect generator for SpaceTrader.

Modern sci-fi synthesis, not chiptune. Every effect is built from layers -
a transient that gives the attack its edge, a tonal body that carries the
identity, a sub layer for weight - then run through resonant filters,
saturation, convolution reverb and a stereo widener.

Deliberately avoided: bare square/saw waves, chiptune arpeggios and dry
mono blips. Those read as 1980s hardware, which clashes with the game's
rendered backgrounds and 3D shaders.

Output is 16-bit stereo WAV at 48 kHz, which Godot imports natively.

Usage:
    python3 tools/generate_sfx.py                 # all effects -> assets/audio/sfx/
    python3 tools/generate_sfx.py laser explosion # only these two
    python3 tools/generate_sfx.py --out /tmp/try  # write somewhere else

Requires numpy.
"""

import os
import sys
import wave

import numpy as np

SR = 48000
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")


# ------------------------------------------------------------------ helpers

def ns(dur: float) -> int:
    """Seconds -> sample count."""
    return max(int(round(dur * SR)), 2)


def line(a, b, n, curve=1.0):
    """Linear-in-shape ramp; curve < 1 moves fast then settles, > 1 the reverse."""
    return a + (b - a) * (np.linspace(0.0, 1.0, n) ** curve)


def sweep(f0, f1, n):
    """Exponential frequency sweep - how pitch actually reads to the ear."""
    return f0 * (float(f1) / float(f0)) ** np.linspace(0.0, 1.0, n)


def sine(freq, n):
    phase = np.cumsum(np.broadcast_to(np.asarray(freq, dtype=float), (n,))) / SR
    return np.sin(2.0 * np.pi * phase)


def noise(n, seed=0):
    """Gaussian noise - smoother and less 'digital' than uniform."""
    return np.random.default_rng(seed).standard_normal(n) * 0.4


def env(n, attack=0.003, hold=0.0, curve=4.0):
    """Attack (raised cosine) / hold / exponential decay filling exactly n samples."""
    a = max(ns(attack), 1) if attack > 0 else 1
    h = ns(hold) if hold > 0 else 0
    d = max(n - a - h, 1)
    rise = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, a))
    flat = np.ones(h)
    x = np.linspace(0.0, 1.0, d)
    fall = (np.exp(-curve * x) - np.exp(-curve)) / (1.0 - np.exp(-curve))
    return np.concatenate([rise, flat, fall])[:n]


def svf(x, cutoff, q=0.7, mode="lp"):
    """Time-varying state variable filter (TPT topology).

    Resonance is what makes a sweep sound like a filter rather than a fade,
    so this replaces the flat one-pole used before.
    """
    n = len(x)
    fc = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)), 20.0, SR * 0.45)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / max(q, 0.05)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    out = np.empty(n)
    ic1 = 0.0
    ic2 = 0.0
    for i in range(n):
        v3 = x[i] - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = v1
        else:  # hp
            out[i] = x[i] - k * v1 - v2
    return out


def fm(carrier, ratio, index, n):
    """Frequency modulation - the workhorse for energy weapons and glassy bells."""
    carrier = np.broadcast_to(np.asarray(carrier, dtype=float), (n,))
    modulator = sine(carrier * ratio, n)
    phase = np.cumsum(carrier) / SR
    return np.sin(2.0 * np.pi * phase + np.asarray(index) * modulator)


def bell(f0, n, partials=None, curve=5.0):
    """Inharmonic additive tone. Real metal and glass are not harmonic stacks."""
    if partials is None:
        partials = ((1.00, 1.00, 1.00), (2.76, 0.45, 0.75), (5.40, 0.22, 0.50), (8.93, 0.10, 0.35))
    out = np.zeros(n)
    for ratio, amp, decay_scale in partials:
        out += amp * sine(np.full(n, f0 * ratio), n) * env(n, 0.0015, 0.0, curve / max(decay_scale, 0.05))
    return out / 1.6


def saturate(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def layers(*parts):
    """Sum layers of differing length."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def _impulse_response(dur, decay_curve, damp, seed):
    n = ns(dur)
    ir = noise(n, seed) * np.exp(-decay_curve * np.linspace(0.0, 1.0, n))
    ir = svf(ir, damp, 0.5, "lp")
    ir[:64] *= np.linspace(0.0, 1.0, 64)
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)


def _fft_convolve(x, ir):
    n = len(x) + len(ir) - 1
    size = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def reverb(x, mix=0.25, dur=0.6, damp=5000, seed=1, decay_curve=6.0):
    """Convolution reverb against a synthetic impulse response.

    The tail is what separates a sound happening *somewhere* from a dry blip,
    and it extends the returned array past the dry signal on purpose.
    """
    wet = _fft_convolve(x, _impulse_response(dur, decay_curve, damp, seed))
    out = np.zeros(len(wet))
    out[:len(x)] = x
    return out * (1.0 - mix) + wet * mix


def widen(x, amount=0.35, seed=7, smear=0.012):
    """Mid/side widening. The side channel is a short decorrelated copy, so the
    image opens up without hard panning and the mono sum stays intact."""
    side = _fft_convolve(x, _impulse_response(smear, 10.0, 7000, seed))[:len(x)]
    side -= np.mean(side)
    rms_x = np.sqrt(np.mean(x ** 2)) + 1e-9
    rms_s = np.sqrt(np.mean(side ** 2)) + 1e-9
    side *= rms_x / rms_s
    return np.stack([x + amount * side, x - amount * side], axis=1)


# ------------------------------------------------------------------ effects

def ui_click():
    """Muted, dark UI tick. Fires on every button, so it stays understated."""
    n = ns(0.05)
    tick = svf(noise(n, 3), line(6000, 1400, n), 0.9, "bp") * env(n, 0.0005, 0.0, 9.0) * 0.6
    body = (sine(line(520, 380, n), n) + 0.4 * sine(line(1180, 900, n), n)) * env(n, 0.001, 0.0, 8.0)
    x = svf(layers(tick, body * 0.7), 5200, 0.7, "lp")
    x = reverb(x, 0.12, 0.09, 4500, 21, 9.0)
    return widen(x, 0.12, 5), 0.30


def ui_denied():
    """Rejected click (locked building, action already used this landing).

    Darker and duller than ui_click, with a slight downward drop - it has to
    read as 'no' without sounding like an error alarm.
    """
    n = ns(0.16)
    body = (sine(sweep(300, 170, n), n) + 0.5 * sine(sweep(150, 85, n), n)) * env(n, 0.004, 0.01, 5.5)
    thud = svf(noise(n, 301), line(900, 200, n), 0.8, "lp") * env(n, 0.001, 0.0, 8.0) * 0.35
    x = svf(saturate(layers(body, thud), 1.3), 2200, 0.7, "lp")
    x = reverb(x, 0.18, 0.25, 2200, 307, 7.0)
    return widen(x, 0.15, 33), 0.34


def card_play():
    """Card leaving the hand: an air swipe with a soft snap at the end."""
    n = ns(0.20)
    swipe = svf(noise(n, 11), sweep(500, 4200, n), 1.4, "bp") * env(n, 0.02, 0.02, 3.0)
    air = svf(noise(n, 12), 9000, 0.6, "hp") * env(n, 0.03, 0.0, 5.0) * 0.15
    snap_n = ns(0.04)
    snap = svf(noise(snap_n, 13), line(3000, 900, snap_n), 1.2, "bp") * env(snap_n, 0.001, 0.0, 10.0)
    x = layers(swipe, air)
    x[-snap_n:] += snap * 0.5
    x = reverb(x, 0.16, 0.22, 5000, 23, 7.0)
    return widen(x, 0.40, 9), 0.42


def card_draw():
    """Card arriving: same family, reversed direction, lighter."""
    n = ns(0.15)
    swipe = svf(noise(n, 17), sweep(4600, 700, n), 1.3, "bp") * env(n, 0.008, 0.0, 4.5)
    air = svf(noise(n, 18), 7000, 0.6, "hp") * env(n, 0.004, 0.0, 8.0) * 0.2
    x = reverb(layers(swipe, air), 0.14, 0.18, 5500, 29, 8.0)
    return widen(x, 0.35, 10), 0.38


def laser():
    """Player weapon: FM energy discharge, bright transient, sub for weight."""
    n = ns(0.30)
    carrier = sweep(1500, 220, n)
    body = fm(carrier, 1.48, line(7.0, 0.7, n, 0.5), n) * env(n, 0.002, 0.01, 5.0)
    zap = svf(noise(n, 31), sweep(9000, 1500, n), 2.2, "bp") * env(n, 0.001, 0.0, 8.0) * 0.35
    sub = sine(sweep(180, 55, n), n) * env(n, 0.002, 0.02, 6.0) * 0.5
    x = saturate(layers(body, zap, sub), 1.8)
    x = reverb(x, 0.20, 0.35, 6000, 41, 8.0)
    return widen(x, 0.30, 11), 0.62


def enemy_laser():
    """Incoming fire: lower, dirtier, more noise - reads as 'not yours'."""
    n = ns(0.34)
    carrier = sweep(760, 105, n)
    body = fm(carrier, 2.02, line(9.0, 1.2, n, 0.5), n) * env(n, 0.003, 0.02, 4.5)
    grit = svf(noise(n, 37), sweep(4000, 700, n), 1.5, "bp") * env(n, 0.002, 0.01, 6.0) * 0.5
    sub = sine(sweep(140, 42, n), n) * env(n, 0.003, 0.03, 5.0) * 0.6
    x = saturate(layers(body, grit, sub), 2.6)
    x = reverb(x, 0.24, 0.45, 4000, 43, 7.0)
    return widen(x, 0.30, 12), 0.58


def shield_hit():
    """Shield absorbs the hit: glassy inharmonic ring, high-passed - no low end,
    because nothing physical was struck."""
    n = ns(0.35)
    ring = bell(1450, n, curve=6.0) * 0.8
    fizz = svf(noise(n, 53), sweep(6000, 2200, n), 1.8, "bp") * env(n, 0.002, 0.01, 5.0) * 0.4
    swell = sine(sweep(2600, 1200, n), n) * env(n, 0.004, 0.0, 7.0) * 0.3
    x = svf(layers(ring, fizz, swell), 320, 0.7, "hp")
    x = reverb(x, 0.30, 0.50, 7000, 59, 6.0)
    return widen(x, 0.45, 13), 0.50


def hull_hit():
    """Hull damage: sub thump plus saturated crunch and a dull metal ring."""
    n = ns(0.45)
    thump = sine(sweep(150, 42, n), n) * env(n, 0.002, 0.01, 4.5)
    crunch = saturate(svf(noise(n, 61), sweep(2200, 200, n), 1.1, "lp"), 2.5) * env(n, 0.001, 0.02, 5.0) * 0.7
    metal = bell(260, n, curve=9.0) * 0.25
    x = saturate(layers(thump, crunch, metal), 1.6)
    x = reverb(x, 0.22, 0.55, 3000, 67, 7.0)
    return widen(x, 0.30, 15), 0.72


def explosion():
    """Ship destroyed: filtered noise body, sub boom, and debris crackle
    scattered through the tail so it does not end as one flat whoosh."""
    n = ns(1.0)
    body = saturate(svf(noise(n, 71), sweep(7000, 130, n), 1.3, "lp") * env(n, 0.004, 0.05, 3.2), 2.2)
    sub = sine(sweep(110, 28, n), n) * env(n, 0.006, 0.08, 3.0) * 0.9
    rng = np.random.default_rng(73)
    debris = np.zeros(n)
    grain = ns(0.01)
    for i in range(90):
        pos = int(abs(rng.normal(0.35, 0.25)) * n) % n
        if pos + grain < n:
            debris[pos:pos + grain] += noise(grain, 100 + i) * env(grain, 0.0005, 0.0, 10.0) * rng.uniform(0.05, 0.25)
    debris = svf(debris, 4000, 1.0, "bp")
    x = reverb(layers(body, sub, debris * 0.6), 0.35, 1.30, 2500, 79, 5.0)
    return widen(x, 0.50, 17), 0.90


def _soft_note(freq, n, amp=1.0):
    core = 0.7 * sine(np.full(n, freq), n) + 0.18 * sine(np.full(n, freq * 2.0), n) + 0.06 * sine(np.full(n, freq * 3.01), n)
    shimmer = fm(np.full(n, freq * 4.0), 1.0, line(1.2, 0.1, n), n) * 0.08
    return (core + shimmer) * env(n, 0.006, 0.02, 4.0) * amp


def purchase():
    """Buy confirmation: two soft overlapping notes, not an arpeggio."""
    n1 = ns(0.16)
    n2 = ns(0.42)
    offset = n1 - ns(0.02)
    x = np.zeros(offset + n2)
    x[:n1] += _soft_note(659.25, n1, 0.7)
    x[offset:offset + n2] += _soft_note(987.77, n2, 1.0)
    x = reverb(x, 0.28, 0.60, 6500, 83, 6.0)
    return widen(x, 0.35, 19), 0.48


def sell():
    """Credits received: three metallic bell hits, bright and inharmonic."""
    total = ns(0.70)
    x = np.zeros(total)
    for offset, freq, amp in ((0.000, 1320.0, 1.0), (0.055, 1760.0, 0.8), (0.110, 2200.0, 0.55)):
        n = ns(0.50)
        hit = bell(freq, n, curve=7.0) * amp
        p = ns(offset) if offset > 0 else 0
        room = min(n, total - p)
        x[p:p + room] += hit[:room]
    x = svf(x, 400, 0.7, "hp")
    x = reverb(x, 0.30, 0.70, 7000, 97, 5.5)
    return widen(x, 0.40, 21), 0.46


def casino_spin():
    """Slot reel: soft mechanical ticks decelerating towards the result."""
    total = ns(1.35)
    x = np.zeros(total)
    t = 0.0
    gap = 0.05
    i = 0
    while t < 1.25:
        p = ns(t) if t > 0 else 0
        tn = ns(0.03)
        tick = svf(noise(tn, 200 + i), line(2600, 800, tn), 1.6, "bp") * env(tn, 0.0008, 0.0, 9.0)
        body = sine(line(700, 480, tn), tn) * env(tn, 0.001, 0.0, 9.0) * 0.4
        if p + tn <= total:
            x[p:p + tn] += tick + body
        t += gap
        gap *= 1.14
        i += 1
    x = reverb(x, 0.15, 0.25, 4000, 101, 8.0)
    return widen(x, 0.30, 23), 0.40


def casino_win():
    """Jackpot: glassy bell run over a rising shimmer."""
    total = ns(1.70)
    x = np.zeros(total)
    glass = ((1.00, 1.00, 1.00), (2.00, 0.40, 0.80), (3.01, 0.20, 0.60), (4.70, 0.08, 0.40))
    for offset, freq in ((0.00, 659.25), (0.12, 987.77), (0.24, 1318.51), (0.40, 1760.00)):
        n = ns(1.0)
        p = ns(offset) if offset > 0 else 0
        room = min(n, total - p)
        x[p:p + room] += bell(freq, n, glass, 4.0)[:room] * 0.8
    rise_n = ns(0.50)
    x[:rise_n] += svf(noise(rise_n, 103), sweep(1200, 9000, rise_n), 1.5, "bp") * env(rise_n, 0.30, 0.0, 4.0) * 0.25
    x = reverb(x, 0.35, 1.10, 8000, 107, 5.0)
    return widen(x, 0.45, 25), 0.55


def casino_lose():
    """Losing spin: dark descending drop. Disappointing without being comic."""
    n = ns(0.60)
    low = (0.8 * sine(sweep(320, 110, n), n) + 0.5 * sine(sweep(160, 55, n), n)) * env(n, 0.01, 0.05, 4.0)
    air = svf(noise(n, 109), sweep(2000, 300, n), 0.9, "lp") * env(n, 0.02, 0.0, 4.5) * 0.3
    x = saturate(layers(low, air), 1.4)
    x = reverb(x, 0.25, 0.70, 2500, 113, 6.0)
    return widen(x, 0.25, 27), 0.45


def travel():
    """Hyperspace departure: air rushing up over a saturated engine ramp."""
    n = ns(2.00)
    air = svf(noise(n, 127), sweep(200, 6000, n), 1.2, "bp") * line(0.05, 1.0, n, 2.0)
    engine = saturate((0.6 * sine(sweep(50, 300, n), n) + 0.3 * sine(sweep(75, 452, n), n)) * line(0.1, 1.0, n, 1.6), 2.0)
    x = layers(air * 0.8, engine * 0.7) * env(n, 1.40, 0.0, 3.0)
    x = reverb(x, 0.30, 1.00, 5000, 131, 5.0)
    return widen(x, 0.55, 29), 0.55


def arrive():
    """Arrival: the departure gesture inverted, settling onto a low pad."""
    n = ns(1.50)
    air = svf(noise(n, 137), sweep(5000, 300, n), 1.0, "bp") * env(n, 0.06, 0.10, 3.0)
    engine = sine(sweep(260, 70, n), n) * env(n, 0.05, 0.0, 3.5) * 0.6
    pad = (0.4 * sine(np.full(n, 110.0), n) + 0.25 * sine(np.full(n, 165.0), n)) * env(n, 0.40, 0.20, 4.0) * 0.3
    x = reverb(layers(air * 0.7, engine, pad), 0.32, 1.00, 4000, 139, 5.5)
    return widen(x, 0.50, 31), 0.50


EFFECTS = {
    "ui_click": ui_click,
    "ui_denied": ui_denied,
    "card_play": card_play,
    "card_draw": card_draw,
    "laser": laser,
    "enemy_laser": enemy_laser,
    "shield_hit": shield_hit,
    "hull_hit": hull_hit,
    "explosion": explosion,
    "purchase": purchase,
    "sell": sell,
    "casino_spin": casino_spin,
    "casino_win": casino_win,
    "casino_lose": casino_lose,
    "travel": travel,
    "arrive": arrive,
}


# -------------------------------------------------------------------- output

def write_wav(path, samples, gain):
    x = np.atleast_2d(np.asarray(samples, dtype=float))
    if x.shape[0] == 2 and x.shape[1] != 2:
        x = x.T
    if x.ndim == 1 or x.shape[1] == 1:
        x = np.column_stack([x.ravel(), x.ravel()])

    # Kill DC and subsonic rumble that saturation and sub layers leave behind.
    for c in range(x.shape[1]):
        x[:, c] = svf(x[:, c], 28.0, 0.7, "hp")

    peak = float(np.max(np.abs(x)))
    if peak > 0.0:
        x = x / peak * gain

    # A convolution tail decays towards silence but never reaches it, which
    # otherwise leaves seconds of inaudible data in every file.
    audible = np.abs(x).max(axis=1) > gain * 0.0015
    if audible.any():
        x = x[:int(np.flatnonzero(audible)[-1]) + ns(0.02)]

    fade = min(ns(0.004), len(x) // 4)
    if fade > 1:
        x[:fade] *= np.linspace(0.0, 1.0, fade)[:, None]
        x[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
    return len(x) / SR


def main(argv):
    out_dir = DEFAULT_OUT
    names = []
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out_dir = argv[i + 1]
            i += 2
            continue
        names.append(argv[i])
        i += 1

    unknown = [n for n in names if n not in EFFECTS]
    if unknown:
        print("unknown effect(s): %s" % ", ".join(unknown))
        print("available: %s" % ", ".join(EFFECTS))
        return 1

    for name in (names or list(EFFECTS)):
        samples, gain = EFFECTS[name]()
        dur = write_wav(os.path.join(out_dir, name + ".wav"), samples, gain)
        print("%-14s %5.2fs" % (name, dur))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
