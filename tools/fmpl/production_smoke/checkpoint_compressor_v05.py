"""Preserve the eight-second retime, real captures, and audible review preview."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageDraw


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p, value): Path(p).write_text(json.dumps(value, indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser()
    for name in ('source','native','native-capture','audio','audio-readback','out'): ap.add_argument('--'+name,required=True)
    args=ap.parse_args();src=Path(args.source);native=Path(args.native);audio=Path(args.audio);out=Path(args.out)
    if out.exists(): raise FileExistsError('Preserve candidate snapshots')
    retime=json.loads((src/'retime-readback.json').read_text());export=json.loads((src/'export-readback.json').read_text())
    capture=json.loads((src/'captures/capture.json').read_text())
    if not retime['passed'] or retime['native_sha256']!=sha(src/'compressor-v05.blend') or retime['equivalent_pose_error']!=0: raise RuntimeError('Retime gate')
    if not export['passed'] or export['glb_sha256']!=sha(src/'compressor-v05.glb'): raise RuntimeError('Export gate')
    if capture['source_sha256']!=sha(src/'compressor-v05.blend') or len(capture['frames'])!=36: raise RuntimeError('Capture source/count gate')
    for name in ('qa.json','reopen-qa.json'):
        if not json.loads((src/'captures'/name).read_text())['passed']: raise RuntimeError('Capture '+name)
    nr=json.loads((native/'native-jig-receipt.json').read_text())
    if not nr['passed'] or nr['diagnostic_frame_counters'] or nr['model_source_sha256']!=sha(src/'compressor-v05.blend'): raise RuntimeError('Native gate')
    if json.loads((native/'spec.json').read_text())['rear_collar_layer']: raise RuntimeError('Rejected rear collar overlay cannot be delivered')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for name in ('compressor-v05.blend','compressor-v05.glb','retime-readback.json','export-readback.json','construction-receipt.json','part_provenance.json','port_manifest.json','working-front.png'): shutil.copy2(src/name,out/name)
    for name in ('textures','captures'): shutil.copytree(src/name,out/name,ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    native_cap=Path(args.native_capture)
    for name in ('qa.json','reopen-qa.json','native-fitting-readback.json'):
        if not json.loads((native_cap/name).read_text())['passed']: raise RuntimeError('Native capture '+name)
    shutil.copytree(native_cap,out/'native-captures',ignore=shutil.ignore_patterns('*.log','checkpoint-*.json'))
    shutil.copytree(native/'mods/tp-mh7-compressor-review_0.0.1',out/'review-mod/tp-mh7-compressor-review_0.0.1')
    shutil.copy2(native/'native-jig-receipt.json',out/'native-jig-receipt.json')
    shutil.copy2(args.audio_readback,audio/'native-audio-readback.json')
    def panel(state,i):
        canvas=Image.new('RGB',(512,552),(33,35,38));draw=ImageDraw.Draw(canvas)
        for slot,(label,direction) in enumerate((('North',0),('East',3),('South',2),('West',1))):
            x=slot%2*256;y=slot//2*276
            with Image.open(src/f'captures/frames/{state}/d{direction:02d}/f{i:03d}.png') as im:
                im=im.convert('RGBA');canvas.paste(im,(x,y),im.getchannel('A'))
            draw.text((x+12,y+259),label,fill='white')
        return canvas
    panel('idle',0).save(out/'compressor-four-angle-idle.png')
    frames=[panel('working',i) for i in range(8)]
    frames[0].save(out/'compressor-four-angle-working.gif',save_all=True,append_images=frames[1:],duration=1000,loop=0,disposal=2)
    preview=out/'preview-frames';preview.mkdir()
    for i,im in enumerate(frames): im.save(preview/f'{i:03d}.png')
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','1','-i',str(preview/'%03d.png'),'-i',str(audio/'masters/compressor-working.wav'),'-t','8','-c:v','libx264','-r','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'compressor-working-with-sound.mp4')],check=True)
    shutil.rmtree(preview)
    checkpoint=dict(status='retimed_and_audible_review_candidate',cycle_seconds=8,source_sha256=sha(src/'compressor-v05.blend'),glb_sha256=sha(src/'compressor-v05.glb'),
        equivalent_pose_error=0,capture_frames=36,atlas_count=6,native_fluid_tests_passed=True,owner_animation_observation='All appeared to be animating correctly',
        graphical_seating_verified=False,native_animation_clock_verified=False,owner_approved=False,ordinary_mod_installed=False,
        audio_bank='../../../shared-audio/hydrogen-machinery/v01',top_port='Owner reported hard clipping; separate rear-collar overlay rejected in private study. Native seam remains open.')
    write(out/'CHECKPOINT.json',checkpoint)
    (out/'README.md').write_text('# Compressor V05: slower motion and authored sound\n\n'
        'The actual 27 source actions now run an eight-second cycle, half the previous speed. Equivalent poses have zero measured change and the geometry digest is unchanged. The actual eight-second GLB was reimported and checked. Four real directions, idle and eight working poses, six sheets and the reopened master are included. V04 remains preserved.\n\n'
        'The MP4 pairs the authored compressor loop with the slower four-angle capture. The shared audio bank contains working roar/chatter/chuffs plus start, idle and shutdown cues, and distinct quieter purifier/electrolyzer loops. Its audio-only extension must be enabled alongside the included compressor review mod. Actual Factorio data-stage bindings pass for all three machines.\n\n'
        'The isolated native compressor passes 16 pipe-mask/rotation sites and real fluid delivery in four rotations. The owner observed the animations working. Exact native frame-clock verification remains open. The reported top-port seam is still open; a separate rear-collar overlay worsened the view and is excluded. This is a review candidate, not owner approval or ordinary chain integration.\n',encoding='utf-8')
    for root in (out,audio): write(root/'SHA256.json',{p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    print('COMPRESSOR_V05_PACKAGED',out)


if __name__=='__main__': main()
