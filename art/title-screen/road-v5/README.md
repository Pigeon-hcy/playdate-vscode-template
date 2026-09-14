# Whole-truck bounce and fast scenery

The live page remains `../shutter-v2/preview.html`.

- `scenery-panorama.png`: generated black-and-white West Coast roadside art;
  exact image_gen prompt is in `prompts.json`.
- `driving-preview.png`: browser capture of the current driving composition.

The truck and its mounted menu share one vertical transform. Two waves produce
up to 2 screen pixels of bounce. Dividing by the camera scale prevents the
zoom from magnifying that displacement. The shutter retains a smaller local
vibration, and both settle over the first 0.14 seconds after A.

The truck art is rendered at 90% with its white exterior clipped by a fixed
vehicle silhouette. White painted body panels remain opaque, while scenery
shows around the roof, bumpers and wheels. The camera target incorporates
this placement, so the zoom still lands exactly on the same shutter.

Scrolling speeds in logical pixels per second:

- Panoramic scenery: 95.
- Near roadside poles/rails: 165.
- Road markings: 290, increased from 70 in v4.

The panorama tiles horizontally, and road/roadside geometry is built once.
All three layers scroll independently from the vehicle bounce. No objects
are created during the animation loop. Full game integration remains pending;
the reveal target is still the static layout reference made from game assets.

Headless Chrome verification covered changed vehicle positions, all scrolling
layers, the unchanged camera during the wide shot, the zoom, title particles
and their expiry, the waiting menu, A gating and the full exit. The wide frame
was visually checked for the silhouette and background layering; the black
hold remains fully black inside the viewport.
