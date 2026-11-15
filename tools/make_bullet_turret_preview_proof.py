"""Compare the exact conservative native preview core with the full cap.

Uses the same all-frame opaque intersection as the runtime sheet packer.
"""
from pathlib import Path
import argparse
from PIL import Image,ImageChops,ImageFilter,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('captures',type=Path);a=p.parse_args()
base=Image.open(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon/base-north.png').convert('RGBA')
board=Image.new('RGB',(960,900),(35,38,42));draw=ImageDraw.Draw(board)
for row,(name,frames) in enumerate((('chicago-piano',24),('twin-minigun',18))):
    capture=a.captures/name
    idle=Image.open(capture/'d32-idle-body.png').convert('RGBA');minimum=idle.getchannel('A')
    for frame in range(frames):
        with Image.open(capture/f'd32-f{frame:02}-body.png') as im:minimum=ImageChops.darker(minimum,im.getchannel('A'))
    core=idle.copy();core.putalpha(minimum.point(lambda x:255 if x==255 else 0).filter(ImageFilter.MinFilter(3)))
    core.save(capture/'native-preview-pilot.png')
    for col,cap in enumerate((core,idle)):
        canvas=Image.new('RGBA',(640,640))
        for im,scale in ((base,.315463840961),(cap,.774999976158)):
            size=round(im.width*scale*2)
            canvas.alpha_composite(im.resize((size,size),Image.Resampling.LANCZOS),(round(320-size/2),round(400-1.11090652*64-size/2)))
        crop=canvas.crop(canvas.getchannel('A').getbbox());crop.thumbnail((430,380),Image.Resampling.LANCZOS)
        board.paste(crop,(col*480+(480-crop.width)//2,row*450+35),crop)
        draw.text((col*480+20,row*450+410),name+(' / native preview core' if col==0 else ' / full animated cap'),fill='white')
board.save(a.captures/'native-preview-proof.png')
