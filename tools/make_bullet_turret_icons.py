"""Make original item icons from actual cap captures on the fixed bunker."""
from pathlib import Path
import argparse
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('captures',type=Path);a=p.parse_args()
base=Image.open(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon/base-north.png').convert('RGBA')
board=Image.new('RGB',(960,510),(35,38,42));draw=ImageDraw.Draw(board)
for index,name in enumerate(('chicago-piano','twin-minigun')):
    cap=Image.open(a.captures/name/'d32-idle-body.png').convert('RGBA')
    canvas=Image.new('RGBA',(640,640))
    for im,scale in [(base,.315463840961),(cap,.774999976158)]:
        size=round(im.width*scale*2)
        canvas.alpha_composite(im.resize((size,size),Image.Resampling.LANCZOS),
            (round(320-size/2),round(400-1.11090652*64-size/2)))
    crop=canvas.crop(canvas.getchannel('A').getbbox())
    large=crop.copy();large.thumbnail((430,440),Image.Resampling.LANCZOS)
    board.paste(large,(index*480+(480-large.width)//2,40),large)
    draw.text((index*480+20,480),name+' / actual separated sprites',fill='white')
    crop.thumbnail((120,120),Image.Resampling.LANCZOS)
    icon=Image.new('RGBA',(128,128));icon.alpha_composite(crop,((128-crop.width)//2,(128-crop.height)//2))
    dest=ROOT/'tech-priests_src/graphics/entity'/('bunker-'+name);dest.mkdir(parents=True,exist_ok=True)
    icon.save(dest/'icon.png')
board.save(a.captures/'mounted-pilot.png')
