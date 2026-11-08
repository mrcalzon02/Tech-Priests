"""Prepare the approved animated boiler for the common sprite pipeline.

Blender: -b approved.blend --python tools/art/prepare_boiler_source.py -- --out PATH
Adds a cold frame zero, skips zero-density steam, and enables render caching.
Retains all authored mesh geometry, animation timing, lighting and materials.
"""
import argparse
from pathlib import Path
import sys
import bpy

parser=argparse.ArgumentParser()
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
scene=bpy.context.scene
if bpy.context.object and bpy.context.object.mode!='OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
puffs=list(bpy.data.collections['V08 ANIMATED STEAM'].objects)
if len(puffs)!=16:
    raise ValueError('Expected the approved V08 sixteen-puff steam animation')
for frame in range(98):
    scene.frame_set(frame)
    for ob in puffs:
        density=ob.data.materials[0].node_tree.nodes['Animated steam density'].outputs[0].default_value
        ob.hide_render=frame==0 or density<=0
        ob.keyframe_insert('hide_render',frame=frame)
scene.render.use_persistent_data=True
scene.cycles.use_denoising=True
scene.render.fps=24
scene.frame_set(0)
args.out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(args.out.resolve()))
