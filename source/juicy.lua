--[[
Juicy: Playdate 400x240 / 30 Hz, dt and all durations are SECONDS.
import "juicy"
local juice = Juicy.new({ reducedMotion = false, particleCapacity = 24 })
juice:ingredientLand("tomato", { direction = -1 })
-- Heavy ingredients: juice:verticalShake("patty", .45) layers onto ingredientLand.
-- Use the same id for both effects and draw with getTransform / drawImage.
-- Every update: juice:update(dt); then read transforms (borrowed, DO NOT mutate).
-- Draw bottom-centred: x = baseX + t.offsetX - width*t.scaleX/2;
-- y = baseBottom + t.offsetY - height*t.scaleY. Never change model coordinates.
-- Existing layers: ingredientLand(id, {secondary=true, impactWeight=.5,
--   delay=.012}); bottom layer weight .2. delay propagates downward.
-- Whole burger: ingredientLand("group", {group=true}) (vertical only).
-- stationSwitch("old", 1, {outgoing=true}); stationSwitch("new", 1).
-- Draw both stations; owner manages input lock and outgoing lifetime.
-- x/y options are particle emission coordinates, not object positions.
-- Optional onImpact(id), onComplete(id), onErrorImpact(id) are notifications.
-- Same id retriggers/replaces its envelope, retaining bounded residual motion;
-- use different ids for layer, group and UI. remove ids when objects are retired.
-- Terminal hide (extinguish success / button done / outgoing station) retains
-- visible=false, but numeric transforms return EXACTLY to identity. remove resets.
-- Screen channels are opt-in local offsets; never applied to display or UI here.
-- No timers, sprite mutation, sounds, gameplay, or per-frame table allocation.
]]
import "CoreLibs/graphics"
local gfx = playdate.graphics
Juicy = {}
Juicy.__index = Juicy

-- All tuning lives here; time units seconds, velocity pixels/second.
Juicy.config = {
    land=.120, complete=.260, error=.160, station=.180, fire=.160,
    extinguish=.120, shrink=.160, button=.100, flash=.045, flashCooldown=.180,
    maxX=5, maxY=3, minSX=.90, maxSX=1.12, minSY=.82, maxSY=1.10,
    propagation=.012, capacity=24, screenStrength=2, screenDuration=.090,
    stationWidth=400, stationOvershoot=3, carry=.30, maxGain=1.4,
    particleLife=.28, particleGravity=160, particleSpeed=38,
    landX={-4,3,-2,1,0}, errorX={-3,3,-2,2,-1,0},
    errorTimes={0,.13,.35,.50,.76,1},
    squashX=1.08, squashY=.88, reboundX=.97, reboundY=1.05,
    completeX=1.10, completeY=.84, completeRebound=1.06,
    buttonIn=.88, buttonOut=1.08,
    heavyShakeDuration=.45, heavyShakeAmplitude=2.5,
    heavyShakeStartHz=12, heavyShakeEndHz=4, heavyShakeMaxHz=14,

}
local C = Juicy.config
local EMPTY = {}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function mix(a,b,t) return a+(b-a)*t end
local function round(v) return math.floor(v+.5) end
Juicy.easing = {
    linear=function(t) return t end,
    easeOutQuad=function(t) return 1-(1-t)^2 end,
    easeOutCubic=function(t) return 1-(1-t)^3 end,
    easeOutBack=function(t) local u=t-1; return 1+2.70158*u^3+1.70158*u^2 end,
    easeInOutQuad=function(t) if t<.5 then return 2*t*t end return 1-(-2*t+2)^2/2 end,
}
local E = Juicy.easing
local function identity(t)
    t.offsetX,t.offsetY,t.scaleX,t.scaleY,t.rotation=0,0,1,1,0
    t.visible,t.invert=true,false
