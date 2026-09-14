# Truck art and full-window shutter revision

The live page remains `../shutter-v2/preview.html`.

- `truck-style-master.png`: first redraw with chunky pixel contours and
  substantial patterned black-and-white shading, based on the game's patty
  and grinder artwork.
- `truck-large-shutter.png`: current taller cargo box with a much larger
  opening; the cab, tires and lower chassis preserve the successful redraw.
- `driving-preview.png`, `zoom-preview.png`, `menu-native-preview.png`:
  browser captures of the composed scene, not Playdate simulator screenshots.
- `prompts.json`: full built-in image_gen prompts and measured opening bounds.

The generated source is 1620×971. The plain opening measures x143–1068 and
y118–638, with minor edge variation. The displayed shutter uses a one-pixel
bleed: x142, y117, width928, height523. It covers the full opening instead of
centering a smaller 5:3 rectangle inside the window. The previous inner rails
were replaced with a single thin outline; the truck art supplies the outer rim.

The physical opening differs slightly from 5:3, so the mounted SVG fills it
explicitly. The camera interpolates its horizontal and vertical scale to
land exactly on the 400×240 menu without blank bands or clipped controls.
The truck placement is (20,12) at scale .9, with a revised silhouette clip
matching the new body and wheels. Bounce compensates against vertical zoom.

The existing fast parallax scenery, road motion, whole-truck bounce, title
arrival/particles, menu waiting state and A-triggered shutter/black/dissolve
sequence are preserved. Headless Chrome checks passed for these behaviors;
wide, zoom and native-size menu frames were visually reviewed. The black hold
was also checked for all-black interior pixels.

These are updated art and browser-preview assets; no game Lua or compiled
game package was changed in this revision.

## Wheel and title motion (v7)

Both wheels rotate clockwise using clipped copies of the existing truck image,
with angular speed tied to the scrolling road. Their layers share the body's
bounce. No additional raster assets are loaded.

The title enters from 2.80–3.02 seconds (220 ms). At arrival, 16 pooled pixel
particles burst from its right edge, travel right and expire after 240–345 ms,
including while the menu is waiting. No particles appear before arrival.

Headless browser checks verified both wheel rotations, title timing, rightward
particle movement and expiry, plus the existing zoom, bounce, scenery, A gating
and exit sequence without JavaScript errors. `title-arrival-preview.png` shows
the arrival burst; `driving-preview.png` includes the rotating wheel layers.

The v8 adjustment triples particle width and height (6×3 through 12×6 pixels)
and spreads the 16 emission points across the full RUSH word, instead of only
its right edge. Landing timing, rightward velocity and lifetime are unchanged.

The v9 burst uses 48 pooled particles lasting 1.05–1.40 seconds. Their position
interpolates toward a fixed rightward endpoint with cubic ease-out, reducing
speed to zero. During the final 35% of each lifetime, particles shrink to a
pixel and disappear; the effect stays monochrome. Emission still covers RUSH
and begins at title arrival. Browser checks confirmed decreasing displacement
over equal time intervals, 48 particles still alive after 580 ms, late shrink
and full expiry while waiting at the menu.

In v10, emission starts when the title has covered 75% of its travel distance.
Inverting its cubic ease-out gives 2.881409 seconds (about 81 ms into the slide).
Origins follow RUSH's position at that instant; particles continue toward the
existing endpoints. Count, sizes, lifetime, deceleration and shrink are retained.
Browser checks cover just before/after the threshold and the moving origin.
