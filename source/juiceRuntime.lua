import "juicy"

-- The game's single Juicy instance. main.lua advances it once per frame,
-- before input, so an effect triggered this frame is drawn from its start
-- pose. Every workstation shares it, so effect ids must stay unique across
-- workstations, and a workstation must retire only the ids it owns
-- (Juicy:remove) rather than calling Juicy:clear.
Juice = Juicy.new()
