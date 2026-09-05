# Harvest — design system

**The floor:** a 5" 720p screen, 2 GB of RAM, direct sunlight, a dusty screen, work-hardened
hands, and a user who may not read. Every rule below follows from it.

## Principles

1. **Reading is optional.** Pictures and speech carry every P0 flow. Text accompanies.
2. **One decision per screen.** The farmer is standing in a field.
3. **Pictures are data.** A crop is chosen by its photograph, a unit by a picture of the basket.
4. **Say the consequence in money.** Naira, not hours.
5. **Honest about uncertainty.** Ranges, not false precision.

## Colour

Built around crop freshness, because that is the one state the whole app communicates.

| Role | Light | Dark |
|---|---|---|
| `surface` | `#FFFFFF` | `#0F1310` |
| `surfaceDim` | `#F2F5F1` | `#1A211B` |
| `textPrimary` | `#12180F` | `#EDF2EA` |
| `textSecondary` | `#5B6558` | `#A3AE9E` |
| `accent` | `#2E7D32` | `#5CB860` |
| `fresh` | `#2E7D32` | `#5CB860` |
| `atRisk` | `#E08A00` | `#F0A93B` |
| `critical` | `#C62828` | `#EF6B6B` |
| `sold` | `#5B6558` | `#A3AE9E` |

**Dark is the default**, not `ThemeMode.system`. Both are authored; neither is derived.

**Colour is never the sole carrier of meaning.** A freshness ring says the same thing three
ways: the fill fraction, the spoken sentence, and the colour. A colour-blind farmer in
sunlight on a dusty screen loses one channel and keeps two.

## Targets

`Target.standard` is **56 dp** — Material's 48 is a figure for an office.
`Target.primary` is **64 dp**, for anything used one-handed outdoors while holding a crate.

## Type

Display 30 sp, title 22, body 18, secondary 16. Moderate on purpose: a headline that fills
the screen leaves no room for the thing it introduces.

## Speech

Five languages: English, Nigerian Pidgin (`pcm`), Hausa, Yoruba, Igbo. Each named by its
**endonym** — `Yorùbá`, not `Yoruba` — because the name in the language is the only name
useful to somebody who cannot read the rest of the screen.

Every fixed prompt is a bundled clip. `make audio-check` proves the set is complete and
reads the language and phrase lists out of the Dart enums rather than a list maintained
beside them.
