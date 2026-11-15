"""Deliver the owner's accepted source and actual four-angle captures."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image,ImageDraw

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',required=True)
    ap.add_argument('--capture',required=True);ap.add_argument('--source-checks',required=True)
    ap.add_argument('--out',required=True);ap.add_argument('--native-jig');args=ap.parse_args()
    native=Path(args.native).resolve();cap=Path(args.capture).resolve();checks=Path(args.source_checks).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Accepted source/delivery is immutable')
    receipt=json.loads((cap/'capture.json').read_text());qa=json.loads((cap/'qa.json').read_text())
    reopened=json.loads((cap/'reopen-qa.json').read_text());cfg=receipt['config']
    if not qa['passed'] or not reopened['passed'] or len(receipt['frames'])!=36:raise RuntimeError('Incomplete capture gates')
    if cfg['directions']!=[0,90,180,270] or cfg['fps']!=2 or cfg['cycle_seconds']!=4:raise RuntimeError('Wrong requested views/clock')
    if sha(native)!=receipt['source_sha256']:raise RuntimeError('Accepted source/capture mismatch')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    shutil.copy2(native,out/'water-purifier-v16.blend')
    shutil.copytree(cap,out/'captures')
    for name in ('service-fit-receipt.json','service-independent-readback.json','idle.png','working.png'):
        shutil.copy2(checks/name,out/name)
    if args.native_jig:
        jig=Path(args.native_jig).resolve();target=out/'native-physical-jig';target.mkdir()
        for name in ('native-jig-receipt.json','create.log','flow.log'):shutil.copy2(jig/name,target/name)
        (target/'.gitattributes').write_bytes(b'*.log -text -diff\n')
    # Atlas row map follows the existing verified boiler/condenser camera:
    # positive Blender yaw and native east/west are opposite.
    views=[('North',0),('East',3),('South',2),('West',1)]
    def panel(state,index):
        canvas=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(canvas)
        for slot,(label,direction) in enumerate(views):
            x=(slot%2)*256;y=(slot//2)*276
            with Image.open(cap/f'frames/{state}/d{direction:02d}/f{index:03d}.png') as im:
                rgba=im.convert('RGBA');canvas.paste(rgba,(x,y),rgba.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return canvas
    panel('idle',0).save(out/'purifier-four-angle-idle.png')
    frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'purifier-four-angle-working.webp',save_all=True,append_images=frames[1:],duration=500,loop=0,lossless=True)
    frames[0].save(out/'purifier-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=500,loop=0,disposal=2)
    acceptance=dict(status='OWNER_ACCEPTED_MODEL; FOUR_ANGLE_CAPTURE_DELIVERED',source_sha256=sha(native),
        owner_instruction="Good I'd call that done let's finish the animation Capture the four angles idol and animated and let's move on.",
        scope='Current purifier shape/finish accepted; deliver four actual idle views and animated views; proceed to electrolyzer.',
        source_camera='one fixed 45-degree orthographic camera; model rotated for four actual captures',
        source_yaw_degrees=[0,90,180,270],view_map={label:row for label,row in views},
        idle_views=4,working_views=4,working_frames_per_view=8,total_native_frames=36,
        cycle_seconds=4,preview_frame_duration_ms=500,atlas_resolutions=[64,128,256],atlas_count=6,
        capture_qa_passed=True,master_reopen_passed=True,
        native_prototype='isolated physical pipe/flow jig passed separately; ordinary mod not promoted',
        future_purifier_shape_work='Move on; no further speculative model refinement.',
        next_machine='electrolyzer')
    (out/'ACCEPTANCE.json').write_text(json.dumps(acceptance,indent=2)+'\n')
    (out/'README.md').write_text('# Owner-accepted purifier V16\n\n'
        'The owner accepted this model and requested four idle and animated views before moving to the electrolyzer. '
        'These are 36 actual Blender renders: four idle views and eight working frames for each of four angles. '
        'The six 64/128/256 atlases, saved capture master and independently reopened/hash-checked receipts are included.\n\n'
        'Preview loop: 4 seconds. Source yaw rows are 0, 90, 180, 270; family camera mapping is North=0, East=3, South=2, West=1. '
        'This is capture delivery, not a claim of ordinary game installation or final graphical pipe seating.\n',encoding='utf-8')
    manifest={str(p.relative_to(out)).replace('\\','/'):sha(p) for p in sorted(out.rglob('*')) if p.is_file()}
    (out/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('FOUR_VIEW_DELIVERY',out,'files',len(manifest),flush=True)

if __name__=='__main__':main()
