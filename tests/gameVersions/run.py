#!/usr/bin/env python3
"""Check independent gameplay dependencies and run each version's core state."""
from pathlib import Path
import re
from lupa.lua54 import LuaRuntime

SOURCE = Path(__file__).resolve().parents[2] / 'source'
SHARED = {'gameVersions', 'titleScreen', 'titleAssets', 'loadingAssets'}
states = []
for version in ['original', 'variantA', 'variantB', 'variantC', 'variantD']:
    prefix = '' if version == 'original' else f'variants/{version}/'
    folder = SOURCE / prefix
    assembly_source = (folder / 'assemblyWorkstation.lua').read_text()
    if version == 'variantC':
        assert 'ingredientCardWheel' not in assembly_source
        assert 'selectedIngredientIndex' not in assembly_source
        assert 'FOLLOW THE QTE' in assembly_source
        assert 'acceptQteToken' in assembly_source
    else:
        assert 'kButtonA' not in assembly_source, f'{version}: A still places assembly items'
        assert '{ "⬇", "ADD THE PICKED ITEM" }' in assembly_source
        assert '🎣 PICK   ⬇ ADD   ⬆ BUN' in assembly_source
    if prefix:
        for path in folder.glob('*.lua'):
            for dependency in re.findall(r'^import "([^"]+)"', path.read_text(), re.M):
                assert (dependency.startswith('CoreLibs/') or dependency in SHARED
                        or dependency.startswith(prefix)), (path, dependency)
                if not dependency.startswith('CoreLibs/'):
                    assert (SOURCE / (dependency + '.lua')).exists(), dependency

    lua = LuaRuntime(unpack_returned_tuples=True)
    loaded = set()

    def load(name):
        if name in loaded:
            return
        loaded.add(name)
        assert name.startswith(prefix) and (prefix or not name.startswith('variants/'))
        code = (SOURCE / (name + '.lua')).read_text()
        # These core modules use simple += and *=, including a one-line if.
        code = re.sub(r'([\w.]+) ([+*])= (.*?)(?= end|$)',
                      r'\1 = \1 \2 \3', code, flags=re.M)
        lua.execute(code)

    lua.globals()['import'] = load
    load(prefix + 'orderRuntime')
    lua.execute('''
        assert(PlayerConfig.score==0 and PlayerConfig.mincedMeat==0 and PlayerConfig.patties==0)
        assert(PlayerConfig.workstationCount==3 and Orders:count()==1)
        local score=Scoring.awardBurger({"P","L"},10,false)
        assert(score>0 and PlayerConfig.score==score)
        Orders:startRush()
        assert(Orders:isRushHour())
        Orders:update(2)
        assert(Orders:count()>=2)
        PlayerConfig.mincedMeat=99
        PlayerConfig.grinder.outputParticles[1]={x=42}
    ''')
    if version == 'variantB':
        lua.execute('''
            local allowed={P=true,A=true,T=true,L=true,K=true}
            assert(#PlayerConfig.assembly.ingredientCodes==5)
            for _,code in ipairs(PlayerConfig.assembly.ingredientCodes) do
                assert(allowed[code], "unexpected simplified ingredient: "..code)
            end
            assert(#PlayerConfig.recipe==9)
            for _,recipe in ipairs(PlayerConfig.recipe) do
                local ingredientCount=#recipe-1
                assert(ingredientCount>=2 and ingredientCount<=5)
                for index=2,#recipe do assert(allowed[recipe[index]]) end
            end
            assert(PlayerConfig.grinder.stovePromptThreshold==300)
        ''')
    if version == 'variantC':
        lua.execute('''
            local qte=PlayerConfig.assembly.qte
            assert(qte.comboWindow==0.65 and qte.crankDegrees==60)
            assert(qte.ingredients.P.tokens[1]=="CRANK")
            assert(qte.ingredients.L.tokens[1]=="A")
            assert(qte.topBun.tokens[1]=="UP" and qte.topBun.tokens[2]=="A")
            assert(qte.serve.tokens[1]=="UP" and qte.serve.tokens[2]=="B")
        ''')
    if version == 'variantD':
        lua.execute('''
            local frying=PlayerConfig.frying
            assert(frying.slotCount==1)
            assert(frying.readyMin==60 and frying.burnAbove==80)
            assert(frying.degreesForFullBar==360)
        ''')
    states.append(lua)
    print(f'PASS: {version} independent imports, initial state, scoring and rush orders')

# Mutating one running instance cannot alter another's nested config/state.
states[1].execute('PlayerConfig.grinder.outputParticles[1].x=999; PlayerConfig.orders.lifetime=1')
for index, state in enumerate(states):
    if index != 1:
        state.execute('assert(PlayerConfig.grinder.outputParticles[1].x==42 and PlayerConfig.orders.lifetime==60)')
print('PASS: per-version nested state remains independent')
