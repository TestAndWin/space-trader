"""Render a MIDI background track to a seamless stereo loop WAV.

Usage:
    python3 tools/render_midi_loop.py <in.mid> <out.wav>
    oggenc -q 5 -o assets/audio/bgm/<name>.ogg <out.wav>

Godot cannot play MIDI (it only reads MIDI *input* devices), so the tracks in
assets/audio/*.mid are source material that has to be rendered to Ogg Vorbis.

No SoundFont available, so each MIDI track gets a hand-built additive voice
matching its General MIDI role (warm pad, bass, harp pluck, celesta, halo pad).
The tail past the loop point is wrapped back onto the start, so reverb and
release ring across the loop seam instead of cutting off.
"""
import math
import struct
import sys
import wave

import numpy as np

SR = 44100
LOOP = 32.0          # 4 bars at 60 BPM
TAIL = 8.0           # rendered past the loop point, then wrapped back in




def read_vlq(d, i):
    v = 0
    while True:
        b = d[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        if not b & 0x80:
            return v, i


def parse(path):
    d = open(path, 'rb').read()
    fmt, ntrk, div = struct.unpack('>HHH', d[8:14])
    i, tempo, tracks = 14, 500000, []
    for _ in range(ntrk):
        ln = struct.unpack('>I', d[i + 4:i + 8])[0]
        end, j, tick, name, running = i + 8 + ln, i + 8, 0, '', None
        events = []
        while j < end:
            dt, j = read_vlq(d, j)
            tick += dt
            b = d[j]
            if b == 0xFF:
                mt = d[j + 1]
                ln2, j2 = read_vlq(d, j + 2)
                data = d[j2:j2 + ln2]
                if mt == 0x03:
                    name = data.decode('utf-8', 'replace')
                if mt == 0x51:
                    tempo = int.from_bytes(data, 'big')
                j = j2 + ln2
                continue
            if b & 0x80:
                running = b
                j += 1
            st = running & 0xF0
            if st in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                a, v = d[j], d[j + 1]
                j += 2
                if st == 0x90 and v > 0:
                    events.append((tick, 1, a, v))
                elif st == 0x80 or st == 0x90:
                    events.append((tick, 0, a, 0))
            else:
                j += 1
        tracks.append((name, events))
        i = end
    return div, tempo, tracks


def notes_of(events, spt):
    """Pair note-on/note-off into (start_sec, dur_sec, midi_note, velocity)."""
    open_notes, out = {}, []
    for tick, on, note, vel in events:
        if on:
            open_notes[note] = (tick, vel)
        elif note in open_notes:
            start, vel = open_notes.pop(note)
            out.append((start * spt, (tick - start) * spt, note, vel))
    return out


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def env_adsr(n, attack, decay, sustain, release):
    """Envelope over the held part; `release` is appended by the caller."""
    e = np.ones(n, dtype=np.float32)
    a = min(int(attack * SR), n)
    if a:
        e[:a] = np.linspace(0.0, 1.0, a) ** 1.5
    d = min(int(decay * SR), n - a)
    if d > 0:
        e[a:a + d] = np.linspace(1.0, sustain, d)
    e[a + d:] = sustain
    return e


def partials(freq, dur, harmonics, detune=0.0, vibrato=0.0, vib_hz=5.0):
    t = np.arange(int(dur * SR), dtype=np.float32) / SR
    sig = np.zeros_like(t)
    for mult, amp in harmonics:
        f = freq * mult
        if f > SR / 2.2:
            continue
        phase = 2 * np.pi * f * t
        if vibrato:
            phase = phase + vibrato * np.sin(2 * np.pi * vib_hz * t)
        sig += amp * np.sin(phase + np.random.random() * 6.283)
        if detune:
            sig += amp * 0.7 * np.sin(2 * np.pi * f * (1 + detune) * t + np.random.random() * 6.283)
    return t, sig


def voice_pad(freq, dur, vel):
    tail = 4.0
    t, sig = partials(freq, dur + tail,
                      [(1, 1.0), (2, 0.40), (3, 0.18), (4, 0.09), (5, 0.04)],
                      detune=0.0025, vibrato=0.02, vib_hz=0.35)
    n = len(sig)
    held = int(dur * SR)
    e = np.zeros(n, dtype=np.float32)
    e[:held] = env_adsr(held, 2.2, 1.0, 0.75, 0)
    rel = n - held
    e[held:] = e[held - 1] * np.exp(-np.arange(rel) / (tail * 0.35 * SR))
    return sig * e * (vel / 127.0) * 0.5


def voice_bass(freq, dur, vel):
    tail = 2.0
    t, sig = partials(freq, dur + tail, [(1, 1.0), (2, 0.30), (3, 0.10), (4, 0.03)])
    n, held = len(sig), int(dur * SR)
    e = np.zeros(n, dtype=np.float32)
    e[:held] = env_adsr(held, 0.35, 1.5, 0.6, 0)
    e[held:] = e[held - 1] * np.exp(-np.arange(n - held) / (tail * 0.3 * SR))
    return sig * e * (vel / 127.0) * 1.1


def voice_pluck(freq, dur, vel):
    """Harp-like: instant attack, exponential decay, harmonics die faster."""
    total = min(dur + 3.0, 5.0)
    t = np.arange(int(total * SR), dtype=np.float32) / SR
    sig = np.zeros_like(t)
    for mult, amp, decay in [(1, 1.0, 1.8), (2, 0.45, 1.1), (3, 0.22, 0.8),
                             (4, 0.10, 0.6), (6, 0.05, 0.4)]:
        f = freq * mult
        if f > SR / 2.2:
            continue
        sig += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    a = int(0.004 * SR)
    sig[:a] *= np.linspace(0, 1, a)
    return sig * (vel / 127.0) * 0.9


def voice_bell(freq, dur, vel):
    """Celesta: slightly inharmonic partials, long shimmering decay."""
    total = min(dur + 4.0, 7.0)
    t = np.arange(int(total * SR), dtype=np.float32) / SR
    sig = np.zeros_like(t)
    for mult, amp, decay in [(1, 1.0, 2.6), (2.01, 0.35, 1.6), (3.02, 0.18, 1.0),
                             (4.98, 0.08, 0.7), (7.0, 0.04, 0.5)]:
        f = freq * mult
        if f > SR / 2.2:
            continue
        sig += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    a = int(0.006 * SR)
    sig[:a] *= np.linspace(0, 1, a)
    return sig * (vel / 127.0) * 0.85


def voice_shimmer(freq, dur, vel):
    tail = 5.0
    t, sig = partials(freq, dur + tail, [(1, 1.0), (2, 0.5), (3, 0.25), (4.5, 0.12)],
                      detune=0.004, vibrato=0.08, vib_hz=0.6)
    n, held = len(sig), int(dur * SR)
    e = np.zeros(n, dtype=np.float32)
    e[:held] = env_adsr(held, 4.0, 0.0, 1.0, 0)
    e[held:] = e[held - 1] * np.exp(-np.arange(n - held) / (tail * 0.4 * SR))
    # slow tremolo keeps the high pad from sounding static
    trem = 1.0 + 0.25 * np.sin(2 * np.pi * 0.17 * (np.arange(n) / SR))
    return sig * e * trem * (vel / 127.0) * 0.45


# name -> (voice fn, gain, stereo pan -1..1, reverb send)
VOICES = {
    'Pad (warm)':         (voice_pad,     0.55, 0.00, 0.55),
    'Bass':               (voice_bass,    0.85, 0.00, 0.20),
    'Pluck':              (voice_pluck,   0.40, -0.35, 0.60),
    'Melodie':            (voice_bell,    0.55, 0.25, 0.65),
    'Shimmer (optional)': (voice_shimmer, 0.35, 0.10, 0.75),
}


def reverb(mono):
    """Schroeder-style: four combs in parallel into two allpass stages."""
    out = np.zeros_like(mono)
    for delay_ms, gain in [(29.7, 0.80), (37.1, 0.78), (41.1, 0.76), (43.7, 0.74)]:
        d = int(delay_ms * SR / 1000)
        buf = mono.copy()
        for k in range(1, int(len(mono) / d)):
            buf[k * d:] += gain ** k * mono[:len(mono) - k * d]
        out += buf / 4.0
    for delay_ms, gain in [(5.0, 0.7), (1.7, 0.7)]:
        d = int(delay_ms * SR / 1000)
        y = out.copy()
        y[d:] += gain * out[:-d]
        out = y * (1 - gain * gain)
    return out


def main(midi_path, out_path):
    np.random.seed(7)
    div, tempo, tracks = parse(midi_path)
    spt = tempo / 1e6 / div
    total = int((LOOP + TAIL) * SR)
    dry = np.zeros((2, total), dtype=np.float32)
    wet_send = np.zeros(total, dtype=np.float32)

    for name, events in tracks:
        if name not in VOICES:
            continue
        fn, gain, pan, send = VOICES[name]
        for start, dur, note, vel in notes_of(events, spt):
            sig = fn(hz(note), dur, vel) * gain
            i0 = int(start * SR)
            n = min(len(sig), total - i0)
            if n <= 0:
                continue
            left = math.sqrt((1 - pan) / 2)
            right = math.sqrt((1 + pan) / 2)
            dry[0, i0:i0 + n] += sig[:n] * left
            dry[1, i0:i0 + n] += sig[:n] * right
            wet_send[i0:i0 + n] += sig[:n] * send

    wet = reverb(wet_send)
    # Slight decorrelation so the reverb sits wider than the dry signal.
    off = int(0.011 * SR)
    mix = dry.copy()
    mix[0] += 0.34 * wet
    mix[1, off:] += 0.34 * wet[:-off]

    # Wrap the tail back onto the start: the loop seam now carries the ring-out.
    loop_n = int(LOOP * SR)
    out = mix[:, :loop_n].copy()
    tail = mix[:, loop_n:]
    out[:, :tail.shape[1]] += tail

    peak = float(np.max(np.abs(out)))
    out = out / peak * 0.89
    # No fade at the seam: the wrapped tail already continues the ring-out, so
    # sample 0 picks up where the last sample left off. A fade would cut it.
    # The wrapped tail leaves a tiny step at the seam (the tail itself was cut
    # off at LOOP+TAIL). Ramp that offset out over 30ms instead of fading to
    # silence, which would punch a hole in the ring-out.
    seam = out[:, 0] - out[:, -1]
    print('seam step = %.5f -> smoothed' % float(np.max(np.abs(seam))))
    ramp_n = int(0.03 * SR)
    ramp = np.linspace(1.0, 0.0, ramp_n, dtype=np.float32)
    out[:, :ramp_n] -= seam[:, None] * ramp[None, :]

    pcm = (np.clip(out.T, -1, 1) * 32767).astype('<i2')
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('wrote %s  %.2fs  peak_before_norm=%.3f' % (out_path, loop_n / SR, peak))


main(sys.argv[1], sys.argv[2])
