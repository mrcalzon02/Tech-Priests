"""Distinct item/research icons composited from the actual separated sprites."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
G=ROOT/'tech-priests_src/graphics/entity'
base=Image.open(G/'bunker-autocannon/base-north.png').convert('RGBA')
cannon=Image.open(G/'bunker-autocannon/idle-04.png').convert('RGBA').crop((0,0,256,256))
for name,cap in [('bunker-autocannon',cannon),
    ('bunker-lobber',Image.open(G/'bunker-lobber/beauty-idle-32.png').convert('RGBA')),
    ('bunker-energy-dish',Image.open(G/'bunker-energy-dish/idle-32.png').convert('RGBA'))]:
    canvas=Image.new('RGBA',(640,640))
    for im,scale in [(base,.315463840961),(cap,.774999976158)]:
        side=round(im.width*scale*2)
        image=im.resize((side,side),Image.Resampling.LANCZOS)
        canvas.alpha_composite(image,(round(320-side/2),round(400-1.11090652*64-side/2)))
    icon=canvas.crop(canvas.getchannel('A').getbbox());icon.thumbnail((120,120),Image.Resampling.LANCZOS)
    result=Image.new('RGBA',(128,128));result.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2))
    result.save(G/name/'icon.png')
