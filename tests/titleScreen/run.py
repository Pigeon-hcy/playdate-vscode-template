#!/usr/bin/env python3
"""Run real titleScreen.lua/main.lua against an instrumented Playdate boundary.

Requires lupa (Lua 5.4) and Pillow. This tests Lua behavior, not SDK performance.
Optional argument: output directory for native bitmap composition snapshots.
"""
from pathlib import Path
import os
import sys
from lupa.lua54 import LuaRuntime
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/bun-rush-native-title')
OUTPUT.mkdir(parents=True, exist_ok=True)
lua = LuaRuntime(unpack_returned_tuples=True)
loaded = set()
imports = []
imports_allowed = True
version = os.environ.get('BUN_RUSH_TEST_VERSION', 'original')


def load(name):
    assert imports_allowed, "import() called outside of pdz loading"
    imports.append(name)
    if Path(name).name == 'juiceRuntime':
        lua.execute('assert(startupFlushes==1,"startup loading must reach display before game assets load")')
    if name == 'CoreLibs/crank':
        # This helper belongs to the Lua library, not the native Playdate API.
        lua.execute('playdate.getCrankTicks=function() drains=drains+1 return 0 end')
    if name.startswith('variants/') and name.endswith('/main'):
        lua.execute((ROOT / 'source' / f'{name}.lua').read_text())
    if name in ('titleScreen', 'titleAssets', 'loadingAssets', 'gameVersions') and name not in loaded:
        loaded.add(name)
        lua.execute((ROOT / 'source' / f'{name}.lua').read_text())


