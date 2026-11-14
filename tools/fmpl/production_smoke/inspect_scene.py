"""Read-only scene census for source recovery; run with Blender --python."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

source, output = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.open_mainfile(filepath=str(Path(source).resolve()))
scene = bpy.context.scene
rows = []
for ob in scene.objects:
    if ob.type not in {'MESH', 'CURVE', 'EMPTY', 'CAMERA'}:
        continue
    row = dict(name=ob.name, type=ob.type, hidden=ob.hide_render,
               location=list(ob.matrix_world.translation), dimensions=list(ob.dimensions),
               materials=[m.name if m else None for m in getattr(ob.data, 'materials', [])],
               properties={k:str(v) for k,v in ob.items()})
    if ob.type == 'MESH':
        corners = [ob.matrix_world @ Vector(v) for v in ob.bound_box]
        row['bounds'] = [[min(v[i] for v in corners) for i in range(3)],
                         [max(v[i] for v in corners) for i in range(3)]]
        if len(ob.data.vertices) == 128 and ' / section ' in ob.name:
            rings=[sum((ob.matrix_world @ v.co for v in list(ob.data.vertices)[k:k+32]),Vector())/32 for k in (0,32)]
            row['line_ends']=[list(v) for v in rings]
            row['radius']=(ob.matrix_world @ ob.data.vertices[0].co-rings[0]).length
    if ob.type == 'CURVE':
        row['splines'] = [[list(ob.matrix_world @ p.co.xyz) for p in s.points]
                          for s in ob.data.splines]
    rows.append(row)
Path(output).write_text(json.dumps(dict(source=source, objects=rows,
    timeline_fps=scene.render.fps/scene.render.fps_base,
    camera=scene.camera.name if scene.camera else None,
    images=[dict(name=i.name,packed=bool(i.packed_file),size=list(i.size)) for i in bpy.data.images],
    actions=[a.name for a in bpy.data.actions]),indent=2))
print('SCENE_CENSUS', len(rows))
