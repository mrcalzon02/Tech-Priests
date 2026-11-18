import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v07-aged-and-ambient';bpy.ops.wm.open_mainfile(filepath=str(O/'conclave-center-v07.blend'));ob=bpy.data.objects['Supplied DGordillo low-poly skull 0'];vs=[ob.matrix_world@v.co for v in ob.data.vertices];tree=BVHTree.FromPolygons(vs,[list(f.vertices) for f in ob.data.polygons]);rows=[]
for z in (1.51,1.55,1.59,1.63,1.67,1.71,1.75,1.79):
 row=[]
 for x in (0,.035,.065,.095,.12):
  p,n,f,d=tree.ray_cast(Vector((x,-1,z)),Vector((0,1,0)));row.append(round(p.y,4) if p else None)
 rows.append([z,row])
print('SKULL_PROBE',json.dumps(dict(bounds=[[min(p[j] for p in vs) for j in range(3)],[max(p[j] for p in vs) for j in range(3)]],front_y_samples=rows)),flush=True)