lua.globals()['import'] = load
lua.execute('''
calls = {}
liveAssets = setmetatable({}, {__mode="v"})
local function record(kind, ...) calls[#calls + 1] = {kind, ...} end
local context = nil
local color = 0
local gfx = { kColorBlack=0, kColorWhite=1, kDrawModeCopy=0, kDrawModeFillWhite=1,
    image={kDitherTypeBayer8x8=1}, imagetable={} }
playdate = {graphics=gfx}
playdate.buttonJustPressed=function() return false end
function gfx.image.new(name, height, background)
    if type(name) == "number" then name = background == 0 and "loading" or "snapshot" end
    local image = {name=name,draw=function(self,x,y)
        record("image",self.name,x,y,self.hasHelp)
        if self.name=="snapshot" then screenHasHelp=self.hasHelp end
    end}
    liveAssets[name] = image
    return image
end
function gfx.imagetable.new(name)
    local images = {drawImage=function(self,index,x,y)
        assert(index>=1 and index<=81)
        record("image",name.."-table-"..index,x,y)
    end}
    liveAssets[name] = images
    return images
end
function gfx.clear(value) record("clear",value or 1) end
function gfx.setColor(value) color=value end
function gfx.setDitherPattern(alpha) assert(alpha>=0 and alpha<=1);record("dither",alpha) end
function gfx.fillRect(x,y,w,h) record("fill",x,y,w,h,color) end
function gfx.drawRect(x,y,w,h) record("rect",x,y,w,h,color) end
function gfx.pushContext(image) context=image end
function gfx.popContext() context=nil end
function recordHelp(visible)
    if context then context.hasHelp=visible else screenHasHelp=visible end
end
function gfx.setDrawOffset() end
function gfx.clearClipRect() end
function gfx.setImageDrawMode() end
function gfx.setLineWidth() end
function gfx.drawText() end
function gfx.getSystemFont()
    return {getTextWidth=function() return 80 end,getHeight=function() return 16 end,
        drawText=function(self,text,x,y) record("text",text,x,y) end}
end
function count(kind)
    local n=0 for _,call in ipairs(calls) do
        if call[1]==kind and (kind~="fill" or call[6]==0) then n=n+1 end
    end return n
end
function imageCall(name)
    for _,call in ipairs(calls) do if call[1]=="image" and call[2]==name then return call end end
end
captures,preparations=0,0
function prepareGame()
    assert(imageCall("SystemAssets/launchImage") == nil,"loading work happened inside draw")
    preparations=preparations+1
    return preparations>=3
end
function gameDraw() captures=captures+1 end
function step(dt,change,docked)
    calls={};TitleScreen.update(dt,change or 0,docked or false,prepareGame,gameDraw);TitleScreen.draw()
end
''')
load('titleScreen')
lua.execute('''
TitleScreen.initialize()
step(0)
assert(imageCall("resource/title/road-table-1"))
step(1,90)
assert(TitleScreen.getState()=="intro" and captures==0)
step(1.699)
assert(imageCall("resource/title/road-table-81"))
step(.0011)
assert(imageCall("resource/title/shutter") and count("fill")==0)
collectgarbage("collect")
assert(liveAssets["resource/title/road"]==nil,"road frames retained after zoom")
assert(not imageCall("resource/title/title"))
step(.181)
assert(count("fill")==0,"particles before 75% distance")
step(.001)
assert(count("fill")==48,"particles missing at 75% distance")
assert(imageCall("resource/title/title")[3]<TitleAssets.titleX,"burst waited for arrival")
for _,call in ipairs(calls) do
    if call[1]=="fill" and call[6]==0 then assert(call[2]>=96 and call[2]<=254,"wrong moving RUSH origin") end
end
step(.2)
local earlyX=nil
for _,call in ipairs(calls) do if call[1]=="fill" then earlyX=call[2];break end end
step(.2)
local middleX=nil
for _,call in ipairs(calls) do if call[1]=="fill" then middleX=call[2];break end end
step(.2)
local lateX=nil
for _,call in ipairs(calls) do if call[1]=="fill" then lateX=call[2];break end end
assert(middleX-earlyX>lateX-middleX,"particles did not decelerate")
assert(count("fill")==48,"particles disappeared too early")
step(.118,90)
assert(TitleScreen.getState()=="menu" and captures==0,"early crank movement leaked across readiness boundary")
assert(TitleScreen.shouldShowCrankIndicator() and not imageCall("resource/title/prompt"))
step(.55)
assert(count("fill")>0 and count("fill")<48,"particle lifetimes not staggered")
step(1)
assert(count("fill")==0,"particles did not expire in menu")
step(3600)
assert(TitleScreen.getState()=="menu" and captures==0)
step(.1,90,true)
assert(TitleScreen.getState()=="menu" and TitleScreen.shouldShowCrankIndicator(),"docked crank must not start")
step(.1,.1)
assert(TitleScreen.getState()=="menu","sensor jitter must not start")
step(0,90)
assert(TitleScreen.getState()=="exit" and captures==0 and preparations==0)
assert(not TitleScreen.shouldShowCrankIndicator())
local initialY=imageCall("resource/title/closed")[4]
step(.7)
assert(imageCall("resource/title/closed")[4]==initialY and TitleScreen.shouldShowCrankIndicator(),
    "stopped crank must pause shutter and show hint")
step(.1,90,true)
assert(imageCall("resource/title/closed")[4]==initialY and TitleScreen.shouldShowCrankIndicator(),
    "docking must pause shutter and show hint")
step(.1,-90)
assert(imageCall("resource/title/closed")[4]<initialY and not TitleScreen.shouldShowCrankIndicator(),
    "reverse crank must resume opening and hide hint")
step(.1,180)
assert(TitleScreen.getState()=="loading" and imageCall("resource/loading/in-table-1") and preparations==0,
    "loading must be presented before preparation")
assert(not TitleScreen.shouldShowCrankIndicator())
step(.2)
assert(imageCall("resource/loading/in-table-7") and preparations==0)
step(.2)
assert(imageCall("SystemAssets/launchImage") and preparations==0)
step(.1);step(.1);step(.1)
assert(preparations==3 and captures==0 and not imageCall("snapshot"),"capture started before loading completed")
step(.1)
assert(TitleScreen.getState()=="loadingOut" and imageCall("resource/loading/out-table-1"))
step(.2)
assert(imageCall("resource/loading/out-table-7") and not imageCall("snapshot"))
step(.2)
assert(TitleScreen.getState()=="enter" and captures==1 and imageCall("snapshot")[4]==-240)
local previousY=-240
for i=1,22 do
    step(1/30,90)
    local frame=imageCall("snapshot")
    assert(frame and frame[4]>=previousY and frame[4]<=0,"entrance must move down to zero")
    assert(count("dither")==0 and count("clear")==0,"entrance flashed a clear or dissolve")
    previousY=frame[4]
    if not TitleScreen.isActive() then break end
end
assert(not TitleScreen.isActive() and previousY==0)
collectgarbage("collect")
assert(next(liveAssets)==nil,"title resources retained during gameplay")
step(0,90)
assert(#calls==0 and captures==1 and preparations==3,"completed intro restarted or redrew")
print("PASS: title timing, particles, crank opening/pause/dock hints, horizontal loading dissolves, loading-before-work, downward slide and resource release")
''')

