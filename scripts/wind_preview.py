# /// script
# dependencies = ["pillow"]
# ///
"""Offline actual-plan schematic. No Roblox/physics/render-quality claim."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT/'build/wind_preview.json').read_text())
OUT = ROOT/'research/notes/wind-step-preview'
OUT.mkdir(exist_ok=True)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(size):
    return ImageFont.truetype(FONT, size) if Path(FONT).exists() else ImageFont.load_default(size=size)
def scene(row, width=320, height=170, light=False, moving=False):
    bg=(229,236,229) if light else (21,34,36)
    im=Image.new('RGB',(width,height),bg);d=ImageDraw.Draw(im)
    grid=(201,215,204) if light else (35,52,52)
    for x in range(0,width,32): d.line((x,0,x,height), fill=grid)
    for y in range(0,height,32): d.line((0,y,width,y),fill=grid)
    scale=14; x=(46+row['position']*14) if moving else width*.64; y=height*.52
    f=row['frame']; layer=Image.new('RGBA',im.size);p=ImageDraw.Draw(layer)
    for r in f['ribbons']:
        side=r['side']; yy=y+side*17; length=r['length']*scale
        # Three-point swept taper; pale outer edge, jade core. Local root-space only.
        points=[(x+4,yy),(x-length*.4,yy+side*8),(x-length,yy+side*3),
                (x-length*.4,yy+side*(8-r['width']*scale)),(x+4,yy-side*2)]
        alpha=int(255*r['opacity'])
        p.line(points+[points[0]],fill=(26,112,86,alpha),width=3)
        p.polygon(points,fill=(127,224,184,alpha));p.line(points[:3],fill=(222,255,237,alpha),width=1)
    for m in f['motes']:
        xx=x-m['behind']*scale; yy=y+m['side']*23+m['height']*scale
        z=max(1,m['size']*scale)
        p.polygon([(xx,yy-z),(xx+z,yy),(xx,yy+z),(xx-z,yy)],fill=(177,244,205,int(m['opacity']*255)))
    if f['arc']:
        p.arc((x-25,y-26,x+18,y+26),110,250,fill=(203,255,225,int(f['arc']*255)),width=3)
    im=Image.alpha_composite(im.convert('RGBA'),layer).convert('RGB');d=ImageDraw.Draw(im)
    # Neutral top-down stand-in, deliberately not represented as authored R15 art.
    d.ellipse((x-14,y-14,x+14,y+14),fill=(69,84,99),outline=(176,189,204),width=2)
    d.ellipse((x+6,y-7,x+20,y+7),fill=(223,204,176),outline=(52,64,75))
    d.line((x+29,y,x+55,y),fill=(80,134,110) if light else (158,191,173),width=2)
    d.polygon([(x+55,y),(x+49,y-4),(x+49,y+4)],fill=(80,134,110) if light else (158,191,173))
    if row.get('label')=='Stopped by wall':
        d.rectangle((x+24,12,x+35,height-12),fill=(126,112,100))
    return im

def board(width):
    cols=3 if width>320 else 1; cell=width//cols; rows=math.ceil(6/cols)
    im=Image.new('RGB',(width,124+rows*238+62),(12,22,25));d=ImageDraw.Draw(im)
    d.text((16,14),'WIND STEP / SLIPSTREAM',font=font(19 if cols>1 else 16),fill='#d9f7e6')
    d.text((16,44),'Offline design prototype',font=font(15),fill='#90cfb2')
    d.text((16,70),'Actual pure-plan output; not Roblox footage.',font=font(11 if cols==1 else 14),fill='#a5b6bb')
    d.text((16,92),'Jade wind  /  travel intent  /  bounded fade',font=font(12),fill='#a5b6bb')
    for i,row in enumerate(DATA['phases']):
        xx=(i%cols)*cell; yy=124+(i//cols)*238
        im.paste(scene(row,cell,170,light=i%2==1),(xx,yy))
        d.text((xx+12,yy+179),f"{i+1:02} {row['label']}",font=font(15),fill='#d9f7e6')
        d.text((xx+12,yy+202),f"{int(row['elapsed']*1000)}ms | {row['frame']['phase']} | {len(row['frame']['ribbons'])} ribbons",font=font(12),fill='#9ab4b6')
    d.text((12,im.height-50),'No live movement or appearance changed.',font=font(12),fill='#9ab4b6')
    d.text((12,im.height-29),'Original character required; no damage cue.',font=font(12),fill='#9ab4b6')
    im.save(OUT/f'board-{width}.png')
board(960);board(320)
frames=[]
for row in DATA['animation']:
    im=scene(row,320,180,moving=True);d=ImageDraw.Draw(im)
    d.text((8,8),'OFFLINE / actual-plan schematic',font=font(11),fill='#d9f7e6')
    d.text((8,160),row['frame']['phase'],font=font(12),fill='#90cfb2');frames.append(im)
frames[0].save(OUT/'slipstream.gif',save_all=True,append_images=frames[1:],duration=[17,17,16]*20,loop=0,disposal=2)
(OUT/'plan.json').write_text(json.dumps(DATA,indent=2)+'\n')
print('PREVIEW:', ', '.join(p.name for p in OUT.iterdir()))
