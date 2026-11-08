"""Raise the condenser housing around its fixed-height pipe connection."""
import bpy,bmesh,json,math,hashlib,struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'condenser_v20';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'condenser_v19/tech_priests_water_condenser_v19.blend'))
s=bpy.context.scene;lift=.38
def signature(o):
 return hashlib.sha256(b''.join(struct.pack('3f',*(o.matrix_world@v.co)) for v in o.data.vertices)).hexdigest()
fixed=[o for o in s.objects if o.type=='MESH' and (o.name.startswith(('Water outlet','Reference pipe')))]
fixed_before={o.name:signature(o) for o in fixed}
structural={'Condenser continuous central chassis','Condenser left continuous side cheek','Condenser right continuous side cheek','Condenser left fitted retaining strap','Condenser right fitted retaining strap','V17 raised rear-left outer channel rail','V10 upper left clip foundation foot'}
unchanged_prefix=('Condenser foundation','Condenser shallow tapered foundation','Condenser left anchor','Condenser lower exposed rail','Condenser front recessed floor','V06 right anchor','V06 right plate-level anchor','V17 rear-left channel dark floor')
raised=[];extended=[];base=[]
for o in list(s.objects):
 if o.type!='MESH' or o.parent is None or o.parent.name!='CONDENSER_TILE_CALIBRATION':continue
 if o.name.startswith(unchanged_prefix):base.append(o.name);continue
 inv=o.matrix_world.inverted()
 if o.name in structural:
  pts=[o.matrix_world@v.co for v in o.data.vertices];lo=min(p.z for p in pts);hi=max(p.z for p in pts)
  newlo=.06 if o.name in {'Condenser continuous central chassis','Condenser right continuous side cheek'} else lo
  for v,p in zip(o.data.vertices,pts):p.z=newlo+(p.z-lo)/(hi-lo)*(hi+lift-newlo);v.co=inv@p
  o.data.update();extended.append(o.name)
 else:
  m=o.matrix_world.copy();m.translation.z+=lift;o.matrix_world=m;raised.append(o.name)
# Bore a real socket through the raised sidewall, coaxial with the fixed pipe.
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=.287,depth=.76,location=(.78,-.5,.36),rotation=(0,math.pi/2,0))
cutter=bpy.context.object;cutter.name='Temporary coaxial side socket cutter'
bored=[]
for name in ['Condenser continuous central chassis','Condenser right continuous side cheek']:
 o=bpy.data.objects[name];bpy.context.view_layer.objects.active=o
 m=o.modifiers.new('Water outlet machined side bore','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=cutter
 bpy.ops.object.modifier_apply(modifier=m.name);bored.append(name)
bpy.data.objects.remove(cutter,do_unlink=True)
# Remove the stray grid seam outside the ground reference plane.
o=bpy.data.objects.get('Grid Y 2')
if o:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.update()
assert all(signature(bpy.data.objects[n])==h for n,h in fixed_before.items())
body=bpy.data.objects['Condenser continuous central chassis'];pts=[body.matrix_world@v.co for v in body.data.vertices]
top=max(v.z for v in pts);clearance=top-(.36+.34)
assert clearance>.05
integrity=[]
for name in bored:
 o=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free();integrity.append({'mesh':name,'nonmanifold_edges':bad});assert bad==0
# A ray down the pipe axis must reach the machined bore floor, not an uncut sidewall.
hits=[]
for name in bored:
 o=bpy.data.objects[name];inv=o.matrix_world.inverted();origin=inv@Vector((1.1,-.5,.36));direction=(inv.to_3x3()@Vector((-1,0,0))).normalized();hit,loc,n,idx=o.ray_cast(origin,direction)
 world=o.matrix_world@loc if hit else None
 hits.append({'mesh':name,'hit':hit,'world_hit':list(world) if hit else None})
 assert not hit or world.x<.42
report={'revision':'V20','upper_assembly_lift_tiles':lift,'housing_roof_z':top,'outlet_flange_top_z':.7,'roof_clearance_above_flange':clearance,'outlet_mouth_blender':[1,-.5,.36],'pipe_and_reference_world_geometry_unchanged':True,'fixed_geometry_hashes':fixed_before,'raised_without_shape_change':raised,'extended_structural_parts':extended,'base_hardware_preserved':base,'machined_bore_radius':.287,'bored_sidewalls':integrity,'axial_bore_rays':hits,'footprint_tiles':[2,2],'runtime_validation':'Not performed; this is a Blender geometry revision.'}
(D/'Condenser_V20_Validation.json').write_text(json.dumps(report,indent=2))
s['asset_revision']='V20 raised housing and upper assembly with bored side outlet';s.camera=bpy.data.objects['PIPE_FIT_OBLIQUE'];s.cycles.samples=24
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_water_condenser_v20.blend'),compress=True)
for o in s.objects:o.select_set(False)
for o in s.objects:
 if o.type=='MESH' and (o.parent and o.parent.name=='CONDENSER_TILE_CALIBRATION' or o.name.startswith('Water outlet')):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v20.glb'),export_format='GLB',use_selection=True,export_apply=True)
for camera,label in [('PIPE_FIT_OBLIQUE','Oblique'),('PIPE_FIT_GAME_CAMERA_45_DEGREES','Game_View'),('PIPE_FIT_FRONT_HEIGHT','Height')]:
 s.camera=bpy.data.objects[camera];s.render.filepath=str(D/('Condenser_V20_'+label+'.png'));bpy.ops.render.render(write_still=True)
print('V20_COMPLETE',top,clearance,flush=True)
