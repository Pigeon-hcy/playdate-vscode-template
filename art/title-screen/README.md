# Cover and main-menu concepts

Working title: **BUN RUSH**. Naming is still under discussion; game metadata
and the startup flow have not been renamed or changed.

- `concepts/bun-rush-cover-v1.png`: portrait cover / promotional key art.
- `concepts/bun-rush-main-menu-v1.png`: landscape main-menu concept with
  START SHIFT, HOW TO PLAY and an A-button selection hint.
- `prompts-v1.json`: exact prompts and references, generated using the
  built-in image_gen tool.

The coarse black ink / halftone treatment references the existing patty,
American cheese and grinder artwork. These are high-resolution concept
originals, not finalized 400×240 1-bit runtime images. No images from this
folder are included in the game build. Before integration, the menu art needs
native-size readability review and conversion into a static background, with
interactive menu labels and selection drawn separately and cached.

Naming candidates supplied by the user:

- Crank, Serve, Delicious! — direct cooking-game tribute; emphasizes crank input.
- Bun Rush — compact food + rush-hour name, currently used in these concepts.
- Needs for Burger — proposed speed-film tribute. Suggested English refinement:
  Need for Burgers, or the rhyming Need for Feed. Need for Speed is the racing
  game title; Fast & Furious is the film-series title.

Additional wordplay: Bun for Your Life, from Run for Your Life. Naming
availability and trademark clearance have not been checked.

## Current menu direction

The current revision is `shutter-v2/`: a horizontal food-truck roller shutter
with abstract burger graffiti, a separately animated title, and only
PRESS A TO START. See its README and interactive `preview.html`.

The latest opening sequence adds the road intro documented in
`road-v4/README.md`; its live page is still `shutter-v2/preview.html`.

Current driving motion is revised in `road-v5` (a sibling of `road-v4`):
whole-truck bounce plus fast scrolling scenery and road. The live page
remains `shutter-v2/preview.html`. See the v5 README for updated speeds.

The current truck artwork and full-window shutter mapping are documented in
`truck-v6/README.md`; the interactive page remains `shutter-v2/preview.html`.
