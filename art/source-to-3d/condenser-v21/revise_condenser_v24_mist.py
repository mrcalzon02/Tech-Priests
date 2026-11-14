"""V24 approval candidate: ragged, inlet-aligned, stretching intake mist.

Load the exact V23 inlet review; modify only effect materials, effect scale
animation and effect orientation constraints. No hardware or piston changes.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

SOURCE_SHA='5b7a8bb22a23463db555eba8cdb9327180a67939dc151ec59e0d44ec1461d554'

def material(index):
    mat=bpy.data.materials.new('V24 ragged suction mist %02d'%index)
    mat.use_nodes=True
    ns,ls=mat.node_tree.nodes,mat.node_tree.links
    ns.clear()
    def node(kind,name):
        o=ns.new(kind);o.label=name;return o
    def mathnode(op,a,b=None):
        o=node('ShaderNodeMath',op);o.operation=op
        for i,v in enumerate((a,b)):
            if v is None:continue
            if isinstance(v,(float,int)):o.inputs[i].default_value=v
            else:ls.new(v,o.inputs[i])
        return o.outputs[0]
    uv=node('ShaderNodeTexCoord','particle UV')
    warp=node('ShaderNodeTexNoise','large turbulent edge lobes')
    warp.noise_dimensions='4D'
    warp.inputs['Scale'].default_value=4.3
    warp.inputs['Detail'].default_value=3.0
    warp.inputs['Roughness'].default_value=.72
    warp.inputs['W'].default_value=index*1.713
    ls.new(uv.outputs['UV'],warp.inputs['Vector'])
    # Perturb the radial envelope itself. V22 only varied density inside a
    # perfectly circular falloff, which retained a uniform oval silhouette.
    dist=node('ShaderNodeVectorMath','radial distance');dist.operation='DISTANCE'
    dist.inputs[1].default_value=(.5,.5,0)
    ls.new(uv.outputs['UV'],dist.inputs[0])
    edgeoffset=mathnode('MULTIPLY',mathnode('SUBTRACT',warp.outputs['Fac'],.5),.42)
    ragged=mathnode('ADD',dist.outputs['Value'],edgeoffset)
    rim=node('ShaderNodeMapRange','irregular feathered boundary')
    rim.clamp=True;rim.interpolation_type='SMOOTHERSTEP'
    rim.inputs['From Min'].default_value=.19
    rim.inputs['From Max'].default_value=.46
    rim.inputs['To Min'].default_value=.88
    rim.inputs['To Max'].default_value=0
    ls.new(ragged,rim.inputs['Value'])
    mapping=node('ShaderNodeVectorMath','streaks parallel to pull');mapping.operation='MULTIPLY'
    mapping.inputs[1].default_value=(3.0,5.0,1)
    ls.new(uv.outputs['UV'],mapping.inputs[0])
    fine=node('ShaderNodeTexNoise','broken wispy filaments')
    fine.noise_dimensions='4D';fine.inputs['Scale'].default_value=2.2
    fine.inputs['Detail'].default_value=2.5;fine.inputs['W'].default_value=index*.831
    ls.new(mapping.outputs[0],fine.inputs['Vector'])
    texture=node('ShaderNodeMapRange','interior gaps')
    texture.clamp=True
    texture.inputs['From Min'].default_value=.25
    texture.inputs['From Max'].default_value=.72
    texture.inputs['To Min'].default_value=.18
    texture.inputs['To Max'].default_value=.85
    ls.new(fine.outputs['Fac'],texture.inputs['Value'])
    safety=node('ShaderNodeMapRange','fade before quad boundary')
    safety.clamp=True;safety.interpolation_type='SMOOTHERSTEP'
    safety.inputs['From Min'].default_value=.41
    safety.inputs['From Max'].default_value=.495
    safety.inputs['To Min'].default_value=1
    safety.inputs['To Max'].default_value=0
    ls.new(dist.outputs['Value'],safety.inputs['Value'])
    density=mathnode('MULTIPLY',mathnode('MULTIPLY',rim.outputs['Result'],texture.outputs['Result']),safety.outputs['Result'])
    transparent=node('ShaderNodeBsdfTransparent','air')
    pale=node('ShaderNodeEmission','existing pale steam')
    pale.inputs['Color'].default_value=(.66,.81,.83,1)
    pale.inputs['Strength'].default_value=.88
    mix=node('ShaderNodeMixShader','wisps over air')
    ls.new(density,mix.inputs[0]);ls.new(transparent.outputs[0],mix.inputs[1]);ls.new(pale.outputs[0],mix.inputs[2])
    out=node('ShaderNodeOutputMaterial','surface');ls.new(mix.outputs[0],out.inputs['Surface'])
    # Slow coherent evolution instead of frame-random noise flicker.
    for frame in range(1,98):
        phase=(frame-1)%96/96*math.tau
        warp.inputs['W'].default_value=index*1.713+.24*math.sin(phase)
        warp.inputs['W'].keyframe_insert(data_path='default_value',frame=frame)
        fine.inputs['W'].default_value=index*.831+.35*math.sin(phase+.6)
        fine.inputs['W'].keyframe_insert(data_path='default_value',frame=frame)
    return mat

def mist_scale(frame,head,k,cloud):
    stage=(frame-1)%96
    phase=(stage%12)/12
    progress=((phase-.11)/.80-k*.10)/(1-k*.10)
    if stage//12!=head or phase<=.11 or phase>=.91 or not 0<progress<1:
        return Vector((.00001,)*3)
    fade=math.sin(math.pi*progress)**.65
    width=(.14+.025*math.cos(k*2.4))*fade
    # Growing length and narrowing cross section communicate acceleration
    # into the opening. Local X is continuously aimed at that inlet.
    stretch=1.0+.85*math.sin(progress*math.pi*.75)
    outside,inside=Vector(cloud['fx_origin']),Vector(cloud['fx_destination'])
    eased=progress*progress*(3-2*progress)
    distance=(outside-inside).length*(1-eased)
    length=min(width*stretch,distance*.78+.012)
    return Vector((length,width*(.79-.35*progress),width))

def run(source,out):
    if hashlib.sha256(source.read_bytes()).hexdigest()!=SOURCE_SHA:
        raise RuntimeError('Expected exact V23 inlet-review source')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene;s.frame_set(1)
    clouds=sorted([o for o in s.objects if o.get('FX_ONLY_INWARD_ATMOSPHERIC_INTAKE')],key=lambda o:o.name)
    if len(clouds)!=40:raise RuntimeError('Expected 40 existing mist particles')
    for i,cloud in enumerate(clouds):
        head=int(cloud.name.split('mist ')[1].split('.')[0])
        k=int(cloud['mist_puff_index'])
        cloud.data.materials.clear();cloud.data.materials.append(material(i))
        # Preserve the camera-facing constraint; then turn only within the
        # plane toward a genuine 3D inlet target. This also works at each yaw.
        target=bpy.data.objects.new('V24 mist inlet target %02d'%i,None)
        cloud.users_collection[0].objects.link(target)
        target.parent=cloud.parent
        target.location=cloud['fx_destination']
        target.empty_display_size=.01
        aim=cloud.constraints.new('LOCKED_TRACK')
        aim.name='V24 stretch axis points into inlet'
        aim.target=target;aim.track_axis='TRACK_X';aim.lock_axis='LOCK_Z'
        for frame in range(1,98):
            cloud.scale=mist_scale(frame,head,k,cloud)
            cloud.keyframe_insert(data_path='scale',frame=frame)
    s.frame_set(1)
    s['animation_review_revision']='V24 ragged suction mist; owner approval pending'
    s['v24_source_sha256']=SOURCE_SHA
    s['v24_change_scope']='mist alpha silhouette, filament density, inlet-aligned stretching only'
    s['owner_visual_approved']=False
    out.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);run(a.source.resolve(),a.out.resolve())
