# /// script
# dependencies = ["opencv-python-headless==5.0.0.93", "pillow==13.0.0"]
# ///
"""uv run reproduce.py /path/movement.mp4 /tmp/r031h-rebuilt
Verify source; regenerate sheets and adjacent-frame difference receipts.
JPEG byte identity may vary by encoder; manifest identifies reviewed originals.
"""
import csv, hashlib, json, sys
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

source, out = Path(sys.argv[1]), Path(sys.argv[2])
assert out.resolve() != Path(__file__).resolve().parent, 'Do not overwrite reviewed evidence'
manifest = json.loads(Path(__file__).with_name('manifest.json').read_text())
assert source.stat().st_size == manifest['source_bytes']
assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest['source_sha256']
out.mkdir(parents=True, exist_ok=True)
cap = cv2.VideoCapture(str(source))
assert int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) == manifest['source_frames']
assert cap.get(cv2.CAP_PROP_FPS) == 60
for name, spec in manifest['sheets'].items():
    frames, crop, w = spec['frames'], spec['crop'], spec['width']
    h = round(w * (crop[3]-crop[1]) / (crop[2]-crop[0])) if crop else round(w*1080/1920)
    canvas = Image.new('RGB', (w*3, (h+28)*((len(frames)+2)//3)), '#101820')
    draw = ImageDraw.Draw(canvas)
    for i, n in enumerate(frames):
        cap.set(cv2.CAP_PROP_POS_FRAMES, n)
        ok, bgr = cap.read()
        assert ok, n
        im = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
        if crop: im = im.crop(crop)
        x, y = (i%3)*w, (i//3)*(h+28)
        canvas.paste(im.resize((w,h)), (x,y+28))
        draw.text((x+8,y+7), f'n={n}   t={n/60:.4f}s', fill='white')
    canvas.save(out/(name+'.jpg'), quality=90)
with (out/'adjacent-difference.csv').open('w') as f:
    writer = csv.writer(f)
    writer.writerow(['previous_frame','frame','recording_seconds','crop_mean_abs_channel_difference_0_255'])
    # Crop is fixed in original pixels; includes character + environment, NOT a world-space tracker.
    for lo, hi in [(7374,7428),(7476,7500)]:
        cap.set(cv2.CAP_PROP_POS_FRAMES,lo)
        ok, prev = cap.read(); assert ok
        for n in range(lo+1,hi+1):
            ok, im = cap.read(); assert ok
            delta = float(np.mean(cv2.absdiff(im[260:900,600:1280],prev[260:900,600:1280])))
            writer.writerow([n-1,n,f'{n/60:.6f}',f'{delta:.6f}'])
            prev = im
cap.release()
print('Source fingerprint, frame count and sheet reproduction: PASS')
