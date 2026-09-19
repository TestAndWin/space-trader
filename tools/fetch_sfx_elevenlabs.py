#!/usr/bin/env python3
"""Fetch sound effects from the ElevenLabs text-to-sound-effects API.

Replaces the procedural set from generate_sfx.py: same effect names, same
target loudness, so a file can be swapped in without touching any code.

The API only serves raw PCM on higher tiers - everything else silently gets
MP3 back regardless of output_format - so the response is decoded to WAV with
afconvert (macOS) or ffmpeg. Output is 16-bit mono at 44.1 kHz, which Godot
imports natively.

The API key is read from ELEVENLABS_API_KEY, or from the project's .env file
when the variable is not set. It is never written anywhere.

Licensing: generations made on a free plan are personal-use only and are NOT
retroactively relicensed by subscribing later. Anything shipped in a build has
to be generated while a paid plan is active.

Usage:
    python3 tools/fetch_sfx_elevenlabs.py                 # all -> assets/audio/sfx/
    python3 tools/fetch_sfx_elevenlabs.py laser purchase  # only these
    ... --out /tmp/try     # write somewhere else
    ... --list             # show the manifest without calling the API
"""

import json
import math
import os
import shutil
import ssl
import struct
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import wave

API_URL = "https://api.elevenlabs.io/v1/sound-generation"
SR = 44100
DEFAULT_OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "audio", "sfx",
)
ENV_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env",
)


