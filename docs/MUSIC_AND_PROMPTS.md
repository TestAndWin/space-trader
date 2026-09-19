# Music (Suno)

Prompts for generating background music with [suno.com](https://suno.com).
Target: seamless loops for the game screens, generated instrumental, no vocals.

## Licensing — read before generating

- **Free plan**: Suno keeps ownership, you only get a **non-commercial, personal-use**
  licence. Not sufficient for a released build, not even a free one.
- **Pro / Premier**: you own the outputs and may use them commercially. Rights
  survive cancellation, so one paid month is enough to produce the whole soundtrack.
- **No retroactive rights**: tracks generated on the free plan stay non-commercial
  even after upgrading. They have to be regenerated while subscribed.
- Downloads are capped since 2026-09-03. Free accounts only get a small one-time
  allowance of trial downloads (personal use only).

## Loop length

The planet screen loop should repeat after roughly 30 seconds. Pick the BPM so a
whole number of bars lands on the target length, then cut on a bar boundary:

| BPM | 8 bars (4/4) | 9 bars |
|-----|--------------|--------|
| 64  | 30.00 s      | 33.75 s |
| 70  | 27.43 s      | 30.86 s |
| 75  | 25.60 s      | 28.80 s |

64 BPM / 8 bars hits exactly 30 s and is the default used below.

## Planet Screen (Hub)

- Filename: `assets/audio/music_planet_hub.ogg`
- Title: `Starport Idle`
- Lyrics field: `[Instrumental]`
- Settings: Instrumental ON, Custom Mode ON, length 30-60 s, cut to 8 bars
- Style Prompt:

```
Ambient sci-fi space trading hub, slow atmospheric synthwave, 64 BPM, A minor.
Warm analog pads, deep sub bass drone, sparse plucked arpeggio, soft
side-chained pulse, distant metallic reverb, subtle vinyl-like noise floor.
Calm, contemplative, spacious — background music for a starport city screen,
never intrusive. Steady 4-bar loop structure, no drops, no build-ups,
no vocals, no drums beyond a soft muted kick. Consistent dynamics from
start to end, seamless loopable ending that flows back into the intro.
```

### Planet type variants

Reuse the prompt above and swap the mood line
(`Calm, contemplative, spacious — ...`) for the matching row:

| Planet type | Mood line |
|-------------|-----------|
| Tech (Starport Alpha, Nexus Prime) | `Clean, crystalline, curious — glassy bell tones and a clock-like sequencer` |
| Industrial (Forge World) | `Heavy, mechanical, grinding — filtered machine noise used as a rhythm layer` |
| Agricultural (Green Reach) | `Gentle, organic, warm — soft flute pad and wooden percussion texture` |
| Mining (Dust Haven, Iron Belt) | `Low, cavernous, heavy — deep drone and distant hammer echoes` |
| Outlaw (Nova Station, Crimson Jack's Hideout) | `Shady, tense, smoky — detuned bass, brushed hi-hat, a hint of noir saxophone` |

## Integration notes

- Playback runs through the `AudioManager` autoload (`scripts/autoloads/audio_manager.gd`),
  on the buses `Music`, `SFX` and `UI` (`assets/audio/default_bus_layout.tres`).
- The planet screen already plays `res://assets/audio/bgm/planet.ogg` via
  `AudioManager.play_bgm()` (`planet_screen.gd`). A Suno track replaces that file.
- `play_bgm()` forces looping in code (`_ensure_looping()` handles OGG, MP3 and
  WAV), so the import dock Loop flag is not required.

# Sound Effects (ElevenLabs)

## Current state

All in-game sound effects in `assets/audio/sfx/*.wav` come from ElevenLabs
(generated 2026-09-19 on a paid plan, so they are licensed for release builds).
`tools/fetch_sfx_elevenlabs.py` holds the prompts and writes straight into that
directory. `AudioManager.play_sfx(name)` and the `play_laser()` /
`play_purchase()` / ... wrappers look them up by file name.

Player shots differ by damage type: `AudioManager.play_shot(damage_type)` maps
KINETIC -> `kinetic_shot`, ION -> `ion_shot`, PIERCING -> `laser`
(`AudioManager.SHOT_SFX`).

`travel.wav` is a 10 s steady drone with no ending: `AudioManager.play_travel_sfx(duration)`
plays it for exactly the length of the warp animation and fades it out there.

`tools/generate_sfx.py` still produces the old procedural set under the same
names. It is kept as a fallback: running it overwrites the ElevenLabs files.

**Clicks**: `AudioManager._input()` plays `ui_click` on every left click / tap
anywhere in the game, on press. Screens do not call `play_ui_click()`
themselves. A control that uses clicks as gameplay input joins
`AudioManager.SILENT_CLICK_GROUP` to opt out (Starport Defense canvas).
`play_ui_denied()` called in the same frame replaces the click.

## Licensing

- **Free plan**: personal use only, attribution required. Not usable in a build.
- **Starter and above** (from 5 $/month): commercial licence, no attribution.
- As with Suno, a later upgrade does **not** relicense free-plan generations —
  regenerate while subscribed.
- Cost: 200 credits per generation. The free plan has 10,000 credits/month
  (~50 generations) and no overage billing: requests fail once it is spent.

## Procedure

1. Create an API key at <https://elevenlabs.io/app/settings/api-keys>.
   Restrict its **scope** to sound generation and set a **credit quota**, so a
   script bug cannot burn the whole allowance. Copy it immediately — it is shown once.
2. Never commit the key and never paste it into chats. Put it in `.env`
   (already in `.gitignore`) or pass it for a single call:

   ```bash
   python3 tools/fetch_sfx_elevenlabs.py --list            # show the manifest, no API call
   python3 tools/fetch_sfx_elevenlabs.py laser purchase    # only these
   python3 tools/fetch_sfx_elevenlabs.py                   # all -> assets/audio/sfx/
   python3 tools/fetch_sfx_elevenlabs.py --out /tmp/try    # somewhere else

   The key is read from `ELEVENLABS_API_KEY`, or from `.env` if unset.
   ```

3. Listen (`afplay assets/audio/sfx/laser.wav`). To audition a new take without
   replacing the current one, use `--out` and copy it over once it is better.

A restricted key returns **401 `missing_permissions`** on
`/v1/user/subscription` — that is expected and means the scope works, not that
the key is broken. Test with a generation instead.

## Pitfalls found during the trial

- **No PCM on the free/low tiers.** `output_format: "pcm_44100"` (and
  `pcm_24000`) is silently ignored; the response is always
  `audio/mpeg`, 128 kbps stereo. Writing those bytes as PCM produces noise.
  The script therefore requests `mp3_44100_128` and decodes with `afconvert`
  (macOS) or `ffmpeg`. Expect some MP3 generation loss on sharp transients.
- **SSL on python.org builds.** Python installed from python.org ships without
  the system CA store, so `urlopen` fails with `CERTIFICATE_VERIFY_FAILED`.
  The script uses `certifi`, falling back to `/etc/ssl/cert.pem`.
- **Inconsistent levels.** Takes come back at arbitrary loudness. The script
  peak-normalises each one to the same target as `generate_sfx.py`, so an A/B
  swap does not change the mix.
- **No single clicks.** The minimum duration is 0.5 s and the model fills it
  with a run of ticks. Manifest entries with a fifth value (`max_seconds`) are
  cut to the first transient with an exponential release (`crop_onset()`);
  everything else just has its trailing silence trimmed (`trim_tail()`).
- **Style drift.** Every generation is independent. A shared style suffix on
  every prompt keeps the set from sounding like six different games.

## Prompt rules

Formula: *what happens + source/material + sound character*, then the shared suffix.

- Bad: `laser sound`
- Good: `Spaceship laser cannon firing a single shot, sharp energy discharge with a bright electric transient and a short descending metallic tail`
- Always keep reverb out of the file (`dry, no reverb`). Room can be added on
  the Godot bus later; baked-in reverb cannot be removed and makes repeated UI
  sounds tiring.
- Set `duration_seconds` explicitly. "Auto" tends to produce long tails.
- `prompt_influence` 0.7-0.8 for game SFX: high enough to follow the prompt,
  low enough to leave some variation between takes.

Shared style suffix (appended to every prompt):

```
clean synthetic sci-fi game sound effect, dry, close, no reverb, no music
```

## Prompt manifest

Source of truth is `MANIFEST` in `tools/fetch_sfx_elevenlabs.py`. Target peak
matches the procedural file of the same name.

| Name | Duration | Influence | Peak | Prompt |
|------|----------|-----------|------|--------|
| `laser` | 0.6 s | 0.8 | 0.62 | Spaceship laser cannon firing a single shot, sharp energy discharge with a bright electric transient and a short descending metallic tail |
| `purchase` | 0.7 s | 0.8 | 0.48 | Digital credit transaction confirmed, short warm synthetic two-tone chime, clean and friendly, single event |
| `shield_hit` | 0.8 s | 0.8 | 0.50 | Energy shield absorbing a projectile impact, shimmering electric ripple with a glassy inharmonic resonance, no low end |
| `explosion` | 2.0 s | 0.7 | 0.90 | Spaceship exploding in vacuum, muffled deep boom with debris scatter and a fading energy hiss, no music |
| `hull_hit` | 0.9 s | 0.8 | 0.72 | Heavy projectile impact on a starship hull plate, deep metallic thud with creaking stress and a dull ring |
| `casino_win` | 1.8 s | 0.7 | 0.55 | Slot machine jackpot in a futuristic casino, bright glassy bell cascade rising over a warm synth shimmer |

Trial results (2026-09-19): all six returned at the requested length, no
clipping, 0-1 ms lead-in silence, RMS from -12 dBFS (explosion) to -24 dBFS
(purchase).

### Not yet in the manifest

Candidates for the remaining procedural effects, if the set is ever replaced in full:

| Name | Duration | Prompt |
|------|----------|--------|
| `enemy_laser` | 0.6 s | Hostile energy weapon firing, lower and dirtier plasma discharge with gritty noise and a heavy tail |
| `sell` | 0.6 s | Digital credit payout, bright ascending synthetic chime with a soft coin-like click |
| `ui_click` | 0.5 s | Minimal futuristic UI click, soft muted tick |
| `ui_denied` | 0.5 s | Short negative UI error tone, low dull descending buzz |
| `card_play` | 0.5 s | Single playing card swiped quickly through the air, crisp swish ending in a soft snap |
| `card_draw` | 0.5 s | Single card sliding off a deck, crisp paper friction, very short |
| `casino_spin` | 1.4 s | Slot machine reels spinning, soft mechanical ticks slowing down |
| `casino_lose` | 0.6 s | Losing slot machine result, dark descending synth drop, disappointing but not comical |
| `travel` | 2.0 s | Starship engine spooling up and departing, deep rising hum with a rushing whoosh |
| `arrive` | 1.5 s | Spaceship dropping out of hyperspace, descending energy whoosh settling into a low hum |

The API minimum is 0.5 s, so UI sounds shorter than that (the procedural
`ui_click` is 0.05 s) need trimming after generation.
