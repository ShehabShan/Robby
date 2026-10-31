# /// script
# dependencies = ["pillow"]
# ///
"""Build the committed headless review sheet from Blender renders. Not a live capture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'research/notes/T-043d1-previews'
OUT.mkdir(parents=True, exist_ok=True)
BUILD = ROOT / 'build/art/rime_m1'
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n):
    return ImageFont.truetype(font_path,n) if Path(font_path).exists() else ImageFont.load_default(size=n)
board=Image.new('RGB',(1440,1420),'#0d1720'); d=ImageDraw.Draw(board)
d.text((32,24),'RIMESHARD / HAND-SHAPED FROST',font=font(32),fill='#d7f5ff')
d.text((32,72),'M1 prototype - original source - headless R15-proportion mannequin, NOT Roblox footage',font=font(19),fill='#92b4c6')
for i,(name,title,desc) in enumerate([
    ('needle_1','01 / LEFT FLICK','One narrow dart; left hand releases.'),
    ('needle_2','02 / RIGHT COUNTER','Right-hand contrast; same gameplay size.'),
    ('needle_pair','03 / PAIRED FINISH','Two darts, not one wide hit; 6 deg spread.')]):
    x=24+i*472
    d.text((x,116),title,font=font(25),fill='#a7e7fa')
    for j,phase in enumerate(['release','recover']):
        im=Image.open(BUILD/(name+'-'+phase+'.png')).convert('RGB').resize((448,448))
        y=160+j*500; board.paste(im,(x,y))
        d.text((x+12,y+12),'RELEASE AT t=0' if j==0 else 'RECOVERY / NO NEW SHOT',font=font(18),fill='#e1f3f5')
    d.text((x,614),desc,font=font(17),fill='#bcd4dd')
    d.text((x,1118),'.25 s light recovery' if i<2 else '1.20 s finisher recovery',font=font(19),fill='#bcd4dd')
shape=Image.open(BUILD/'shards.png').convert('RGB').resize((240,240))
board.paste(shape,(24,1160))
d.text((288,1175),'FACET FAMILY / 16 triangles each',font=font(25),fill='#a7e7fa')
for j,line in enumerate(['Left / right / brighter paired variant; 1.8-stud dart length, original procedural geometry.',
                         'Arms only: root, waist, head and legs are not driven by the action clips.',
                         'No gameplay changes, sounds, camera shake, uploads or publication.',
                         'Timing contract + client integration next. Real motion, avatar fit and phone readability unverified.']):
    d.text((288,1220+j*35),line,font=font(17),fill='#bcd4dd')
board.save(OUT/'m1-board.jpg',quality=91)
print('BOARD:',OUT/'m1-board.jpg')
frames=[]
for path in sorted((BUILD/'motion').glob('*.png')):
    im=Image.open(path).convert('RGB'); draw=ImageDraw.Draw(im)
    draw.rectangle((0,0,320,44),fill='#0d1720')
    draw.text((10,6),'OFFLINE POSE CURVES / NOT GAMEPLAY',font=font(12),fill='#d7f5ff')
    draw.text((10,25),f"t={min(int(path.stem)/10,1.7):.2f}s / release is immediate",font=font(12),fill='#92b4c6')
    frames.append(im)
if frames:
    frames[0].save(OUT/'m1-motion.gif',save_all=True,append_images=frames[1:],duration=100,loop=0)
    print('MOTION:',len(frames),'offline frames')
