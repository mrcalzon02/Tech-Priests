"""Native Cycles approval renders; fixed 45-degree camera and real geometry.

Four directional stills, a full 96-frame/12s north cycle, and a 24-frame
three-second intake close-up. Close-up is diagnostic, not export framing.
"""
import argparse,json,math,sys
from pathlib import Path
import bpy
from mathutils import Matrix,Vector

def run(source,out,mode):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene
    s.render.engine='CYCLES';s.cycles.samples=12;s.cycles.use_denoising=True
    s.render.use_persistent_data=True
    s.render.threads_mode='FIXED';s.render.threads=8
    s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100
    s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    out.mkdir(parents=True,exist_ok=True)
    def render(path,frame):
        s.frame_set(frame);bpy.context.view_layer.update()
        s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    if mode in ('probe','stills'):
        turntable=bpy.data.objects['FX ONLY | entity export turntable']
        originals=json.loads(s['source_world_matrices'])
        parents=json.loads(s['source_original_parents'])
        for yaw in ([0] if mode=='probe' else [0,90,180,270]):
            turntable.rotation_euler.z=math.radians(yaw)
            rotate=Matrix.Rotation(math.radians(yaw),4,'Z')
            for name,par in parents.items():
                if par is None:
                    o=bpy.data.objects.get(name)
                    if o and not name.startswith(('Reference pipe','Grid ','PIPE_FIT_','FMPL_CAPTURE_')):
                        o.matrix_world=rotate@Matrix(originals[name])
            render(out/('full_%03d.png'%yaw),7)
        if mode=='probe':
            s.camera.location+=Vector((-.16,.14,.32));s.camera.data.ortho_scale=1.35
            s.render.resolution_x=s.render.resolution_y=768
            render(out/'close_probe.png',7)
    elif mode=='cycle':
        s.render.resolution_x=s.render.resolution_y=384
        for frame in range(1,97):render(out/('cycle_%03d.png'%frame),frame)
    elif mode=='close':
        s.camera.location+=Vector((-.16,.14,.32));s.camera.data.ortho_scale=1.35
        for frame in range(1,25):render(out/('close_%03d.png'%frame),frame)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--mode',choices=['probe','stills','cycle','close'],required=True)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);run(a.source.resolve(),a.out.resolve(),a.mode)
