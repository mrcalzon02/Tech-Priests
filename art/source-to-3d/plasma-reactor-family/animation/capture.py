"""Render native online frames, cold plate and emitted-light witnesses with FMPL."""
import argparse,json,sys
from pathlib import Path
import bpy
import numpy as np
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import fmpl_adapter as fmpl

def shadow_geometry(objects,path):
    verts=[];tris=[];offset=0
    for ob in objects:
        if ob.type!='MESH' or ob.get('fmpl_reactor_fx'):continue
        me=ob.data
        co=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get('co',co)
        matrix=np.array(ob.matrix_world,dtype=np.float32)
        verts.append(co.reshape(-1,3)@matrix[:3,:3].T+matrix[:3,3])
        me.calc_loop_triangles()
        ix=np.empty(len(me.loop_triangles)*3,np.int32);me.loop_triangles.foreach_get('vertices',ix)
        tris.append(ix.reshape(-1,3)+offset)
        offset+=len(me.vertices)
    np.savez_compressed(path,verts=np.concatenate(verts),tris=np.concatenate(tris))

def setup_outputs(scene):
    scene.use_nodes=True
    tree=scene.node_tree;tree.nodes.clear()
    rl=tree.nodes.new('CompositorNodeRLayers')
    comp=tree.nodes.new('CompositorNodeComposite');tree.links.new(rl.outputs['Image'],comp.inputs['Image'])
    scene.view_layers[0].use_pass_emit=True
    output=tree.nodes.new('CompositorNodeOutputFile')
    output.format.file_format='PNG';output.format.color_mode='RGB';output.format.color_depth='8'
    tree.links.new(rl.outputs['Emit'],output.inputs[0])
    return output

def capture(opts):
    name=fmpl.NAMES[opts.tier-1];s=bpy.context.scene
    col=bpy.data.collections[name]
    root=next(o for o in col.objects if o.type=='EMPTY' and 'ground pivot' in o.name)
    cfg=fmpl.profile(opts.tier)
    fmpl.audit(s,cfg)
    dest=Path(opts.output).resolve()/name.lower();dest.mkdir(parents=True,exist_ok=True)
    fmpl.select_direction(root,0)
    s.frame_set(1)
    if not (dest/'shadow-geometry.npz').exists():shadow_geometry(col.objects,dest/'shadow-geometry.npz')
    s.render.use_persistent_data=True;s.render.engine='CYCLES'
    s.cycles.samples=opts.samples;s.cycles.use_adaptive_sampling=False;s.cycles.use_denoising=False
    s.cycles.seed=311;s.cycles.use_animated_seed=False
    s.cycles.max_bounces=4;s.cycles.diffuse_bounces=1;s.cycles.glossy_bounces=2
    s.cycles.transmission_bounces=3;s.cycles.volume_bounces=1
    s.cycles.volume_step_rate=1.7;s.cycles.volume_max_steps=80
    s.cycles.transparent_max_bounces=12
    s.cycles.film_transparent_glass=True;s.cycles.film_transparent_roughness=.16
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.render.image_settings.compression=35
    s.render.film_transparent=True
    output=setup_outputs(s)
    for heading in opts.headings:
        folder=dest/heading;folder.mkdir(exist_ok=True)
        fmpl.select_direction(root,fmpl.ANGLE_FOR_HEADING[heading])
        output.base_path=str(folder)
        (folder/'camera.json').write_text(json.dumps(fmpl.audit(s,cfg),indent=2))
        for index in opts.indices:
            if index==17:
                frame,stem=97,'closure'
            elif index==0:
                frame,stem=1,'off'
            else:
                frame,stem=fmpl.ACTIVE_FRAMES[index-1],f'{index:02d}'
            if (folder/(stem+'.ok')).exists():continue
            s['reactor_power']=float(index!=0)
            s.update_tag()
            s.frame_set(frame);bpy.context.view_layer.update()
            output.file_slots[0].path='emit-'+stem+'-'
            s.render.filepath=str(folder/(stem+'.png'))
            bpy.ops.render.render(write_still=True)
            (folder/(stem+'.ok')).touch()
            print('CAPTURED',name,heading,stem,flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('tier',type=int);ap.add_argument('output')
    ap.add_argument('--headings',nargs='+',default=['south','east','north','west'])
    ap.add_argument('--indices',nargs='+',type=int,default=list(range(17)))
    ap.add_argument('--samples',type=int,default=6)
    capture(ap.parse_args(sys.argv[sys.argv.index('--')+1:]))
