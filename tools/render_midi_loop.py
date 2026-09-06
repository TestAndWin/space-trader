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
    beats_per_bar, beat_div = 4, 4
    for _ in range(ntrk):
        ln = struct.unpack('>I', d[i + 4:i + 8])[0]
        end, j, tick, name, running, prog = i + 8 + ln, i + 8, 0, '', None, 0
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
                if mt == 0x58:
                    beats_per_bar, beat_div = data[0], 2 ** data[1]
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
            elif st == 0xC0:
                prog = d[j]
                j += 1
            else:
                j += 1
        tracks.append((name, prog, events))
        i = end
    bar_ticks = int(div * 4 / beat_div * beats_per_bar)
    return div, tempo, bar_ticks, tracks


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


def voice_drone(freq, dur, vel):
    """Sub bass drone: near-sine with a touch of grit, breathes very slowly."""
    tail = 4.0
    t, sig = partials(freq, dur + tail, [(1, 1.0), (2, 0.55), (3, 0.26), (4, 0.10)],
                      detune=0.0012)
    n, held = len(sig), int(dur * SR)
    e = np.zeros(n, dtype=np.float32)
    e[:held] = env_adsr(held, 1.6, 0.0, 1.0, 0)
    e[held:] = e[held - 1] * np.exp(-np.arange(n - held) / (tail * 0.35 * SR))
    breathe = 1.0 + 0.12 * np.sin(2 * np.pi * 0.09 * (np.arange(n) / SR))
    return sig * e * breathe * (vel / 127.0) * 0.85


def voice_lead(freq, dur, vel):
    """Soft synth lead: hollow (odd harmonics), slow swell, gentle vibrato."""
    tail = 3.0
    t, sig = partials(freq, dur + tail, [(1, 1.0), (3, 0.22), (5, 0.09), (2, 0.12)],
                      detune=0.0018, vibrato=0.035, vib_hz=4.4)
    n, held = len(sig), int(dur * SR)
    e = np.zeros(n, dtype=np.float32)
    e[:held] = env_adsr(held, 0.45, 0.8, 0.8, 0)
    e[held:] = e[held - 1] * np.exp(-np.arange(n - held) / (tail * 0.3 * SR))
    return sig * e * (vel / 127.0) * 0.65


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


# voice -> (fn, gain, stereo pan -1..1, reverb send)
VOICES = {
    'pad':      (voice_pad,     0.55, 0.00, 0.55),
    'bass':     (voice_bass,    0.85, 0.00, 0.20),
    'drone':    (voice_drone,   0.34, 0.00, 0.30),
    'pluck':    (voice_pluck,   0.40, -0.35, 0.60),
    'bell':     (voice_bell,    0.55, 0.25, 0.65),
    'lead':     (voice_lead,    0.50, 0.15, 0.55),
    'shimmer':  (voice_shimmer, 0.35, 0.10, 0.75),
}

# General MIDI program -> voice. Only the programs actually used by the tracks
# in assets/audio are listed; anything else falls back to 'pad'.
PROGRAM_VOICES = {
    8: 'bell',       # Celesta
    32: 'bass',      # Acoustic Bass
    38: 'drone',     # Synth Bass 1
    46: 'pluck',     # Orchestral Harp
    82: 'lead',      # Lead 3 (calliope)
    89: 'pad',       # Pad 2 (warm)
    94: 'pad',       # Pad 7 (halo)
    98: 'bell',      # FX 3 (crystal)
    99: 'shimmer',   # FX 4 (atmosphere)
}

# Two tracks can share a GM program and still want different treatment (both
# "Shimmer" and "Quartal Pad" are Pad Halo), so the track name wins when set.
NAME_VOICES = {
    'shimmer (optional)': 'shimmer',
}


def voice_for(name, prog):
    key = NAME_VOICES.get(name.strip().lower())
    if key is None:
        key = PROGRAM_VOICES.get(prog, 'pad')
    return VOICES[key], key


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


def highpass(stereo, cutoff_hz):
    """High-pass in the frequency domain, which is circular -- and that is what
    a loop wants: a recursive filter would ring in at sample 0 and break the
    seam, while circular filtering treats the signal as the periodic thing it
    actually is."""
    n = stereo.shape[1]
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    # 2nd-order-ish response: -12 dB/oct below the cutoff, flat above.
    with np.errstate(divide='ignore'):
        ratio = freqs / cutoff_hz
    resp = (ratio ** 2 / (1.0 + ratio ** 2)).astype(np.float32)
    out = np.empty_like(stereo)
    for ch in range(stereo.shape[0]):
        out[ch] = np.fft.irfft(np.fft.rfft(stereo[ch]) * resp, n)
    return out


def main(midi_path, out_path):
    np.random.seed(7)
    div, tempo, bar_ticks, tracks = parse(midi_path)
    spt = tempo / 1e6 / div

    # Loop on a bar boundary, not on the last note-off: the tracks end ragged
    # (release tails), but the loop has to line up musically.
    last_tick = max((e[0] for _, _, evs in tracks for e in evs), default=0)
    bars = max(1, math.ceil(last_tick / bar_ticks))
    loop_sec = bars * bar_ticks * spt
    print('%.1f BPM, %d bars of %d ticks -> loop %.4fs'
          % (6e7 / tempo, bars, bar_ticks, loop_sec))

    total = int((loop_sec + TAIL) * SR)
    dry = np.zeros((2, total), dtype=np.float32)
    wet_send = np.zeros(total, dtype=np.float32)

    for name, prog, events in tracks:
        if not events:
            continue
        (fn, gain, pan, send), key = voice_for(name, prog)
        print('  %-22s prog=%-3d -> %s' % (name, prog, key))
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
    loop_n = int(round(loop_sec * SR))
    out = mix[:, :loop_n].copy()
    tail = mix[:, loop_n:]
    out[:, :tail.shape[1]] += tail

    out = highpass(out, 32.0)

    # Peak-normalising makes a bass-heavy track quiet and a bright one loud, so
    # match on RMS (-16 dBFS) and only fall back to the peak if that clips.
    target_rms = 10 ** (-16.0 / 20.0)
    gain = target_rms / float(out.std())
    peak = float(np.max(np.abs(out))) * gain
    if peak > 0.89:
        gain *= 0.89 / peak
    print('normalise: rms %.1f dBFS peak %.3f (gain x%.2f)'
          % (20 * math.log10(out.std() * gain), min(peak, 0.89), gain))
    out = out * gain
    # No fade at the seam: the wrapped tail already continues the ring-out, so
    # sample 0 picks up where the last sample left off. A fade would cut it.
    # What is left is a tiny step, because the wrapped tail was itself cut off
    # at loop_sec+TAIL. Ramp that offset out over 30ms instead of fading to
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
