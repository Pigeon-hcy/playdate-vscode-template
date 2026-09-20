#!/usr/bin/env python3
"""Run real scoring and order callbacks through combo thresholds and failures."""
from pathlib import Path
import re
from lupa.lua54 import LuaRuntime

SOURCE = Path(__file__).resolve().parents[2] / 'source'

for version in ['original', 'variantA', 'variantB', 'variantC', 'variantD']:
    prefix = '' if version == 'original' else f'variants/{version}/'
    lua = LuaRuntime()
    loaded = set()

    def load(name):
        if name in loaded:
            return
        loaded.add(name)
        code = (SOURCE / (name + '.lua')).read_text()
        code = re.sub(r'([\w.]+) ([+*])= (.*?)(?= end|$)',
                      r'\1 = \1 \2 \3', code, flags=re.M)
        lua.execute(code)

    lua.globals()['import'] = load
    load(prefix + 'orderRuntime')
    if version != 'variantA':
        lua.execute('''
            assert(PlayerConfig.combo==nil and Scoring.comboMultiplier==nil)
            for i=1,20 do assert(Scoring.awardBurger({"P","A"},45,false)==970) end
            assert(PlayerConfig.score==19400)
        ''')
        print(f'PASS: {version} scoring unchanged')
        continue

    lua.execute('''
        local layers={"P","A"}
        assert(PlayerConfig.combo==0 and Scoring.comboMultiplier()==1)
        local notified=0
        Scoring.onChange=function(delta) notified=delta end
        local expectedTotal=0
        for count=1,21 do
            local multiplier=1+math.floor(count/5)*.1
            local expected=math.floor(970*multiplier+.5)
            assert(Scoring.awardBurger(layers,45,false)==expected, "wrong threshold order "..count)
            expectedTotal=expectedTotal+expected
            assert(PlayerConfig.score==expectedTotal and notified==expected)
            assert(PlayerConfig.combo==count and Scoring.comboMultiplier()==multiplier)
        end
        -- Reading a score preview must not award another combo or score.
        assert(Scoring.burgerPoints(layers,45,false)==970 and PlayerConfig.combo==21)
        local score=PlayerConfig.score
        assert(Scoring.penalizeWrong()==500)
        assert(PlayerConfig.score==score-500 and PlayerConfig.combo==0 and notified==-500)
        assert(Scoring.awardBurger(layers,45,false)==970 and PlayerConfig.combo==1)
        PlayerConfig.score=0
        Scoring.penalizeMissed(false)
        assert(PlayerConfig.score==0 and PlayerConfig.combo==0 and Scoring.comboMultiplier()==1)
        assert(notified==-800, "zero-score failure must still break combo and notify")

        -- Rush and combo stack on the full raw score, then round once.
        PlayerConfig.combo=4
        assert(Scoring.awardBurger({"P"},1,true)==611) -- 370 * 1.5 * 1.1 = 610.5
        assert(PlayerConfig.combo==5)
        assert(Scoring.penalizeMissed(true)==200 and PlayerConfig.combo==0 and notified==-200)

        -- A background ticket expiring breaks combo even when another is locked.
        Orders:reset()
        local promised=Orders:commitNext()
        local waiting=Orders:addOrder(Orders.time)
        waiting.expiresAt=1
        PlayerConfig.combo=9
        Orders:update(1)
        assert(Orders.expired==1 and Orders:isCommitted(promised))
        assert(PlayerConfig.combo==0 and Scoring.comboMultiplier()==1)
        assert(Scoring.awardBurger(layers,45,false)==970 and PlayerConfig.combo==1)

        -- Rush transitions themselves do not count as a failure.
        Orders:reset()
        Orders:commitNext()
        PlayerConfig.combo=10
        Orders:startRush()
        assert(PlayerConfig.combo==10)
        Orders:endRush()
        assert(PlayerConfig.combo==10)
        -- Several expirations in the same frame leave one reset streak.
        Orders:reset()
        Orders:addOrder(0)
        for _,order in ipairs(Orders.pending) do order.expiresAt=1 end
        Orders:update(1)
        assert(Orders.expired==2 and PlayerConfig.combo==0)
    ''')
    print('PASS: A thresholds, rounding, rush stacking, failure at zero score, real expiry callbacks and recovery')
