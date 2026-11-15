"""Capture the independently driven aerial sprites alongside body capture."""
from pathlib import Path
import hashlib
helper=Path(__file__).with_name('capture_twin_cannon.py')
kit=helper.read_text().split('started=time.monotonic()')[0]
kit=kit.replace("'script_sha256':", "'capture_helpers_sha256':hashlib.sha256(helper.read_bytes()).hexdigest(),'script_sha256':")
exec(compile(kit,str(helper),'exec'),globals())
cap_rest=[obj.location+Vector((0,0,max(v.co.z for v in obj.data.vertices))) for obj in whips]
for obj in body:obj.data.materials.clear();obj.data.materials.append(hold)
started=time.monotonic()
for d in directions:
    for bank in (0,1):
        pose(d,'idle',0)
        for obj in aerials:obj.hide_render=obj not in (whips[bank],caps[bank])
        for ix,x in enumerate(identity['aerial_tip_offsets']):
            for iy,y in enumerate(identity['aerial_tip_offsets']):
                whip=whips[bank];whip.data.shape_keys.key_blocks[1].value=x/.24;whip.data.shape_keys.key_blocks[2].value=y/.24
                caps[bank].location=cap_rest[bank]+Vector((x,y,0))
                bpy.context.view_layer.update();capture(out/f'd{d:02}-aerial{bank}-{ix*5+iy:02}.png')
    print('CANNON_AERIAL_DIRECTION',d,'seconds',round(time.monotonic()-started,1),flush=True)
(out/'capture.json').write_text(json.dumps({'status':'COMPLETE','pass':'aerial','identity':identity,
    'directions':directions,'elapsed_seconds':time.monotonic()-started},indent=2)+'\n')
