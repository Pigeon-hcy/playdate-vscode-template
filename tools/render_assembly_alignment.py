"""Offline visual review using source sprites and assembly config; requires Pillow."""
from PIL import Image, ImageDraw
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
code_to_name=dict(P='Patty',O='Onion',T='Tomato',L='Lettuce',K='Pickle',E='Egg',M='Mushroom',B='Bacon',A='American',S='English')
images={c:Image.open(root/'source/resource/ingredients'/f'{n}.png').convert('RGBA') for c,n in code_to_name.items()}
bun=Image.open(root/'source/resource/ingredients/Bread1.png').convert('RGBA')
top=Image.open(root/'source/resource/ingredients/TopBread.png').convert('RGBA')
seats=dict(P=0,O=0,T=2,L=6,K=3,E=1,M=1,B=3,A=4,S=3)
thickness=dict(P=12,O=5,T=7,L=10,K=5,E=7,M=10,B=6,A=5,S=5)
cfg=(root/'source/playerConfig.lua').read_text()
def values(key):
 block=re.search(r'\b'+key+r'\s*=\s*\{([^}]+)\}',cfg).group(1)
 return {k:float(v) for k,v in re.findall(r'(\w+)\s*=\s*([\d.]+)',block)}
newseats=values('spriteBaselines');newthickness=values('spriteThickness');maxheight=values('spriteMaxHeights')
newbread=values('breadThickness')['bottom'];maxwidth=int(re.search(r'spriteFootprintWidth\s*=\s*(\d+)',cfg).group(1))
natural_overhangs=set(re.findall(r"(\w+)\s*=\s*true",re.search(r"spriteNaturalOverhang\s*=\s*\{([^}]+)\}",cfg).group(1)))
normalized={}
for c,im in images.items():
 b=im.getchannel('A').getbbox();natural=c in natural_overhangs;sx=1 if natural else min(1,maxwidth/(b[2]-b[0]));sy=1 if natural else min(sx,maxheight[c]/im.height)
 sprite=im.resize((int(im.width*sx+.5),int(im.height*sy+.5)),Image.Resampling.NEAREST)
 normalized[c]=sprite.crop(sprite.getchannel('A').getbbox())
 assert c in natural_overhangs or normalized[c].width<=maxwidth+1
 assert normalized[c].getchannel('A').getextrema()==(0,255)
newbun=bun.crop(bun.getchannel('A').getbbox());newtop=top.crop(top.getchannel('A').getbbox())
recipes=[]
for row in re.findall(r'\{([^{}]+)\}',re.sub(r'--[^\n]*','',(root/'source/recipes.lua').read_text())):
 vals=re.findall(r'"([^"]+)"',row)
 if vals:recipes.append((vals[0],vals[1:]))
def drawstack(layers,recipe,closed,after):
 im=Image.new('RGBA',(180,180),'white');bottom=171;center=90
 heights=[s.height for s in (list(normalized.values())+[newbun,newtop])] if after else [69]
 required=sum((newthickness if after else thickness)[c] for c in recipe)
 scale=min(1,(160-max(heights)-newbread)/required) if after and required else 1
 if not after:scale=min(1,(160-69)/(13+required))
 def draw(sprite,seat=0,rotation=0):
  x=int(center-sprite.width/2+.5);y=int(bottom-sprite.height+seat+.5)
  if rotation:
   rotated=sprite.rotate(-rotation,Image.Resampling.NEAREST,expand=True)
   x+=int((sprite.width-rotated.width)/2);y+=int((sprite.height-rotated.height)/2);sprite=rotated
  im.alpha_composite(sprite,(x,y))
 draw(newbun if after else bun)
 bottom-=newbread if after else 13*scale
 seen={}
 for c in layers:
  repeat=seen.get(c,0);seen[c]=repeat+1
  sprite=normalized[c] if after else images[c]
  if repeat%2:sprite=sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  rotation=0 if after or repeat%4<2 else (5 if repeat%4==2 else -5)
  draw(sprite,(newseats if after else seats)[c],rotation)
  bottom-=(newthickness if after else thickness)[c]*scale
 if closed:draw(newtop if after else top)
 return im
out=root/'art/assembly-alignment';out.mkdir(parents=True,exist_ok=True)
# Every recipe, plus all construction prefixes and reversed order, can use the
# same fixed support plane. No ingredient needs the recipe-specific baseline.
checked=0
for name,layers in recipes:
 for ordering in [layers,list(reversed(layers))]:
  for count in range(len(ordering)+1):
   drawstack(ordering[:count],layers,False,True);checked+=1
for after in [False,True]:
 sheet=Image.new('RGB',(180*6,205*3),'#ededed');d=ImageDraw.Draw(sheet)
 for i,(name,layers) in enumerate(recipes):
  x=i%6*180;y=i//6*205
  sheet.paste(drawstack(layers,layers,True,after),(x,y+25));d.text((x+6,y+6),name,fill='black')
 sheet.save(out/('recipes-after.png' if after else 'recipes-before.png'))
sheet=Image.new('RGB',(180*5,145*4),'#ededed');d=ImageDraw.Draw(sheet)
for i,c in enumerate(images):
 col=i%5;group=i//5
 for state in [0,1]:
  x=col*180;y=(group*2+state)*145
  rendered=drawstack([c],[c],False,bool(state)).crop((0,60,180,180))
  sheet.paste(rendered,(x,y+25));d.text((x+6,y+6),f'{code_to_name[c]} / '+('AFTER' if state else 'BEFORE'),fill='black')
sheet.save(out/'contact-before-after.png')
print('Rendered',len(recipes),'recipes and',checked,'construction states; fitted widths (except natural overhangs) <=',maxwidth+1)
print({c:s.size for c,s in normalized.items()})

# Open stacks expose contact and occlusion that a completed bun conceals.
for lower in images:
 sheet=Image.new('RGB',(180*5,145*8),'#ededed');d=ImageDraw.Draw(sheet)
 for i,upper in enumerate(images):
  for foundation_index,foundation in enumerate(['','P']):
   layers=list(foundation+lower+upper)
   for state in [0,1]:
    x=i%5*180;y=((i//5)*4+foundation_index*2+state)*145
    rendered=drawstack(layers,layers,False,bool(state)).crop((0,60,180,180))
    sheet.paste(rendered,(x,y+25))
    label=foundation+lower+' > '+upper+' / '+('AFTER' if state else 'BEFORE')
    d.text((x+6,y+6),label,fill='black')
 sheet.save(out/('stacking-'+code_to_name[lower].lower()+'.png'))
print('Rendered 200 open-stack cases before/after: all 10 x 10 pairs, with and without patty.')
