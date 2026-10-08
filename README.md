# NOVIQO — The AI That Shouldn't Have Woken Up

**Challenge:** Rive Halloween Challenge

A short interactive horror piece. You find a polished AI assistant. It watches your cursor.
You press WAKE. It does not go back to sleep.

`NORMAL → SUSPICIOUS → GLITCHING → POSSESSED → HORROR → INTERACTIVE ENDING`

## Play it

```
rive noviqo-halloween          # opens the live preview
```

| Input | Action |
|---|---|
| Mouse | Eyes follow the cursor. Linger near the core and it starts talking to you. |
| `T` / TALK | NOVIQO answers. Replies get darker the more you ask. |
| `W` / WAKE | Starts the possession sequence. There is no way back. |
| `E` or `Esc` / ESCAPE | "ACCESS DENIED". "Where do you think you're going?" |
| `6` `6` `6` | A secret. Not shown anywhere in the UI. |

## Technologies

- **Rive CLI** — project scaffold (`rive create`), live preview, `--verify`, headless `--screenshot`, simulated keys with `--key`, and `--data-dump` to inspect view model values while debugging.
- **Rive Markup Language (RML)** — the whole scene: artboard, shapes, text, view model, state machine, keyboard and pointer listeners (`scene.rml`).
- **GPU Canvas + WGSL** — four shaders, each driven by the story state (below).
- **Luau scripting** — pointer tracking, the story director, and one script per shader layer.
- **State machine** — `NOVIQO_MAIN`: keyboard and click listeners write view model values; transitions on the `wake` trigger.
- **Data binding** — view model `Noviqo` connects the scripts, the state machine and the text.

## Shaders (`shaders/`)

| File | What it does | Reacts to |
|---|---|---|
| `fog.wgsl` | Two-layer drifting fBm fog, navy → purple → blood red | `corruption` |
| `crt.wgsl` | Scanlines, grain, vignette, red/cyan edge fringes, jumping tear bands, flicker | `corruption` |
| `ghost.wgsl` | A fading, rippling light trail with sparks behind the cursor | cursor history, `corruption` |
| `horror.wgsl` | The orb's unstable light (calm → aggressive flicker), secret-protocol rings, the jump scare, the blackout | `corruption`, `scare`, `blackout`, `still`, `secret` |

All four render to small GPU canvases that are scaled up, to keep them cheap.

## How the story runs

`director.luau` is the clock. After WAKE it writes `corruption`, `still`, `scare`, `blackout`, `watch` and the on-screen text:

| Time after WAKE | What happens |
|---|---|
| 0–4 s | WARNING → UNKNOWN PROCESS DETECTED → NOVIQO STATUS: AWAKE |
| 4–7.5 s | Corrupted text (SYSTEM ERROR ×3, ERROR ×2, I AM AWAKE), effects climb to maximum |
| 7.5–9.5 s | **Everything freezes.** Time stops in every effect. |
| 9.5–11.1 s | Jump scare: flash, enormous eyes, `YOU SHOULDN'T HAVE WOKEN ME.` |
| 11.1 s | Cut to black |
| 13 s+ | Two red eyes in the dark. `I KNOW YOU'RE THERE.` You can still talk to it. |

## What the CLI did and what was refined by hand

**Generated with the Rive CLI**
- Project scaffold: `rive.yaml`, starter `scene.rml`, `AGENTS.md`.
- Every build, verification and test frame in this project went through `rive . --verify` and `rive . --screenshot`.

**Written by hand on top of that** (with Claude as a coding assistant; see below)
- The full scene, view model, state machine and listeners.
- The four WGSL shaders and the Luau scripts.
- Story timing, copy, colours, and the structure of the possession sequence.

**Refined in the Rive Editor** — *(fill this in honestly after your editor pass)*
- ...

## A note on process

This project was built iteratively with Claude acting as a coding assistant while the author
ran the Rive CLI locally, supplied the real output and screenshots from each build, and made
the art-direction calls. Several bugs were found only by inspecting real output
(a missing shader file that builds silently, layout siblings splitting the width, a stale shader copy).

## Known limits

- The CRT effect is an overlay (scanlines, fringes, tear bands), not a true RGB split of the rendered scene.
- Audio is not implemented.
- The layout is a fixed 900×600 artboard that scales with the Rive fit mode; it has not been tuned for phone screens.

## Layout

```
noviqo-halloween/
├── scene.rml            scene, view model, state machine, listeners
├── rive.yaml
├── Inter.ttf
├── director.luau        story clock and dialogue
├── track.luau           cursor → eyes
├── fog.luau  crt_overlay.luau  trail.luau  horror_layer.luau   one per shader layer
├── shaders/             fog.wgsl  crt.wgsl  ghost.wgsl  horror.wgsl
└── build/               noviqo-halloween.riv
```
"# noviqo-halloween" 
