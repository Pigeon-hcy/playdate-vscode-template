# Orders

The game starts with one order. A new order arrives after a random integer
delay from 20 through 40 seconds, then the next delay is sampled. Each order
has its own 60-second lifetime, measured in seconds rather than frames.

Up to six orders can be pending. An arrival at capacity is skipped and the
normal arrival schedule continues, without accumulating a hidden backlog.
Expired orders are removed before input is processed on that frame. Switching
workstations and playing delivery animations do not stop the order clock.

Orders request one burger each and do not specify a recipe. The existing
assembly recipe rules still determine whether a burger is correct. Any
submission consumes the order nearest its deadline when the outgoing
animation begins. An incorrect burger still costs the customer their order.

Scoring lives in `source/scoring.lua` with constants in
`PlayerConfig.scoring`. A correct burger earns
200 + (distinct ingredients × 5 + total ingredients × 3) × 20 + whole seconds
left on the served order × 10, and the whole sum is multiplied by 1.5 during
rush hour: from 520 for the two-ingredient LONE COW to 1800 for ALL IN before
any time bonus. A wrong burger costs 500 and an order that expires unserved
costs 800, applied through the queue's `onOrderExpired` hook wherever the
shared queue is used. A rush issues far more orders than can be served, so a
miss during one costs a quarter of that (200). The score never drops below zero; a penalty that would is cut
short, though the feedback still shows the full penalty. The assembly panel
shows the points gained or lost beside the last result, and every change
also springs a pill up from the bottom of the screen on any station
(`source/scorePopup.lua`, tuned in `PlayerConfig.scorePopup`): Roobert 24
digits, white for gains and black for losses, overshooting slightly, resting
1.2 seconds and dropping away. With no orders, the burger is kept on the assembly
table, serving is blocked, and the recipe panel displays **NO ORDERS!**.

## Rush hour

The first rush begins at a random moment between 3 and 4 minutes into the
game, lasts 2 minutes, and the next begins a random 3.5 to 4.5 minutes after
the previous one ended. When a rush begins, every waiting order keeps only
half of its remaining time, and from then on a new order arrives every 1 to 2
seconds whenever a slot is free, so a holder with one ticket fills up over the
next several seconds and stays full for the rest of the rush. Orders that
arrive during the rush live half a normal lifetime (30 seconds). Because
tickets retract according to their remaining time, every existing order and
every rush order starts retracting immediately.

Shortened deadlines issued during a rush are kept after it ends; new orders
then live the full 60 seconds again and arrivals return to the 20 to 40 second
pace, counted from the end of the rush. Serving picks the pending order nearest its deadline,
which is no longer always the oldest one once a rush has shortened some
deadlines. Tuning is in `PlayerConfig.orders.rush`; omit that table to disable
rushes entirely. Rush changes are replayed in chronological order with
arrivals, so a long frame produces the same queue as many short ones.

## Rush banner

`source/rushBanner.lua` announces both transitions full screen. The order
manager calls its optional `onRushStart` and `onRushEnd` hooks, which
`main.lua` wires to the banner. While a banner is active the game is frozen:
no clocks, cooking, transitions or input advance, crank movement is
discarded, and the last frame is redrawn from the untouched state beneath the
overlay.

- Start: the screen snaps to white in 0.10 seconds, then **RUSH** and
  **HOUR** slam down in turn from three times their size, each impact
  inverting the screen for two frames and shaking the block. The words hold
  for 1.5 seconds after the second lands, then everything dissolves back.
- Over: the same white snap, then **RUSH / HOUR / OVER** is typed one
  character every 0.08 seconds with a blinking block cursor, holds for 1.5
  seconds and dissolves.

Words are rendered once at load from Roobert 24 at the largest integer
scale that fits, so every frame is a plain blit except while a word is still
falling. Tuning is in `PlayerConfig.rushBanner`. `tests/rushBanner/main.lua`
checks the timeline and lets A and B replay either banner.

## Receipt UI

The holder is flipped vertically once on load and fixed to the very top
centre of every workstation, with receipts hanging down beneath it. It is
drawn after workstation transitions, so the tickets stay in place and continue
updating while stations slide behind them. Tickets keep their slots when
another ticket is served or expires.

- Arrival: slide down from above the screen in 0.20 seconds.
- More than 30 seconds remaining: remain seated in the holder.
- Last 30 seconds: move upwards linearly, independently for each ticket. A
  ticket whose deadline was halved by a rush, or issued during one, is
  already inside this window and starts moving at once.
- Last 10 seconds: the ticket flashes inverted at 2 Hz, on a phase shared
  by every urgent ticket. Tuned by `urgentSeconds` and `blinkHz`.
- Deadline: expire; the ticket is fully retracted behind the holder.
- Completion: the fulfilled ticket disappears immediately.

`source/orderManager.lua` owns the queue and clock. `source/orderRuntime.lua`
creates the shared `Orders` instance. `source/orderUI.lua` draws the two sprite
assets. Tuning is in `PlayerConfig.orders`. The manager accepts an injected
random-delay function for deterministic tests.

The 168×10 holder and 22×28 receipt are loaded once and drawn at 1:1. Each
frame draws at most six receipts and one holder, without image allocation,
scaling, per-order timers or a full-screen UI cache. The original generated
art, prompts and export instructions are in `art/orders/README.md`.

## Validation

`tests/orders/main.lua` exercises separate deadlines, the half-life threshold,
offscreen arrival and expiry, six-order capacity, random interval bounds,
long-frame equivalence, stable slots, earliest-deadline priority, correct and
incorrect submissions (both consume an order), duplicate submission, no-order
protection, and rush hour: halved remaining waits, one arrival per second
until full, half-lifetime rush orders, refills, cooldown, and a configuration
with rushes disabled.

Stage a test `main.lua` and `source/resource` in a temporary directory, then
compile it with `pdc -k -I source <staging-directory> <output.pdx>`. Open the
result in Playdate Simulator; success is printed to the console. The order
test demo lets A advance 10 seconds, B complete the order nearest its
deadline, and LEFT start a rush hour by hand.