# Render the actual Lua draw commands with native bitmap assets for visual QA.
def save_frame(name):
    canvas = Image.new('RGB', (400, 240), 'white')
    drawing = ImageDraw.Draw(canvas)
    for _, call in lua.globals().calls.items():
        kind = call[1]
        if kind == 'clear':
            drawing.rectangle((0, 0, 399, 239), fill='white' if call[2] else 'black')
        elif kind == 'image' and call[2] not in ('snapshot', 'loading'):
            image = Image.open(ROOT / 'source' / (call[2] + '.png')).convert('RGBA')
            canvas.paste(image, (int(call[3]), int(call[4])), image)
        elif kind in ('fill', 'rect'):
            x, y, w, h = (int(call[i]) for i in range(2, 6))
            value = 'white' if call[6] else 'black'
            drawing.rectangle((x, y, x+w-1, y+h-1), **({'fill': value} if kind == 'fill' else {'outline': value}))
    canvas.save(OUTPUT / f'{name}.png')


for name, at in [('road', .8), ('zoom', 2.1), ('burst', 2.95), ('particles', 3.7), ('menu', 5)]:
    lua.execute(f'TitleScreen.initialize(); step({at})')
    save_frame(name)

# Exercise the real main.lua startup boundary, with existing game subsystems
# instrumented to catch updates, input, help, and clock leaks from the intro.
lua.execute('''
now, buttons, gameUpdates, inputCalls, drains, helpShows = 0, {}, 0, 0, 0, 0
stationInitializations=0
function finishLoading()
    for i=1,60 do
        calls={};now=now+34;playdate.update()
        if TitleScreen.getState()=="enter" then return end
        assert(TitleScreen.getState()=="loading" or TitleScreen.getState()=="loadingOut", "unexpected loading state")
    end
    error("loading never completed")
end
local pd=playdate
pd.kButtonA, pd.kButtonLeft, pd.kButtonRight=1,2,3
pd.kButtonB,pd.kButtonUp,pd.kButtonDown=4,5,6
pd.getCurrentTimeMilliseconds=function() return now end
pd.getSecondsSinceEpoch=function() return 1,2 end
pd.buttonJustPressed=function(button) return buttons[button] or false end
pd.getCrankTicks=nil
crankChange,crankDocked,indicatorDraws,indicatorResets=0,true,0,0
pd.getCrankChange=function() local change=crankChange;crankChange=0;return change end
pd.isCrankDocked=function() return crankDocked end
startupFlushes=0
pd.display={setRefreshRate=function() end,flush=function()
    assert(imageCall("SystemAssets/launchImage"),"startup flush needs the loading image")
    startupFlushes=startupFlushes+1
end}
pd.ui={crankIndicator={draw=function() indicatorDraws=indicatorDraws+1 end,resetAnimation=function() indicatorResets=indicatorResets+1 end}}
pd.getSystemMenu=function() return {addMenuItem=function(self,label,callback) controls=callback end} end
PlayerConfig={refreshRate=30,activeWorkstation=1,assembly={crankTicksPerTurn=12}}
Orders={time=0,reset=function(self) self.time=0 end,update=function(self,dt) self.time=self.time+dt end}
Scoring={}
Juice={update=function() gameUpdates=gameUpdates+1 end}
local function noop() end
local function no() return false end
GrinderWorkstation={initialize=function() stationInitializations=stationInitializations+1;now=now+500 end,help={}}
AssemblyWorkstation={initialize=function() stationInitializations=stationInitializations+1 end}
FryingWorkstation={isFireDialogVisible=no}
WorkstationManager={register=noop,getController=function() return GrinderWorkstation end,
    isSwitching=no,drawActive=function() return true end,updateTransition=noop,
    updateAll=function() gameUpdates=gameUpdates+1 end,
    handleActiveInput=function() inputCalls=inputCalls+1 end,
    switch=function() error("station input leaked into intro") end,
    shouldShowCrankIndicator=no}
WorkstationNavigation={update=noop,draw=noop}
OrderUI={draw=noop}
ComboUI={draw=noop}
FryingWarning={update=noop,isVisible=no,draw=noop}
SupplyWarning={update=noop,draw=noop}
ScorePopup={update=noop,draw=noop,show=noop}
RushBanner={show=noop,isActive=no,update=noop,draw=noop}
HelpCard={show=function() helpShows=helpShows+1 end,update=noop,
    isOpen=no,hasSeen=function() return true end,isVisible=no,handleInput=noop,draw=noop}
''')
lua.globals().playdate.argv = lua.table_from(['game.pdx', '--version=' + version])
# Refresh the registry with this launch's arguments.
lua.execute((ROOT / 'source/gameVersions.lua').read_text())
imports.clear()
lua.execute((ROOT / 'source/main.lua').read_text())
imports_allowed = False
lua.execute('''
assert(stationInitializations==0,"stations initialized before LOADING")
assert(TitleScreen.getState()=="boot")
now=200;playdate.update()
assert(TitleScreen.getState()=="boot" and imageCall("resource/loading/out-table-7"))
now=400;playdate.update()
assert(TitleScreen.getState()=="intro")
buttons={[1]=true,[2]=true,[3]=true}
now=1000;playdate.update();controls()
assert(Orders.time==0 and gameUpdates==0 and inputCalls==0 and helpShows==0)
now=100000;playdate.gameWillResume();playdate.update()
assert(TitleScreen.getState()=="intro","system menu elapsed time advanced intro")
buttons={};now=103001;playdate.update()
assert(TitleScreen.getState()=="menu")
now=162601;playdate.update()
assert(Orders.time==0 and gameUpdates==0 and inputCalls==0,"waiting menu advanced game")
buttons={[1]=true};now=162635;playdate.update()
assert(TitleScreen.getState()=="menu" and indicatorDraws>0,"A must not start, docked crank needs hint")
crankDocked=false;crankChange=180;now=162669;playdate.update()
assert(TitleScreen.getState()=="exit" and indicatorResets==1)
crankChange=180;now=164000;playdate.update()
assert(Orders.time==0 and gameUpdates==0 and inputCalls==0)
buttons={}
assert(TitleScreen.getState()=="loading")
assert(stationInitializations==0,"stations initialized before visible LOADING")
finishLoading()
assert(stationInitializations==2 and Orders.time==0 and inputCalls==0)
assert(TitleScreen.getState()=="enter")
for i=1,21 do now=now+34;playdate.update() end
assert(not TitleScreen.isActive() and Orders.time==0 and inputCalls==0)
now=now+34;playdate.update()
assert(math.abs(Orders.time-.034)<.0001 and inputCalls==1 and gameUpdates==2)
assert(drains>=7,"hidden crank input was not drained")
print("PASS: startup-only imports, initialization after LOADING, frozen clocks/input, crank drain and handoff")
''')