end
local function transform() local t={}; identity(t); return t end
local function path(points,t,times)
    t=clamp(t,0,1)
    for i=1,#points-1 do
        local a=times and times[i] or (i-1)/(#points-1)
        local b=times and times[i+1] or i/(#points-1)
        if t<=b then return mix(points[i],points[i+1],(t-a)/(b-a)) end
    end
    return points[#points]
end

-- Create independent instance; example: local j=Juicy.new({reducedMotion=true}).
function Juicy.new(options)
    local o=options or EMPTY
    local self=setmetatable({effects={},channels={},particles={},time=0,serial=0,
        reducedMotion=o.reducedMotion==true,neutral=transform()},Juicy)
    for i=1,math.max(1,math.floor(o.particleCapacity or C.capacity)) do
        self.particles[i]={active=false,serial=0}
    end
    return self
end
-- Borrow stable read-only state; unknown ids return identity: j:getTransform("bun").
function Juicy:getTransform(id) local e=self.effects[id]; return e and e.t or self.neutral end
-- Retire an id and its owned particles; example: j:remove("bun"). No callbacks.
function Juicy:remove(id)
    local e=self.effects[id]; if e then identity(e.t) end
    self.effects[id]=nil
    for _,p in ipairs(self.particles) do if p.owner==id then p.active=false end end
end
-- Reset all visuals without callbacks; example: j:clear() on level exit.
function Juicy:clear()
    for id in pairs(self.effects) do self:remove(id) end
    for _,s in pairs(self.channels) do s.elapsed=s.duration; s.x,s.y=0,0 end
    for _,p in ipairs(self.particles) do p.active=false end
end
local function start(self,id,kind,o,duration)
    assert(id~=nil,"Juicy requires an id")
    o=o or EMPTY
    local e=self.effects[id]
    if not e then e={t=transform(),lastFlash=-math.huge}; self.effects[id]=e end
    local t=e.t
    local remaining=e.active and clamp(1-e.elapsed/e.duration,0,1) or 0
    e.carryX=clamp(t.offsetX+(e.vx or 0)*.008,-C.maxX,C.maxX)*C.carry
    e.carryY=clamp(t.offsetY,-C.maxY,C.maxY)*C.carry
    e.gain=math.min(C.maxGain,1+remaining*C.carry)
    e.kind,e.elapsed,e.duration,e.active=kind,-math.max(0,o.delay or 0),math.max(.001,o.duration or duration),true
    e.direction=o.direction==1 and 1 or -1
    e.weight=clamp(o.impactWeight or 1,0,1)
    e.secondary,e.group=o.secondary==true,o.group==true
    e.outgoing,e.loop,e.hide=o.outgoing==true,o.loop==true,o.success==true or o.done==true
    e.x,e.y,e.width=o.x or 200,o.y or 120,o.width or 100
    e.channel=o.channel or id
    e.onImpact,e.onComplete=o.onImpact or o.onErrorImpact,o.onComplete
    e.impacted=false
    e.flash=self.time-e.lastFlash>=C.flashCooldown
    if e.flash then e.lastFlash=self.time end
    identity(t)
    e.vibrationOffset=0
    return e
end
local function burst(self,id,e,kind,count)
    for i=1,count do
        local p=self.particles[1]
        for _,candidate in ipairs(self.particles) do
            if not candidate.active then p=candidate; break end
            if candidate.serial<p.serial then p=candidate end
        end
        self.serial=self.serial+1
        local side=i%2==0 and 1 or -1
        p.active,p.owner,p.serial=true,id,self.serial
        p.x=e.x+side*e.width*.45; p.y=e.y
        p.vx=side*(C.particleSpeed+i*3); p.vy=-C.particleSpeed-i*7
        p.gravity=kind=="crumb" and C.particleGravity or -12
        p.elapsed,p.life=0,C.particleLife+i*.012
        p.kind,p.white=kind,kind=="steam"
    end
end
-- Immediate directional cut-in; j:ingredientLand(3,{direction=1,impactWeight=1}).
function Juicy:ingredientLand(id,options)
    local e=start(self,id,"land",options,C.land)
    if not e.secondary and not e.group and e.elapsed==0 then
        e.t.offsetX=e.direction*C.maxX*(self.reducedMotion and .5 or 1)
    end
    return e.t
end
-- Vertical vibration for heavy ingredients; duration is seconds (0 cancels).
-- j:ingredientLand("patty"); j:verticalShake("patty", .45)
-- Optional: {amplitude=2.5, startHz=12, endHz=4}. Frequency falls linearly;
-- phase is its time integral, so variable dt does not change the trajectory.
-- Defaults stay below 15 Hz (Nyquist at 30 FPS). Final summed Y is capped at 3px.
-- Retrigger preserves phase and adds bounded amplitude; other effects continue.
-- Reduced motion halves amplitude. No sprite/model mutation: render using the
-- same id's getTransform() or drawImage(). remove()/clear() also cancel this.
function Juicy:verticalShake(id, duration, options)
    assert(id~=nil, "Juicy requires an id")
    duration=duration or C.heavyShakeDuration
    assert(type(duration)=="number" and duration>=0 and duration<math.huge,
        "duration must be finite nonnegative seconds")
    local o=options or EMPTY
    local e=self.effects[id]
    if not e then e={t=transform(),lastFlash=-math.huge}; self.effects[id]=e end
    local v=e.vibration
    if duration==0 then
        e.t.offsetY=e.t.offsetY-(e.vibrationOffset or 0)
        e.vibrationOffset=0
        if v then v.active=false end
        return e.t
    end
    local residual=0
    local phase=0
    if v and v.active then
        residual=v.amplitude*(1-v.elapsed/v.duration)
        phase=v.phase
    elseif not v then
        v={}; e.vibration=v
    end
    v.active,v.elapsed,v.duration=true,0,duration
    v.amplitude=clamp((o.amplitude or C.heavyShakeAmplitude)+residual*C.carry,0,C.maxY)
    v.startHz=clamp(o.startHz or C.heavyShakeStartHz,0,C.heavyShakeMaxHz)
    v.endHz=clamp(o.endHz or C.heavyShakeEndHz,0,v.startHz)
    v.initialPhase,v.phase=phase,phase
    return e.t
end

-- Whole-stack completion; animate top bun separately with ingredientLand.
-- j:burgerComplete("burger",{x=200,y=90,onComplete=function() serve() end}).
function Juicy:burgerComplete(id,options) return start(self,id,"complete",options,C.complete).t end
-- Deterministic error, no squash; j:errorShake("burger",{onErrorImpact=beep}).
function Juicy:errorShake(id,options) return start(self,id,"error",options,C.error).t end
-- -1=left, +1=right; j:stationSwitch("old",-1,{outgoing=true}).
function Juicy:stationSwitch(id,direction,options)
    local e=start(self,id,"station",options,C.station)
    e.direction=direction<0 and -1 or 1
    e.t.offsetX=e.outgoing and 0 or -e.direction*C.stationWidth*(self.reducedMotion and .5 or 1)
    return e.t
end
-- Bounded looping flame/particles; j:fireBurst("fire",{loop=true,x=200,y=100}).
function Juicy:fireBurst(id,options) return start(self,id,"fire",options,C.fire).t end
-- Retrigger on B; final hit: j:extinguish("fire",{success=true}).
-- Successful shrink deliberately bypasses minimum scale; identity+hidden at end.
function Juicy:extinguish(id,options)
    return start(self,id,"extinguish",options,options and options.success and C.shrink or C.extinguish).t
end
-- UI only; j:buttonPunch("A",{done=true}) hides after punch.
-- .88 UI minimum is an intentional exception to ingredient scale bounds.
function Juicy:buttonPunch(id,options) return start(self,id,"button",options,C.button).t end
-- Optional local channel; j:addScreenShake("burger",2,.09); never moves display.
function Juicy:addScreenShake(channel,strength,duration)
    local s=self.channels[channel]
    if not s then s={x=0,y=0,elapsed=0,duration=0,strength=0}; self.channels[channel]=s end
    if self.reducedMotion then s.x,s.y=0,0; return end
    s.strength=clamp(math.max(s.strength or 0,strength or C.screenStrength),0,C.screenStrength)
    s.duration=clamp(duration or C.screenDuration,.001,.100); s.elapsed=0
end
-- Two numeric return values; local dx,dy=j:getScreenOffset("burger").
function Juicy:getScreenOffset(channel)
    local s=self.channels[channel]; if self.reducedMotion or not s then return 0,0 end
    return s.x,s.y
end
local function evaluate(self,e,u)
    local t=e.t
    identity(t)
    local x,y,sx,sy=0,0,1,1
    if e.kind=="land" or e.kind=="complete" then
        local complete=e.kind=="complete"
        local contact=complete and .12 or .20
        if u<contact and not e.secondary and not e.group then
            x=e.direction*mix(C.maxX,0,E.easeOutCubic(u/contact))
        else
            local p=clamp((u-contact)/(1-contact),0,1)
            x=e.direction*path(C.landX,p)
            y=2*(1-E.easeOutQuad(p))
            local a=complete and C.completeX or C.squashX
            local b=complete and C.completeY or C.squashY
            local rebound=complete and C.completeRebound or C.reboundY
            if p<.48 then
                local r=E.easeOutBack(p/.48)
                sx,sy=mix(a,C.reboundX,r),mix(b,rebound,r)
            else
                local r=E.easeOutCubic((p-.48)/.52)
                sx,sy=mix(C.reboundX,1,r),mix(rebound,1,r)
            end
        end
        if e.group then x,sx,sy=0,1,1 end
        t.invert=complete and u>=contact and u<contact+C.flash/e.duration and e.flash
    elseif e.kind=="error" then
        x=path(C.errorX,u,C.errorTimes)
        t.invert=u<C.flash/e.duration and e.flash
    elseif e.kind=="station" then
        if e.outgoing then x=e.direction*C.stationWidth*E.easeOutCubic(u)
        elseif u<.78 then x=mix(-e.direction*C.stationWidth,e.direction*C.stationOvershoot,E.easeOutCubic(u/.78))
        else x=e.direction*C.stationOvershoot*(1-E.easeOutQuad((u-.78)/.22)) end
    elseif e.kind=="fire" then
        local pulse=math.sin(math.pi*u)
        sx,sy=1+.10*pulse,1+.10*pulse
        x=2*math.sin(u*math.pi*4)*(1-u)
    elseif e.kind=="extinguish" then
        x=2*math.sin(u*math.pi*6)*(1-u)
        if e.hide then sx,sy=1-E.easeOutCubic(u),1-E.easeOutCubic(u)
        else sx,sy=1+.10*math.sin(math.pi*u),1-.18*math.sin(math.pi*u) end
    elseif e.kind=="button" then
        if u<.25 then sx=mix(1,C.buttonIn,E.easeOutCubic(u/.25))
        elseif u<.6 then sx=mix(C.buttonIn,C.buttonOut,E.easeOutBack((u-.25)/.35))
        else sx=mix(C.buttonOut,1,E.easeOutCubic((u-.6)/.4)) end
        sy=sx
    end
    local motion=self.reducedMotion and .5 or 1
    local weight=e.weight*e.gain
    if e.kind=="station" then t.offsetX=x*motion
    else t.offsetX=clamp((x*weight+e.carryX*(1-u)^2)*motion,-C.maxX,C.maxX) end
    t.offsetY=clamp((y*weight+e.carryY*(1-u)^2)*motion,-C.maxY,C.maxY)
    local minScale=e.kind=="button" and C.buttonIn or C.minSX
    t.scaleX=clamp(1+(sx-1)*weight*motion,minScale,C.maxSX)
    t.scaleY=clamp(1+(sy-1)*weight*motion,C.minSY,C.maxSY)
    if e.kind=="extinguish" and e.hide then
        t.scaleX,t.scaleY=sx,sy -- terminal disappearance is semantic, also in reduced motion
    end
    t.invert=t.invert and not self.reducedMotion
end
-- Seconds, nonnegative finite; j:update((now-last)/1000). No dt truncation.
function Juicy:update(dt)
    assert(type(dt)=="number" and dt>=0 and dt<math.huge,"dt must be finite seconds")
    self.time=self.time+dt
    -- Remove only the previously applied additive displacement, including clipping.
    -- This also works after the primary envelope has ended (no cumulative drift).
    for _,e in pairs(self.effects) do
        if e.vibrationOffset and e.vibrationOffset~=0 then
            e.t.offsetY=e.t.offsetY-e.vibrationOffset
            e.vibrationOffset=0
        end
    end
    for _,p in ipairs(self.particles) do
        if p.active then
            local step=math.min(dt,p.life-p.elapsed)
            p.x=p.x+p.vx*step; p.y=p.y+p.vy*step+.5*p.gravity*step*step
            p.vy=p.vy+p.gravity*step; p.elapsed=p.elapsed+dt
            if p.elapsed>=p.life then p.active=false end
        end
    end
    for _,s in pairs(self.channels) do
        s.elapsed=s.elapsed+dt
        local u=clamp(s.elapsed/s.duration,0,1)
        if u>=1 or self.reducedMotion then s.x,s.y,s.strength=0,0,0
        else s.x=round(path(C.errorX,u)/3*s.strength*(1-u)); s.y=0 end
    end
    for id,e in pairs(self.effects) do
        if e.active then
            e.elapsed=e.elapsed+dt
            if e.elapsed>=0 then
                local u=clamp(e.elapsed/e.duration,0,1)
                local previous=e.t.offsetX
                evaluate(self,e,u)
                e.vx=dt>0 and (e.t.offsetX-previous)/dt or 0
                local impactAt=(e.kind=="land" or e.kind=="complete") and e.duration*(e.kind=="land" and .20 or .12) or 0
                local impactCallback
                if not e.impacted and e.elapsed>=impactAt then
                    e.impacted=true; impactCallback=e.onImpact
                    if e.kind=="complete" then
                        burst(self,id,e,"crumb",4); self:addScreenShake(e.channel,C.screenStrength,C.screenDuration)
                    elseif e.kind=="fire" then burst(self,id,e,"fire",3)
                    elseif e.kind=="extinguish" then burst(self,id,e,"steam",3) end
                end
                local completedCallback
                if u>=1 then
                    identity(e.t)
                    e.t.visible=not (e.hide or (e.kind=="station" and e.outgoing))
                    if e.loop and e.kind=="fire" then e.elapsed=e.elapsed%e.duration; e.impacted=false
                    else e.active=false; e.vx=0; completedCallback=e.onComplete; e.onComplete=nil; e.onImpact=nil end
                end
                -- State finalized before callbacks: retrigger/remove/clear are safe.
                if impactCallback then impactCallback(id) end
                if completedCallback then completedCallback(id) end
            end
        end
    end
    -- Separate pass: primary completion must not erase a longer heavy vibration.
    for _,e in pairs(self.effects) do
        local v=e.vibration
        if v and v.active then
            v.elapsed=math.min(v.duration,v.elapsed+dt)
            if v.elapsed>=v.duration then
                v.active=false
            else
                local u=v.elapsed/v.duration
                v.phase=v.initialPhase+2*math.pi*(v.startHz*v.elapsed+
                    .5*(v.endHz-v.startHz)*v.elapsed*u)
                local offset=math.sin(v.phase)*v.amplitude*(1-u)*
                    (self.reducedMotion and .5 or 1)
                local base=e.t.offsetY
                e.t.offsetY=clamp(base+offset,-C.maxY,C.maxY)
                e.vibrationOffset=e.t.offsetY-base
            end
        end
    end
end
-- Draw integer-pixel pool, optionally scoped to owner; j:drawParticles("burger").
function Juicy:drawParticles(owner)
    local color,line=gfx.getColor(),gfx.getLineWidth()
    gfx.setLineWidth(1)
    for _,p in ipairs(self.particles) do
        if p.active and (owner==nil or owner==p.owner) and
            (p.elapsed<p.life*.7 or math.floor(p.elapsed*60)%2==0) then
            local x,y=round(p.x),round(p.y)
            gfx.setColor(p.white and gfx.kColorWhite or gfx.kColorBlack)
            if p.kind=="crumb" then gfx.drawLine(x,y,x+2,y-1)
            elseif p.kind=="steam" then
                gfx.fillRect(x,y,3,3); gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(x,y,1,1); gfx.fillRect(x+2,y+2,1,1)
            else gfx.fillRect(x,y,2,2) end
        end
    end
    gfx.setColor(color); gfx.setLineWidth(line)
end
-- Bottom-centred image rendering; j:drawImage(image,"bun",200,180).
-- SDK drawRotated is centre-anchored, so rotate the bottom-to-centre vector.
-- Nonuniform scale supported by drawScaled/drawRotated; no temporary Lua images.
function Juicy:drawImage(image,id,x,bottom)
    local t=self:getTransform(id)
    if not t.visible or t.scaleX<=0 or t.scaleY<=0 then return end
    local w,h=image:getSize()
    local mode=gfx.getImageDrawMode()
    if t.invert then gfx.setImageDrawMode(gfx.kDrawModeInverted) end
    if t.rotation==0 then
        image:drawScaled(round(x+t.offsetX-w*t.scaleX/2),round(bottom+t.offsetY-h*t.scaleY),t.scaleX,t.scaleY)
    else
        local a=math.rad(t.rotation); local half=h*t.scaleY/2
        image:drawRotated(round(x+t.offsetX+math.sin(a)*half),round(bottom+t.offsetY-math.cos(a)*half),t.rotation,t.scaleX,t.scaleY)
    end
    gfx.setImageDrawMode(mode)
end
return Juicy