def _ssl_context():
    """Python.org builds ship without the system CA store, so a plain urlopen
    fails to verify api.elevenlabs.io. Prefer certifi, fall back to the macOS
    bundle, and only then to the default (which may work on other installs)."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    if os.path.exists("/etc/ssl/cert.pem"):
        return ssl.create_default_context(cafile="/etc/ssl/cert.pem")
    return ssl.create_default_context()


SSL_CTX = _ssl_context()

# Shared suffix on every prompt. Generations are independent of each other, so
# without a constant style clause the set drifts apart into unrelated timbres.
STYLE = "clean synthetic sci-fi game sound effect, dry, close, no reverb, no music"

# name -> (prompt, duration_seconds, prompt_influence, target_peak[, max_seconds])
# Names match generate_sfx.py one to one, so a file can replace its procedural
# counterpart without a code change. Target peaks mirror generate_sfx.py too,
# so swapping the set does not change the mix. 0.5 s is the API minimum;
# shorter cues are trimmed afterwards by trim_tail(). The model cannot make a
# single click - it fills the whole duration with ticks - so cues that need to
# be shorter than that set max_seconds and are cut to one transient by
# crop_onset().
MANIFEST = {
    "ui_click": (
        "One single isolated button click, a tiny crisp high-pitched digital "
        "tick lasting a few milliseconds, followed by complete silence",
        0.5, 0.8, 0.30, 0.08,
    ),
    "ui_denied": (
        "Short negative interface error buzz on a spaceship console, "
        "low two-note descending synthetic bleep, access denied",
        0.5, 0.8, 0.34,
    ),
    "card_play": (
        "Holographic playing card slapped onto a table, quick paper swipe "
        "with a bright digital energy snap",
        0.5, 0.8, 0.42,
    ),
    "card_draw": (
        "Single holographic card drawn from a deck, soft quick paper slide "
        "with a light airy digital shimmer",
        0.5, 0.8, 0.38,
    ),
    "laser": (
        "Spaceship laser cannon firing a single shot, sharp energy discharge "
        "with a bright electric transient and a short descending metallic tail",
        0.6, 0.8, 0.62,
    ),
    # Per damage type (CardData.DamageType); PIERCING keeps "laser".
    "kinetic_shot": (
        "Starship mass driver cannon firing a single solid slug, punchy "
        "mechanical bang with a heavy recoil thump and a short metallic ring",
        0.6, 0.8, 0.62,
    ),
    "ion_shot": (
        "Ion cannon firing a single charged bolt, crackling electric zap "
        "with a buzzing fizzing plasma hum, bright and sizzling",
        0.6, 0.8, 0.62,
    ),
    "enemy_laser": (
        "Hostile alien warship firing a heavy plasma bolt, harsh buzzing "
        "energy blast with a gritty distorted low tail, menacing",
        0.6, 0.8, 0.58,
    ),
    "shield_hit": (
        "Energy shield absorbing a projectile impact, shimmering electric "
        "ripple with a glassy inharmonic resonance, no low end",
        0.8, 0.8, 0.50,
    ),
    "hull_hit": (
        "Heavy projectile impact on a starship hull plate, deep metallic thud "
        "with creaking stress and a dull ring",
        0.9, 0.8, 0.72,
    ),
    "explosion": (
        "Spaceship exploding in vacuum, muffled deep boom with debris scatter "
        "and a fading energy hiss",
        2.0, 0.7, 0.90,
    ),
    "purchase": (
        "Digital credit transaction confirmed, short warm synthetic two-tone "
        "chime, clean and friendly, single event",
        0.7, 0.8, 0.48,
    ),
    # Market buys only; repairs, upgrades, crew and ships keep "purchase".
    # Kept short because players buy several times in a row.
    "cargo_buy": (
        "A small handful of futuristic metal credit coins dropping into a "
        "tray, short crisp bright jingle that settles quickly, pleasant and "
        "satisfying",
        0.9, 0.8, 0.48,
    ),
    # Buy fuel / fill tank / emergency fuel at the shipyard.
    "fuel_buy": (
        "Fuel nozzle pumping liquid fuel into a starship tank, short "
        "pressurized hiss with a smooth liquid flow, ending in a soft valve "
        "click",
        1.0, 0.8, 0.46,
    ),
    "sell": (
        "Futuristic cash register payout, quick cascade of three bright "
        "synthetic coin chimes rising in pitch, rewarding",
        0.8, 0.8, 0.46,
    ),
    "casino_spin": (
        "Futuristic slot machine reels spinning, rapid mechanical ticking "
        "clicks slowing down with a soft electronic whir",
        1.4, 0.7, 0.40,
    ),
    "casino_win": (
        "Slot machine jackpot in a futuristic casino, bright glassy bell "
        "cascade rising over a warm synth shimmer",
        1.8, 0.7, 0.55,
    ),
    "casino_lose": (
        "Futuristic casino loss, short sad descending synth wah tone, "
        "deflating and disappointed",
        0.7, 0.8, 0.45,
    ),
    # Deliberately long and steady: AudioManager.play_travel_sfx() cuts it to
    # the length of the warp animation (4-7 s) with a fade, so it must not
    # have an ending of its own.
    "travel": (
        "Starship engines igniting into hyperspace and cruising through it, "
        "a short rising turbine whoosh settling into a continuous steady deep "
        "engine rumble with swirling energy at constant loudness throughout, sustained drone, no fade out, no ending",
        10.0, 0.8, 0.55,
    ),
    "arrive": (
        "Starship arriving at a planet, one smooth descending engine whoosh "
        "that slows down and settles into a warm, calm, soft low hum, "
        "gentle and welcoming, single continuous event",
        2.5, 0.75, 0.50,
    ),
}


def decode_to_pcm(mp3_bytes):
    """MP3 -> raw 16-bit mono 44.1 kHz PCM.

    afconvert ships with macOS; ffmpeg is the fallback for other platforms.
    """
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.mp3")
        dst = os.path.join(tmp, "out.wav")
        with open(src, "wb") as f:
            f.write(mp3_bytes)

        if shutil.which("afconvert"):
            cmd = ["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "1", src, dst]
        elif shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-loglevel", "error", "-y", "-i", src,
                   "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", dst]
        else:
            raise RuntimeError("need afconvert (macOS) or ffmpeg to decode the MP3 response")

        subprocess.run(cmd, check=True, capture_output=True)
        with wave.open(dst) as w:
            return w.readframes(w.getnframes())


def request_pcm(name, api_key):
    prompt, duration, influence = MANIFEST[name][:3]
    body = json.dumps({
        "text": "%s, %s" % (prompt, STYLE),
        "duration_seconds": duration,
        "prompt_influence": influence,
        "output_format": "mp3_44100_128",
    }).encode()
    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={"xi-api-key": api_key, "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180, context=SSL_CTX) as resp:
        return decode_to_pcm(resp.read())


def crop_onset(pcm, max_seconds):
    """Keep max_seconds from the first strong transient, with an exponential
    decay so the cut reads as a natural release rather than a chop."""
    n = len(pcm) // 2
    samples = struct.unpack("<%dh" % n, pcm[: n * 2])
    peak = max(abs(s) for s in samples) or 1
    start = next(i for i, s in enumerate(samples) if abs(s) >= peak * 0.3)
    start = max(0, start - int(0.006 * SR))
    length = min(n - start, int(max_seconds * SR))
    out = bytearray()
    for i in range(length):
        v = samples[start + i] * math.exp(-5.0 * i / length)
        out += struct.pack("<h", int(v))
    return bytes(out)


def trim_tail(pcm, threshold=0.02, pad=0.02):
    """Cut trailing near-silence. The API pads every take to the requested
    duration, which for a UI click means most of the file is dead air."""
    n = len(pcm) // 2
    samples = struct.unpack("<%dh" % n, pcm[: n * 2])
    peak = max(abs(s) for s in samples) or 1
    limit = peak * threshold
    last = n - 1
    while last > 0 and abs(samples[last]) <= limit:
        last -= 1
    end = min(n, last + int(pad * SR))
    return pcm[: end * 2]


def load_api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key or not os.path.exists(ENV_FILE):
        return key
    with open(ENV_FILE) as f:
        for raw in f:
            line = raw.strip()
            if line.startswith("export "):
                line = line[len("export "):]
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip().strip("\"'")
    return ""


def normalize(pcm, target_peak):
    """Peak-normalise and apply short edge fades.

    The API returns takes at inconsistent levels; without this the set cannot
    be compared against the procedural files, which are all peak-matched.
    """
    n = len(pcm) // 2
    samples = list(struct.unpack("<%dh" % n, pcm[: n * 2]))
    peak = max(abs(s) for s in samples) or 1
    scale = (target_peak * 32767.0) / peak

    fade = min(int(0.004 * SR), n // 4)
    out = bytearray()
    for i, s in enumerate(samples):
        v = s * scale
        if fade > 1:
            if i < fade:
                v *= i / fade
            elif i >= n - fade:
                v *= (n - i) / fade
        out += struct.pack("<h", max(-32768, min(32767, int(v))))
    return bytes(out)


def write_wav(path, pcm):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)


def main(argv):
    out_dir = DEFAULT_OUT
    names = []
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out_dir = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--list":
            for k, (p, d, inf) in ((k, v[:3]) for k, v in MANIFEST.items()):
                print("%-12s %4.1fs  infl=%.1f  %s" % (k, d, inf, p))
            return 0
        names.append(argv[i])
        i += 1

    unknown = [n for n in names if n not in MANIFEST]
    if unknown:
        print("unknown effect(s): %s" % ", ".join(unknown))
        print("available: %s" % ", ".join(MANIFEST))
        return 1

    api_key = load_api_key()
    if not api_key:
        print("ELEVENLABS_API_KEY is not set (environment or .env)")
        return 1

    failed = 0
    for name in (names or list(MANIFEST)):
        target_peak = MANIFEST[name][3]
        try:
            pcm = request_pcm(name, api_key)
        except urllib.error.HTTPError as e:
            print("%-12s FAILED  HTTP %s  %s" % (name, e.code, e.read()[:200].decode("utf-8", "replace")))
            failed += 1
            continue
        except urllib.error.URLError as e:
            print("%-12s FAILED  %s" % (name, e.reason))
            failed += 1
            continue

        path = os.path.join(out_dir, name + ".wav")
        spec = MANIFEST[name]
        pcm = crop_onset(pcm, spec[4]) if len(spec) > 4 else trim_tail(pcm)
        pcm = normalize(pcm, target_peak)
        write_wav(path, pcm)
        print("%-12s %5.2fs  %6.1f kB  %s" % (
            name, len(pcm) / 2.0 / SR, len(pcm) / 1024.0, path))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
