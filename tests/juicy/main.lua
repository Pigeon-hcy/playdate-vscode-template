-- pdc -I source tests/juicy /tmp/juicy-tests.pdx; open in Playdate Simulator.
import "juicy"
local function near(a,b) assert(math.abs(a-b)<1e-4,tostring(a).." ~= "..tostring(b)) end
local j=Juicy.new()
j:verticalShake("p",.45)
j:update(.1)
local expected=math.sin(2*math.pi*(12*.1+.5*(4-12)*.1*.1/.45))*2.5*(1-.1/.45)
near(j:getTransform("p").offsetY,expected)
local split=Juicy.new()
split:verticalShake("p",.45)
for i=1,10 do split:update(.01) end
near(split:getTransform("p").offsetY,expected)
local reduced=Juicy.new({reducedMotion=true})
reduced:verticalShake("p",.45); reduced:update(.1)
near(reduced:getTransform("p").offsetY,expected*.5)
j:verticalShake("p",.45)
local phase=j.effects.p.vibration.phase
j:update(0)
near(j.effects.p.vibration.phase,phase)
for i=1,30 do
    j:ingredientLand("p")
    j:verticalShake("p",.45)
    j:update(1/30)
    assert(math.abs(j:getTransform("p").offsetY)<=3)
end
j:update(.15)
assert(j.effects.p.vibration.active, "vibration survives landing completion")
j:update(1)
local t=j:getTransform("p")
assert(t.offsetY==0 and t.offsetX==0 and t.scaleX==1 and t.scaleY==1)
j:verticalShake("p",1); j:update(.1); j:verticalShake("p",0)
assert(j:getTransform("p").offsetY==0)
j:verticalShake("p",1); j:update(.1); j:remove("p")
assert(j:getTransform("p").offsetY==0)
j:verticalShake("p",1); j:update(.1); j:clear()
assert(j:getTransform("p").offsetY==0)
assert(not pcall(function() j:verticalShake("p",-1) end))
print("JUICY VERTICAL SHAKE TESTS PASSED")
function playdate.update()
    playdate.graphics.clear()
    playdate.graphics.drawText("Vertical shake tests passed",20,100)
end
