# Workstation events

Sudden events interrupt a single workstation. They are owned by that
workstation, so their state, input handling and drawing all live in its
module and only appear while the player is standing at it. Other stations,
the order clock and cooking carry on regardless.

`source/burstDialog.lua` draws the shared announcement: a comic starburst
panel that springs in, can be jolted, and pops away. The owner supplies a
content box and a function that draws inside it, and the whole panel is baked
into one image at load, so showing it allocates nothing and each frame is a
single blit. The dialog is driven by a clock passed in rather than counting
its own time, so it follows the shared Juicy instance and freezes with the
rest of the game under a rush banner. Tuning is in `PlayerConfig.burstDialog`.

## Grinder: meat jam

After cooldown, the grinder randomly chooses the first, second or third new
piece of meat and seizes halfway through that piece. A piece counts when the
player first cranks it, not merely when it is loaded. Its random yield does
not affect the piece count, and even a large crank sample stops at the jam:

- A starburst reading **MEAT JAM! / MASH DOWN** with a down arrow springs up
  over the machine, and the body shakes for half a second.
- Grinding stops. Cranking produces no mince, the meat stops feeding down the
  hopper, and the drawn crank freezes at the angle it stuck at. Rotation made
  while stuck is read and discarded rather than banked for the moment it
  clears.
- DOWN no longer loads meat; it strikes the machine. Each press shakes the
  body hard, recoils it sideways, knocks a few crumbs loose and jolts the
  panel. Crumbs carry no yield.
- A random 3 to 6 presses free it. The panel pops away and grinding resumes
  immediately.
- Clearing starts a 20-second cooldown. Pieces started during that window
  are exempt even if finished later. The remainder of the jammed piece is
  also exempt, so one piece cannot jam twice. After cooldown, a fresh random
  target of 1–3 new pieces applies.

An empty machine cannot jam, and a jam cannot restart while one is running.
Tuning is in `PlayerConfig.grinder.jam`.

## Validation

`tests/grinderJam/main.lua` covers all three piece targets, large crank samples,
cooldown-spanning pieces, interrupted yield, the frozen output, crank
and meat feed, the press count, the cooldown, the empty-machine guard, and
the panel's own animation curve. The demo forces a jam with A and mashes it
free with DOWN.

Stage a test `main.lua` and `source/resource` in a temporary directory, then
compile it with `pdc -k -I source <staging-directory> <output.pdx>`.

## Fryer: burn warning

Each patty costs 30 mince; the grinder supplies 15 per full crank turn, so a
patty requires two turns before cooking. A raw meat load yields 60–100 mince
(80 on average), enough for two or three patties with leftovers retained.
Across loads this averages 2.67 patties per load. The fryer help card reads the current price from
`PlayerConfig.frying.pattyCost`; its persistent counters and hints are hidden.

`source/fryingWarning.lua` is a shared, non-modal overlay. A cooked patty
within `PlayerConfig.frying.warning.leadSeconds` (default 3 seconds) of
burning triggers an arrow above a **FRYER! / HURRY!** starburst. From station
1 the arrow points right, from station 3 it points left, and on station 2 it
points up toward the grate. Both arrow and dialog shake by 1–3 pixels,
increasing with urgency. This is visual shake of the warning itself.

The warning follows the most urgent occupied slot and changes to
**FRYER! / ON FIRE!** if a patty burns. It remains until the danger is removed;
collecting or discarding excludes that patty immediately, even while its exit
animation is still visible. Other urgent patties keep the warning alive.
Cooking and input continue throughout. The overlay follows the shared game
clock, freezes under help/rush screens, and is hidden during station slides.
On the fryer, the fire-clearing dialog below replaces the small warning while
it is visible; the directional warning remains available on other stations.

`tests/fryingWarning/main.lua` covers the lead boundary, navigation directions,
multiple patties, burn escalation, collection/discard cleanup, and frozen
shake. Compile directly with `pdc -k -I source tests/fryingWarning <output.pdx>`.

