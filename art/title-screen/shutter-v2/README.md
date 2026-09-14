# Food-truck shutter main menu

Landscape 400×240 layout. The only in-game prompt is **PRESS A TO START**.
The HTML review page has a replay button and scrubber outside the game screen.

## Independent layers

- `shutter-west-coast-v3.png`: current shutter with a wider West Coast graffiti
  burger, interlocked arrows, double outlines, extrusions and long flourishes.
- `shutter-graffiti.png` and `interior.png`: previous art, no longer used.
- `gameplay-reference.svg`: static first-screen layout made from existing
  repository sprites, not a simulator screenshot or playable game.
- `title-ink-master.png`: independent black title on white, generated separately.
- `title-bun-rush.svg`: portable transparent title overlay with its PNG master
  embedded; a luminance filter supplies transparency and a white keyline.
- `main-menu-preview.png`: screenshot of the composed HTML menu, not a Playdate capture.
- `preview.html`: local interactive animation; press A or click the screen.
- `prompts.json` and `prompts-west-coast-v3.json`: exact built-in image_gen prompts.

The two transparency-generation attempts baked a checkerboard into RGB pixels.
The clean title master replaces those attempts. The SVG/HTML compositor masks
white and retains black; the alpha is clipped to SourceAlpha to avoid a black
rectangle outside the source image. The title remains an independent layer,
with a small independent jolt, while its parent follows the shutter upward.

## Timeline

- 0–0.14 s: prompt disappears and shutter rattles by about one logical pixel.
- 0.14–1.26 s: shutter and title rise, clipped behind the fixed upper rail.
- 1.26–1.50 s: hold on the black interior; the frame clears at 1.30 s.
- 1.50–2.20 s: dissolve the black cover to the gameplay layout using 64
  precomputed Bayer steps. No kitchen illustration, zoom or opacity crossfade.

Repeated A presses do not restart the sequence. Reduced-motion preference
skips to the gameplay layout reference. The page is a motion study, not gameplay.

## Verification and integration boundary

Headless Chrome checks exercised A input, mid/open states, prevention of a
second start, the exact single prompt, and absence of JavaScript exceptions.
Closed, half-open, black, dissolving and final frames were inspected, including
the menu at 400×240. The black hold was verified as all-black interior pixels. The title
keyline/mask artifact found in the first render was fixed and rechecked.

These are art masters and a browser motion study, not game-ready 1-bit exports.
No startup Lua or game metadata has changed. On Playdate, prepare fixed-size
bitmaps and masks offline; the shutter can then move using clipping and integer
blits. The final handoff should reveal the actual game render under a cached
ordered-dither cover; gameplay input must wait until the cover is gone. Do not load SVG or these high-resolution masters at runtime.

## Current road intro (v4)

The preview now begins with the food truck on a moving road, zooms into the
shutter, then slides in the title with particles. Its waiting menu has subtle
vertical bob. See `../road-v4/README.md` for the full current timeline and
art sources. The opening/black/dissolve timings above are relative to A.

Current driving motion is revised in `road-v5` (a sibling of `road-v4`):
whole-truck bounce plus fast scrolling scenery and road. The live page
remains `shutter-v2/preview.html`. See the v5 README for updated speeds.

The current truck is the coarse bitmap redraw from `../truck-v6/`, with
a measured full-opening shutter and updated camera/clip geometry.
