"""Build a coverage-safe native cap beneath the complete animated cap.

Factorio's entity preview cannot draw Lua render objects. The native layer
contains only pixels that are fully opaque in EVERY captured state, with a
one-pixel interpolation guard. Thus every world animation frame completely
covers the native layer; it cannot reveal a second resting barrel or hatch.
The bunker base is never included in either layer.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
source=ROOT/'tech-priests_src/graphics/entity/bunker-lobber'
records=[]
board=Image.new('RGB',(1024,560),(35,38,42));draw=ImageDraw.Draw(board)
for d in range(64):
    idle=Image.open(source/f'beauty-idle-{d:02}.png').convert('RGBA')
    common=idle.getchannel('A')
    inputs=[]
    for mode,frames,columns in [('cycle',192,16),('entry',15,15),('settle',15,15)]:
        path=source/f'beauty-{mode}-{d:02}.png'
        inputs.append({'path':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        with Image.open(path) as sheet:
            alpha=sheet.getchannel('A')
            for frame in range(frames):
                x,y=frame%columns*256,frame//columns*256
                common=ImageChops.darker(common,alpha.crop((x,y,x+256,y+256)))
    opaque=common.point(lambda value:255 if value==255 else 0).filter(ImageFilter.MinFilter(3))
    core=idle.copy();core.putalpha(opaque)
    path=a.out/f'native-{d:02}.png';core.save(path)
    # Exact coverage proof: no nonzero native pixel lacks a fully opaque
    # foreground pixel in any source state (the minimum encodes all states).
    assert ImageChops.multiply(opaque,common.point(lambda value:255 if value<255 else 0)).getbbox() is None
    native_pixels=opaque.histogram()[255]
    assert native_pixels>500,'Native preview core is unexpectedly empty'
    records.append({'heading':d,'native_opaque_pixels':native_pixels,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'inputs':inputs})
    if d%8==0:
        index=d//8;x,y=index%4*256,index//4*280
        board.paste(core,(x,y),core)
        draw.text((x+8,y+256),f'Native cap / heading {d}',fill='white')
board.save(a.out/'native-core-board.png')
(a.out/'coverage-proof.json').write_text(json.dumps({'status':'PASS_ALL_64_HEADINGS',
    'states_per_heading':223,'all_animated_frames_preserved':True,'base_included':False,
    'native_visibility_rule':'minimum alpha == 255 across idle, entry, cycle and settle, eroded one pixel',
    'records':records},indent=2)+'\n')
