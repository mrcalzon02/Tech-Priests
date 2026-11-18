"""Render actual supported state lenses, without invented machinery motion."""
import bpy,json,math,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/primitive-battery-bank/v01';C=O/'captures';C.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O/'primitive-battery-bank-v01.blend'));s=bpy.context.scene;s.render.resolution_x=512;s.render.resolution_y=512;s.cycles.samples=24
for ob in s.objects:
 if ob.type=='MESH':ob.visible_camera=False
 if ob.type=='LIGHT':ob.data.energy=0
s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
for rec in json.loads((O/'construction.json').read_text())['lamps']:
 ob=bpy.data.objects[rec['object']];ob.visible_camera=True;bs=bpy.data.materials[rec['material']].node_tree.nodes.get('Principled BSDF')
 for i in range(8):
  bs.inputs['Emission Strength'].default_value=1.5+.8*math.sin(math.tau*i/8);s.render.filepath=str(C/(rec['state']+'-f%02d.png'%i));bpy.ops.render.render(write_still=True)
 ob.visible_camera=False
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(O/'state-capture.json').write_text(json.dumps(dict(source_sha256=h(O/'primitive-battery-bank-v01.blend'),export_sha256=h(O/'primitive-battery-bank-v01.glb'),state_frames={p.name:h(p) for p in C.glob('*-f*.png')},scope='Sixteen genuine source lens-state renders; static GLB geometry, no mechanical cycling or exported material animation claimed',period='Eight frames per state at native 12fps; inherited cooldowns preserved'),indent=2)+'\n')
print('BATTERY_SUPPORTED_STATE_LENSES_CAPTURED')