## Fryer: mash B to put out a fire

Each burning patty takes 3–6 separate B presses to extinguish. The first
burning slot has priority; B cannot collect cooked patties while any fire
remains. Holding B counts only its initial press. Progress stays with the
patty when switching stations, and a second fire does not reset that progress.

A **FIRE! / MASH B TO PUT OUT** starburst springs up on the fryer, matching the
grinder's jam panel. Every press jolts the panel and shakes the grate, patties
and flames together. The final press extinguishes and discards that ruined
patty, without adding inventory or also collecting a cooked one. Another
burning patty starts its own press sequence; after the last fire the panel
pops away and B returns to collecting cooked patties. Cooking continues in
all slots throughout. Settings are in `PlayerConfig.frying.fire`.

`tests/fryingFire/main.lua` covers ignition, repeated presses, held-button
rejection, offscreen progress, multiple fires, inventory and warning cleanup.
Stage it beside `source/resource` as described above. The demo burns its two
starting patties after four seconds.

# Controls cards

Every workstation declares a `help` table beside the code it describes: a
title, a one-line summary and a list of controls, each a key glyph and what
it does. `source/helpCard.lua` bakes that into a card when shown: the station
number and name on a black band, the summary, the controls with their keys
right-aligned in one column, and a footer reminding the player that LEFT and
RIGHT change station and A closes the card.

- The card opens the first time the player settles on each station in a
  session, starting with the grinder at launch.
- It reopens for the current station from the Playdate system menu item
  **controls**.
- While it is open the game is frozen exactly as under a rush banner. A or B
  closes it; play resumes at once while the card falls away. The closing press
  never reaches the station underneath.

Button glyphs (Ⓐ Ⓑ ⬆ ⬇ ⬅ ➡ and the crank 🎣) come from Roobert 10 Bold,
the only bundled font that carries all of them. The remaining workstation operation hints use the same glyphs and font,
so the card and screen describe controls consistently. When a control changes, update that station's `help`
table with it. Seen state lasts for the session only.

`tests/helpCard/main.lua` checks each station's help table, that every card
fits on screen, and the card's open, settle, close and fall-away timeline.


## Supply prompts and simplified workstation UI

`source/supplyWarning.lua` opens only when a consumption attempt fails:
A on the fryer with less mince than `pattyCost`, or A/DOWN while adding P
at assembly with no cooked patties. Empty inventory, entering a station,
adding another ingredient, and successfully spending the last unit do not
open it. The burst stays for `PlayerConfig.supplyWarning.lifetime` (1.5 seconds)
after the most recent failed press, then plays its pop-away animation. Repeated
failed attempts jolt the same cached burst and refresh its lifetime; a failed
press during or after exit opens it again. Empty stock never reopens it. The arrow
points to the grinder for mince or the fryer for patties. Replenishing stock
pops the prompt away; leaving its source station cancels it, so returning
requires a new failed attempt. Fire warnings take visual priority. All
animations use the shared game clock and freeze with help/rush overlays.

`source/stationArrow.lua` pre-bakes three directions once and shares them
with fire warnings. Supply burst images are also built once at load.
`source/minceCounter.lua` pre-bakes gray digits at three integer sizes;
only a changed integer quantity recalculates their layout. The number draws
behind the grinder, followed by the machine and its operation hint. Fryer
station labels, counters and bottom hints are removed; navigation, orders,
help and emergency events remain. Assembly removes only its patty counter;
the ten ingredient abbreviations remain visible. Recipe names use a cached
92×32 image with word wrapping and bounded truncation for future names.

`tests/stationUI/main.lua` covers failed consumption, exact-price success,
unrelated ingredients, closed burgers, leaving/returning, replenishment and
full-title fit for every current recipe. Compile and launch in the simulator
as described above; compilation alone does not execute these assertions.