prefix = '' if version == 'original' else f'variants/{version}/'
assert prefix + 'grinderWorkstation' in imports and prefix + 'assemblyWorkstation' in imports, 'game modules never loaded'
assert all(name.startswith(prefix) for name in imports if Path(name).name in ('playerConfig', 'grinderWorkstation', 'assemblyWorkstation')), 'another version was imported'

# First-visit help was previously omitted by the hasSeen=true fixture above.
# Compare the final revealed scene with the very next live frame.
lua.execute('''
now,buttons,helpShows,crankChange,crankDocked=0,{},0,0,false
local visible=false
HelpCard.hasSeen=function() return helpShows>0 end
HelpCard.show=function() helpShows=helpShows+1;visible=true end
HelpCard.isOpen=function() return visible end
HelpCard.isVisible=HelpCard.isOpen
HelpCard.draw=function() recordHelp(visible) end
''')
imports_allowed = True
lua.execute('startupFlushes=0')
lua.execute((ROOT / 'source/main.lua').read_text())
imports_allowed = False
lua.execute('''
now=400;playdate.update()
now=4001;playdate.update()
crankChange=180;now=4035;playdate.update()
crankChange=180;now=5900;playdate.update()
finishLoading()
assert(TitleScreen.getState()=="enter")
-- A slow initialization above must not consume the entrance duration.
assert(imageCall("snapshot")[4]==-240)
for i=1,21 do now=now+34;playdate.update() end
assert(not TitleScreen.isActive())
local revealedHelp=screenHasHelp
now=now+34;playdate.update()
assert(revealedHelp==screenHasHelp,
    "SLIDE POP: final snapshot excludes first-visit help but live gameplay adds it")
print("PASS: first-visit slide and first live frame contain the same UI")
''')
print(f'Native Lua composition snapshots: {OUTPUT}')

