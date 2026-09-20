#!/usr/bin/env python3
"""Count actual Lua title draw calls over deterministic 30 FPS phases.

The graphics boundary counts calls and touched pixel area; this is not a
hardware FPS benchmark. Optional first argument profiles another controller.
"""
from pathlib import Path
import sys
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals()['import'] = lambda name: None
lua.execute((ROOT / 'source/titleAssets.lua').read_text())
lua.execute((ROOT / 'source/loadingAssets.lua').read_text())
lua.execute('''
stats={blits=0,fills=0,clears=0,pixels=0}
local sizes={title={310,56},prompt={108,10}}
local gfx={kColorBlack=0,kColorWhite=1,kDrawModeCopy=0,kDrawModeFillWhite=1,image={kDitherTypeBayer8x8=1},imagetable={}}
playdate={graphics=gfx}
function gfx.image.new(name,height)
    local size=type(name)=="string" and sizes[name:match("([^/]+)$")] or nil
    local w,h=size and size[1] or 400,size and size[2] or 240
    return {draw=function() stats.blits=stats.blits+1;stats.pixels=stats.pixels+w*h end}
end
function gfx.imagetable.new()
    return {drawImage=function() stats.blits=stats.blits+1;stats.pixels=stats.pixels+96000 end}
end
function gfx.clear() stats.clears=stats.clears+1;stats.pixels=stats.pixels+96000 end
function gfx.fillRect(x,y,w,h) stats.fills=stats.fills+1;stats.pixels=stats.pixels+w*h end
local noop=function() end
gfx.pushContext=noop;gfx.popContext=noop;gfx.setDrawOffset=noop;gfx.clearClipRect=noop
gfx.setImageDrawMode=noop;gfx.setLineWidth=noop;gfx.setColor=noop;gfx.drawRect=noop
gfx.setDitherPattern=noop;gfx.setPattern=noop
function gfx.getSystemFont()
    return {getTextWidth=function() return 80 end,getHeight=function() return 16 end,drawText=noop}
end
local ready=function() return true end
function profile(start,frames,exit)
    TitleScreen.initialize();TitleScreen.update(start,0,false,ready,noop);TitleScreen.draw()
    if exit then TitleScreen.update(0,10,false,ready,noop) end
    stats={blits=0,fills=0,clears=0,pixels=0}
    for i=1,frames do TitleScreen.update(1/30,exit and 10 or 0,false,ready,noop);TitleScreen.draw() end
    return stats
end
''')
source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'source/titleScreen.lua'
lua.execute(source.read_text())
for name, start, frames, exiting in [('road', 0, 80, False), ('title+particles', 2.7, 48, False), ('idle menu', 5, 300, False), ('exit', 5, 90, True)]:
    result = dict(lua.globals().profile(start, frames, exiting))
    print(f'{name}: frames={frames}, ' + ', '.join(f'{key}={value}' for key, value in sorted(result.items())))
