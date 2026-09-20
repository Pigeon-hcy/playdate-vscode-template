# Loading artwork

The built-in image_gen tool created the original burger illustration and then
edited it into `loading-text-generated.png`. Only the hand-lettered LOADING...
and underline are used in the game.

Run `python3 tools/build_startup_loading.py` to convert the selected art to
400×240 monochrome, build the fixed-pattern horizontal dissolve tables, and
build the launcher's appearance animation. Runtime loading uses the same art.

## Final edit prompt

Edit this game loading artwork: remove the entire hamburger illustration and every motion mark around it. Keep ONLY the exact existing friendly, rounded hand-drawn white lettering "LOADING..." and its small curved white underline, preserving their letter shapes and relative spacing. Recenter that lettering-and-underline group both horizontally and vertically on the pure solid black canvas, keeping approximately its current width (about one-third of canvas width). Landscape aspect 5:3. No burger, food, icons, sparks, other text or decoration. Crisp white-on-black graphic suitable for a 400x240 1-bit Playdate screen. Preserve the existing soft bouncy handmade typography, do not replace it with a typeset font.
