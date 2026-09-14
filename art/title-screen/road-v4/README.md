# Road intro and title arrival

The current interactive preview remains `../shutter-v2/preview.html` so the
existing local preview URL continues to work. `truck-side.png` is the current
image_gen truck art; `truck-side-master-v1.png` is the initial wider-hatch draft.
Exact generation prompts are in `prompts.json`. A copy of the current truck
image sits beside the HTML as `truck-side-v4.png` for the scoped local server.

## Motion

- 0–1.30 s: the truck remains stationary; repeating road marks move left.
- 1.30–2.70 s: a single camera transform zooms into the mounted shutter.
- 2.80–3.40 s: the independent title slides in from the left with a trailing
  pool of 20 small ink particles; each particle expires independently.
- At 3.60 s: PRESS A TO START appears. The intro waits indefinitely for A.
  The shutter and title bob vertically by at most 2 logical pixels, combining
  two low-amplitude waves. The frame and start hint stay still for readability.
- A: the bob settles, followed by the existing 2.2-second shutter opening,
  black hold and ordered-dither reveal of the gameplay layout reference.

The shutter art is the same image at wide and close views. It is mounted
inside a 101×60.6 region at (96.5,68.1) in the 400×240 truck scene, maintaining
5:3 proportions inside the illustrated hatch. The camera lands exactly on it.
The title is not drawn during the road/zoom portions. No wheel rotation,
moving truck sprite, background parallax or new kitchen illustration is used.

Road marks, title particles and 65 dissolve masks are constructed once.
Particles do not respawn during the menu wait. Repeated/early A presses are
ignored. Hidden tabs stop animation. Reduced-motion mode skips the intro and
idle bob, and A cuts to the ending reference.

## Validation and scope

Headless Chrome checks cover the stationary truck and moving road, zoom,
visible title particles, automatic arrival at the waiting menu, persistent
bob, expired particles, A gating, and the outgoing transition. Wide, zoom,
title arrival, native 400×240 menu, black, dissolve and end frames were checked.

This is an updated art/motion preview, not a game startup implementation.
The ending image remains a layout reference using existing game sprites.
No Lua files, game metadata or compiled game package were changed.

Current driving motion is revised in `road-v5` (a sibling of `road-v4`):
whole-truck bounce plus fast scrolling scenery and road. The live page
remains `shutter-v2/preview.html`. See the v5 README for updated speeds.
