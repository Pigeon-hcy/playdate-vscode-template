-- Compile from repo root:
-- pdc -I source examples/juicy /tmp/juicy-demo.pdx
import "CoreLibs/graphics"
import "juicy"
local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(30)
local juice = Juicy.new()
local layers = 3
local closed, ready = false, false
local station, oldStation, switching = 3, nil, false
local last = pd.getCurrentTimeMilliseconds()
-- Images allocated once, never during update/draw.
local images = {}
for i=1,6 do
    local image = gfx.image.new(110,22,gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorWhite); gfx.fillRoundRect(0,0,110,22,5)
    gfx.setColor(gfx.kColorBlack); gfx.drawRoundRect(0,0,110,22,5)
    gfx.drawText(({"BREAD","PATTY","CHEESE","LETTUCE","TOMATO","BREAD"})[i],8,2)
    gfx.popContext()
    images[i]=image
end
local function add()
    if closed then
        if ready then juice:clear(); layers=3; closed=false; ready=false end
        return
    end
    layers=layers+1
    local direction=layers%2==0 and -1 or 1
    juice:ingredientLand(layers,{direction=direction})
    for i=1,layers-1 do
        juice:ingredientLand(i,{secondary=true,direction=direction,
            impactWeight=.2+.3*(i-1)/math.max(1,layers-2),delay=(layers-i)*.012})
    end
    juice:ingredientLand("burger",{group=true})
    if layers==6 then
        closed=true
        juice:burgerComplete("burger",{x=200,y=100,width=110,
            onComplete=function() ready=true end})
    end
end
local function drawStation(number,id)
    local stationT=juice:getTransform(id)
    if not stationT.visible then return end
    local dx=math.floor(stationT.offsetX+.5)
    if number~=3 then gfx.drawText(number==1 and "GRINDER" or "STOVE",160+dx,100); return end
    local group=juice:getTransform("burger")
    local err=juice:getTransform("error")
    local sx,sy=juice:getScreenOffset("burger")
    -- Bottom-centred stack anchor (200,190), then bottom-centred layers.
    -- drawScaled scales without allocating a new image. No sprite transform API.
    local mode=gfx.getImageDrawMode()
    for i=1,layers do
        local t=juice:getTransform(i)
        local w,h=images[i]:getSize()
        local scaleX=math.max(.90,math.min(1.12,t.scaleX*group.scaleX))
        local scaleY=math.max(.82,math.min(1.10,t.scaleY*group.scaleY))
        local bottom=190-(i-1)*17*group.scaleY+group.offsetY+t.offsetY+sy
        local center=200+dx+group.offsetX+t.offsetX+err.offsetX+sx
        gfx.setImageDrawMode((group.invert or err.invert) and gfx.kDrawModeInverted or mode)
        images[i]:drawScaled(math.floor(center-w*scaleX/2+.5),math.floor(bottom-h*scaleY+.5),scaleX,scaleY)
    end
    gfx.setImageDrawMode(mode)
end
function pd.update()
    local now=pd.getCurrentTimeMilliseconds()
    juice:update((now-last)/1000); last=now
    if not switching then
        local direction=pd.buttonJustPressed(pd.kButtonLeft) and -1 or (pd.buttonJustPressed(pd.kButtonRight) and 1 or 0)
        if direction~=0 then
            oldStation=station; station=((station-1+direction)%3)+1; switching=true
            juice:stationSwitch("old",direction,{outgoing=true})
            juice:stationSwitch("new",direction,{onComplete=function() switching=false; oldStation=nil end})
        elseif station==3 then
            if pd.buttonJustPressed(pd.kButtonA) then add() end
            if pd.buttonJustPressed(pd.kButtonB) then juice:errorShake("error") end
        end
    end
    gfx.clear()
    if oldStation then drawStation(oldStation,"old") end
    drawStation(station,"new")
    if station==3 and not switching then juice:drawParticles() end
    gfx.drawText("LEFT/RIGHT: STATION",8,8)
    gfx.drawText(ready and "A: SERVE / RESET" or "A: ADD   B: ERROR",8,215)
end
