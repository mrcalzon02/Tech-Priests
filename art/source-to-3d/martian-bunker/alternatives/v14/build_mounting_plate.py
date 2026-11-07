"""V14 mounting plate bolts and inset girder bays, visual game-asset detail."""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector
O=Path('art/source-to-3d/martian-bunker/alternatives/v14').resolve();O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O.parent/'v13/six_lobber_corner_chamfers_v13.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];root=bpy.data.objects['TURRET_TRAVERSE'];plate=bpy.data.objects['ROTARY_ADAPTER'];fin=bpy.data.objects['CENTRAL_FIN']
iron=bpy.data.materials['CAST_IRON | existing dark gunmetal tile'];steel=bpy.data.materials['LOADER | grey steel'];inner=bpy.data.materials['CAST_IRON | dark bore interior']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)),[m.name for m in o.data.materials])).encode()).hexdigest()
original={o.name:signature(o) for o in col.objects if o.type=='MESH' and o!=plate};created=[]
def own(o,name,mat):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);o.data.materials.clear();o.data.materials.append(mat);bpy.context.view_layer.update();mw=o.matrix_world.copy();o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted();o.matrix_world=mw;created.append(o);return o
def bevel(o,w):
 m=o.modifiers.new('Small mounting hardware edge finish','BEVEL');m.width=w;m.segments=3;m.harden_normals=True;o.modifiers.new('Mounting hardware normals','WEIGHTED_NORMAL')
def cylinder(name,C,r,depth,mat,vertices=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=C);o=own(bpy.context.object,name,mat);bevel(o,.0015);return o
def mesh(name,vs,fs,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);return own(o,name,mat)
# Actual recesses in the exposed top annulus. The outer rim and solid radial
# webs remain at the original height; a diagonal member sits within each bay.
for m in list(plate.modifiers):
 if m.type in ['BEVEL','WEIGHTED_NORMAL']:plate.modifiers.remove(m)
records=[]
for k in range(8):
 center=math.tau*k/8;lo=center-math.radians(15.5);hi=center+math.radians(15.5);outline=[]
 for i in range(13):
  a=lo+(hi-lo)*i/12;outline.append(Vector((.687*math.cos(a),.687*math.sin(a),0)))
 for i in range(12,-1,-1):
  a=lo+(hi-lo)*i/12;outline.append(Vector((.445*math.cos(a),.445*math.sin(a),0)))
 n=len(outline);vs=[(p.x,p.y,z) for z in [1.781,1.851] for p in outline];fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new('GIRDER_BAY_CUTTER');me.from_pydata(vs,[],fs);me.update();cut=bpy.data.objects.new('GIRDER_BAY_CUTTER',me);S.collection.objects.link(cut)
 bpy.context.view_layer.objects.active=plate;m=plate.modifiers.new('Recessed girder bay %d'%(k+1),'BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=cut;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cut,do_unlink=True)
 # Darker recessed floor makes depth readable without bright trim.
 floorvs=[(p.x,p.y,1.7815) for p in outline];floor=mesh('INSET_GIRDER_BAY_FLOOR_%02d'%(k+1),floorvs,[tuple(range(n))],inner)
 a=Vector((.45*math.cos(lo),.45*math.sin(lo),1.800));b=Vector((.682*math.cos(hi),.682*math.sin(hi),1.800));d=b-a
 bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2);o=bpy.context.object;o.dimensions=(.027,.035,d.length);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);own(o,'INSET_DIAGONAL_GIRDER_%02d'%(k+1),iron);bevel(o,.002)
 records.append({'bay':k+1,'recessed_floor_z':1.781,'original_deck_z':1.82,'diagonal_member_top_below_deck':True})
bevel(plate,.003)
for k in range(16):
 a=math.tau*(k+.5)/16;x=.733*math.cos(a);y=.733*math.sin(a)
 cylinder('MOUNTING_BOLT_SEAT_%02d'%(k+1),(x,y,1.821),.034,.003,inner)
 cylinder('MOUNTING_BOLT_WASHER_%02d'%(k+1),(x,y,1.826),.029,.007,steel)
 cylinder('MOUNTING_BOLT_HEX_HEAD_%02d'%(k+1),(x,y,1.838),.020,.019,iron,6)
bpy.context.view_layer.update()
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
assert len([o for o in created if o.name.startswith('INSET_DIAGONAL_GIRDER_')])==8
assert all(o.parent==root for o in created)
bpy.ops.object.select_all(action='DESELECT')
for o in created+[plate]:o.select_set(True)
bpy.context.view_layer.objects.active=plate;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
report={'revision':'V14 bolted inset girder mounting plate','recessed_girder_bays':8,'inset_diagonal_members':8,'bolt_washer_and_seat_sets':16,'mounting_plate_diameter_and_height_retained':True,'new_mounting_parts_parented_to_traverse_not_elevation':True,'bay_records':records,'all_other_V13_source_geometry_materials_and_transforms_preserved':True,'existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1100'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','24'));cam=S.camera
views=[('oblique',(-4,-6,4.8),(0,.15,3.02),4.05),('rear',(-4,5,4.5),(0,.28,3.02),4.05),('plate_detail',(-3,-4,3.5),(0,0,1.85),1.90),('plate_top',(0,-1,7),(0,0,1.82),1.95)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_bolted_mount_v14.blend'),compress=True)
 S.render.filepath=str(O/('mount_v14_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin;bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_bolted_mount_v14.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_bolted_mount_v14.glb'));assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n;(O/'model_validation.json').write_text(json.dumps(report,indent=2));print('V14_INSET_GIRDERS_AND_EXPORT_PASS')