# The picker consumes buttons and crank input without entering gameplay.
lua.execute('''
restartArgs=nil
playdate.restart=function(args) restartArgs=args end
buttons={};TitleScreen.initialize();step(6)
buttons={[playdate.kButtonB]=true};step(.1,360)
assert(TitleScreen.getState()=="versions" and not TitleScreen.shouldShowCrankIndicator())
local before=preparations
buttons={};step(60,720)
assert(TitleScreen.getState()=="versions" and preparations==before)
buttons={[playdate.kButtonA]=true};step(.1)
assert(TitleScreen.getState()=="menu" and restartArgs==nil,"same version should close picker")
buttons={[playdate.kButtonB]=true};step(.1)
buttons={[playdate.kButtonUp]=true};step(.1)
buttons={[playdate.kButtonDown]=true};step(.1)
buttons={[playdate.kButtonA]=true};step(.1)
assert(restartArgs==nil,"up/down must wrap back to current selection")
buttons={[playdate.kButtonB]=true};step(.1)
buttons={[playdate.kButtonDown]=true};step(.1)
buttons={[playdate.kButtonB]=true};step(.1)
assert(TitleScreen.getState()=="menu" and restartArgs==nil,"cancel changed version")
buttons={[playdate.kButtonB]=true};step(.1)
buttons={[playdate.kButtonDown]=true};step(.1)
buttons={[playdate.kButtonA]=true};step(.1)
local nextIndex=GameVersions.getIndex()%5+1
assert(restartArgs=="--version="..GameVersions.getEntries()[nextIndex].id.." --version-selected")
assert(GameVersions.savePath("progress")=="versions/"..GameVersions.getId().."/progress")
assert(not pcall(GameVersions.savePath,"../progress"))
buttons={}
''')
lua.globals().playdate.argv = lua.table_from(['game.pdx', '--version=variantD', '--version-selected'])
lua.execute((ROOT / 'source/gameVersions.lua').read_text())
lua.execute('''
TitleScreen.initialize(true);step(0)
assert(GameVersions.getId()=="variantD" and TitleScreen.getState()=="menu",
    "choosing a version must return directly to its title menu")
GameVersions.showPicker()
assert(restartArgs=="--version=variantD --choose-version")
''')
lua.globals().playdate.argv = lua.table_from(['game.pdx', '--version=variantB', '--choose-version'])
lua.execute((ROOT / 'source/gameVersions.lua').read_text())
lua.execute('''
TitleScreen.initialize(true);step(0)
assert(GameVersions.getId()=="variantB" and TitleScreen.getState()=="versions")
''')
lua.globals().playdate.argv = lua.table_from(['game.pdx', '--version=unknown'])
lua.execute((ROOT / 'source/gameVersions.lua').read_text())
lua.execute('assert(GameVersions.getId()=="original")')
print(f'PASS: {version} picker selection/cancel/wrap, frozen input, restart routing and save namespace')
