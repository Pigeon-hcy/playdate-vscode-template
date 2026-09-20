# Native game startup

`source/main.lua` now runs `TitleScreen` before gameplay. The browser page
remains an art/motion preview; it is not required or loaded by the game.

- 0–2.7 s: 81 native 400×240 frames at 30 fps cover the moving road/scenery,
  rotating wheels, whole-truck bounce and zoom into the large shutter.
- 2.8–3.02 s: the separately masked title slides into place.
- At 75% of travel distance (2.881409 s), 48 large pixel particles emit from
  the moving RUSH word. They ease toward rightward endpoints, shrink during
  their final 35%, and expire after 1.05–1.40 s, including during menu waiting.
- At 3.6 s: the sole prompt, PRESS A TO START, becomes available. The shutter
  continues to bob. Early A presses do not skip the intro.
- A captures the actual initial game scene once, settles/rattles the door,
  raises it over black, holds black, then dissolves to that scene using the
  SDK's native 8×8 Bayer drawing pattern. Input remains isolated through the
  last transition frame. The existing first-visit help then works normally.

Orders, cooking, gameplay effects, help, and station input remain frozen during
startup; crank input is drained. Returning from the system menu resets the
frame clock so suspended time does not advance either startup or gameplay.

## Runtime cost

All shipped pixels are native-size, binary black/white with binary alpha.
The road performs one image-table blit per frame; its table is released at
2.7 s. Its raw opaque pixel payload is about 987 KiB before SDK overhead.
No runtime zoom, rotation, SVG, high-resolution art, or frame construction is
needed. The live title uses cached shutter/title/prompt images and a fixed
48-entry particle pool. Particles are retired after expiry. The A transition
uses one 400×240 game snapshot and integer image blits; all startup images and
particle references are released on completion. Compiled art is about 322 KiB.
Device frame time has not been benchmarked.

## Rebuilding

1. Run `node tools/render_title_frames.cjs <temporary directory>` with
   Playwright available through Node resolution or NODE_PATH. Set CHROME_PATH
   if Chrome is installed outside the macOS default location.
2. Run `python3 tools/build_title_assets.py <temporary directory>` with Pillow.
   This exports `source/resource/title` and generated `source/titleAssets.lua`.
3. Run `pdc -k -s source bin/Output.pdx` using the installed Playdate SDK.

Generated PNGs are checked in so an ordinary game build needs only the SDK.
The original approved illustrations, title layer and full generation prompts
remain in the sibling art directories. No new generative artwork was needed.

## Validation

`python3 tests/titleScreen/run.py` (Pillow + lupa/Lua 5.4) executes the actual
title controller and main startup code with an instrumented SDK boundary.
It checks frame indices, early/repeated A, 75% burst origins, deceleration,
expiry while idle, snapshot capture, black hold, dissolve, final handoff,
clock/input/help isolation, crank draining, pause/resume, and resource release.

The PNGs here replay the actual Lua draw commands with native bitmap assets
for visual review; they are not Playdate simulator or physical-device captures.
The full game compiled successfully with pdc. Actual device performance and
SDK rendering have not been measured by the host-side tests.
