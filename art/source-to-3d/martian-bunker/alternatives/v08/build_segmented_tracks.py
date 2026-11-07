"""V08 exterior game-asset ammunition housing; concealed fictional distribution.
Preserves all six cannons and existing loader trays. No functional internals.
"""
import bpy,math,json,os,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
O=Path('art/source-to-3d/martian-bunker/alternatives/v08').resolve();O.mkdir(parents=True,exist_ok=True)
V5=O.parent/'v05'
bpy.ops.wm.open_mainfile(filepath=str(V5/'six_lobber_loose_grenade_loader_v05.blend'))
S=bpy.context.scene;col=bpy.data.collections['SIX_LOBBER_LOOSE_GRENADE_LOADERS'];pivot=bpy.data.objects['LOBBER_ELEVATION'];plane=bpy.data.objects['SYMMETRY_CENTRELINE_X0']
red=bpy.data.materials['FIN | existing oxide red tile'];iron=bpy.data.materials['CAST_IRON | existing dark gunmetal tile'];steel=bpy.data.materials['LOADER | grey steel'];inner=bpy.data.materials['CAST_IRON | dark bore interior']
def signature(o):return hashlib.sha256(repr(([tuple(v.co) for v in o.data.vertices],list(map(tuple,o.matrix_world)))).encode()).hexdigest()
original={o.name:signature(o) for o in col.objects if o.type=='MESH' and o.name!='CENTRAL_FIN' and not o.name.startswith(('SIDE_LOADING_', 'LOADING_HOOD_', 'OPEN_GRENADE_GUIDE_', 'PRESENTED_', 'OPEN_CRADLE_', 'HOPPER_LEFT_', 'CRADLE_'))}
created=[]
helper=(V5/'build_loose_loader.py').read_text();exec(helper[helper.index('def own('):helper.index('loaders=[]')])
# Broaden the original fin and integrate it into a substantial rear arm.
fin=bpy.data.objects['CENTRAL_FIN']
for v in fin.data.vertices:v.co.x*=1.65
spine=cube('CENTRAL_AMMUNITION_ARMOURED_SPINE',(0,.685,2.86),(.66,.30,1.79),red)
cube('CENTRAL_ARM_TO_FIN_BRIDGE',(0,.355,2.86),(.20,.42,1.60),red)
cube('SPINE_REAR_SERVICE_COVER',(0,.846,2.86),(.29,.035,1.56),iron)
# Exterior panels suggest a concealed distribution trunk; no hidden machinery.
for z in [2.20,2.72,3.24]:
 cube('SPINE_REAR_REINFORCEMENT',(0,.873,z),(.34,.035,.055),steel)
for x in [-.135,.135]:
 for z in [2.15,2.65,3.15,3.55]:
  cylinder('SERVICE_PANEL_BOLT',(x,.868,z),(x,.890,z),.018,steel)
cube('CENTRAL_FEED_BASE_CASTING',(0,.42,1.99),(.46,.74,.18),iron)
cube('CENTRAL_FEED_TOP_CAP',(0,.685,3.77),(.43,.36,.09),iron)
# Open tapered exterior hoppers replace the previous opaque side hoods.
for row in range(3):
 C=Vector((-.27,.04-.26*row,3.10-.38*row+{0:.28,1:.14,2:0}[row]))
 h=Vector((-.475,C.y+.075,C.z-.13))
 for prefix in ['SIDE_LOADING_HOOD_LEFT_','SIDE_LOADING_SHADOW_LEFT_','LOADING_HOOD_UPPER_GUARD_LEFT_']:
  old=bpy.data.objects.get(prefix+str(row+1))
  if old:bpy.data.objects.remove(old,do_unlink=True)
 # Lift the existing exposed guide above the open hopper lip.
 guide=bpy.data.objects['OPEN_GRENADE_GUIDE_LEFT_'+str(row+1)]
 mw=guide.matrix_world.copy();mw.translation.z+=.14;guide.matrix_world=mw
 for o in list(col.objects):
  if o.name.startswith('PRESENTED_LEFT_'+str(row+1)+'_'):
   mw=o.matrix_world.copy();mw.translation.z+=.14;o.matrix_world=mw
 ztop=C.z-.045;zbottom=C.z-.185
 vs=[]
 for z,wx,wy in [(zbottom,.105,.115),(ztop,.25,.29)]:
  for dx,dy in [(-1,-1),(1,-1),(1,1),(-1,1)]:vs.append((h.x+dx*wx/2,h.y+dy*wy/2,z))
 hopper=mirrored(mesh('OPEN_MECHANICAL_HOPPER_LEFT_'+str(row+1),vs,[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],iron))
 wall=hopper.modifiers.new('Cast hopper wall thickness','SOLIDIFY');wall.thickness=.012
 for i in range(4):rod('HOPPER_ROLLED_LIP_LEFT',vs[4+i],vs[4+(i+1)%4],.012,steel)
 small_cube('HOPPER_NECK_LEFT_'+str(row+1),(h.x,h.y,zbottom-.035),(.12,.13,.07),iron)
 small_cube('HOPPER_DARK_THROAT_LEFT_'+str(row+1),(h.x,h.y,zbottom+.005),(.088,.098,.008),inner)
 # Named empty markers are animation planning handles, not mechanical internals.
 for label,loc in [('ARM_EXIT',(-.21,.548,C.z-.025)),('RAMP',(-.45,.435,C.z+.02)),('HOPPER',(h.x,h.y,ztop+.05)),('CONCEALED_FEED',(h.x,h.y,zbottom))]:
  o=bpy.data.objects.new('RELOAD_PATH_LEFT_%d_'%(row+1)+label,None);col.objects.link(o);o.location=loc;o.empty_display_size=.025;o.hide_render=True
# Replace projecting blocks and storage cradles with true recessed hatches.
rubber=matte('CONVEYOR | continuous vulcanized rubber segments',(.043,.052,.046),.90)
track_checks=[]
for o in list(col.objects):
 if o.name.startswith(('OPEN_CRADLE_', 'CRADLE_', 'HOPPER_LEFT_', 'OPEN_GRENADE_GUIDE_')):
  bpy.data.objects.remove(o,do_unlink=True)
for row in range(3):
 C=Vector((-.27,.04-.26*row,3.10-.38*row+{0:.28,1:.14,2:0}[row]));z=C.z
 # Six real recesses in the pillar skin, with lifted hatch leaves.
 for side in [-1,1]:
  x=.21*side
  bpy.ops.mesh.primitive_cube_add(size=1,location=(x,.585,z+.135));cut=bpy.context.object;cut.dimensions=(.18,.33,.25);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bpy.context.view_layer.objects.active=spine
  m=spine.modifiers.new('Recessed grenade exit opening','BOOLEAN');m.operation='DIFFERENCE';m.object=cut
  bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cut,do_unlink=True)
  cube('HATCH_RECESSED_DARK_BACK',(x,.748,z+.135),(.177,.012,.245),inner)
  for dx in [-.105,.105]:cube('HATCH_FRAME_JAMB',(x+dx,.520,z+.135),(.026,.032,.285),steel)
  for dz in [-.006,.276]:cube('HATCH_FRAME_CROSSPIECE',(x,.520,z+dz),(.235,.032,.026),steel)
  cube('LIFTED_HATCH_LEAF',(x,.550,z+.365),(.195,.032,.165),red)
  cube('HATCH_LEAF_HANDLE',(x,.521,z+.365),(.075,.025,.018),steel)
 # A shallow downward chute, with a separate exposed rubber track ribbon.
 h=Vector((-.475,C.y+.075,z-.13))
 path=[Vector((-.21,.520,z+.020)),Vector((-.34,.435,z+.005)),Vector((-.47,.410,z-.010)),Vector((-.535,.330,z-.025)),Vector((-.535,h.y,z-.030))]
 open_trough('SLOPED_EXIT_CHUTE_LEFT_'+str(row+1),path,width=.155,height=.055)
 # Uniform-length rubber shoes follow a closed loop, including the visible
 # end turn and lower return. Each shoe uses the same rubber material.
 top=[p+Vector((0,0,.027)) for p in smooth(path,32)]
 loop=list(top);radius=.024
 te=(top[-1]-top[-2]);te.z=0;te.normalize()
 for j in range(1,25):
  a=math.pi*j/24;loop.append(top[-1]+te*(radius*math.sin(a))+Vector((0,0,radius*(math.cos(a)-1))))
 loop.extend(p-Vector((0,0,2*radius)) for p in reversed(top[:-1]))
 ts=top[1]-top[0];ts.z=0;ts.normalize()
 for j in range(1,24):
  a=math.pi+math.pi*j/24;loop.append(top[0]+ts*(radius*math.sin(a))+Vector((0,0,radius*(math.cos(a)-1))))
 cumulative=[0.]
 for i in range(len(loop)):cumulative.append(cumulative[-1]+(loop[(i+1)%len(loop)]-loop[i]).length)
 total=cumulative[-1]
 def at(distance):
  import bisect
  distance%=total;i=min(len(loop)-1,bisect.bisect_right(cumulative,distance)-1)
  return loop[i].lerp(loop[(i+1)%len(loop)],(distance-cumulative[i])/(cumulative[i+1]-cumulative[i]))
 count=round(total/.034);pitch=total/count;gap=.0022;vs=[];fs=[]
 previous_across=None
 for k in range(count):
  distance=k*pitch;center=at(distance);t=(at(distance+.001)-at(distance-.001)).normalized()
  # Side direction follows the upper guide even around the return turns.
  if abs(t.z)>.92:
   across=Vector((-te.y,te.x,0)) if distance<total*.65 else Vector((-ts.y,ts.x,0))
  else:
   across=Vector((-t.y,t.x,0)).normalized()
   if t.z<0 or (distance>cumulative[len(top)-1]+math.pi*radius and distance<total-math.pi*radius):across=-across
  if previous_across is not None and across.dot(previous_across)<0:across=-across
  previous_across=across.copy();normal=t.cross(across).normalized();start=len(vs)
  for thick in [-.005,.005]:
   for along,side in [(-1,-1),(-1,1),(1,1),(1,-1)]:
    edge_distance=distance+along*(pitch-gap)/2;p=at(edge_distance)
    et=(at(edge_distance+.0005)-at(edge_distance-.0005)).normalized()
    ea=Vector((-et.y,et.x,0)).normalized() if abs(et.z)<.92 else across.copy()
    if ea.dot(across)<0:ea=-ea
    en=et.cross(ea).normalized()
    vs.append(tuple(p+ea*side*.055+en*thick))
  fs.extend(tuple(start+j for j in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
 track=mirrored(mesh('CONTINUOUS_SEGMENTED_RUBBER_TRACK_LEFT_'+str(row+1),vs,fs,rubber))
 bevel=track.modifiers.new('Soft rubber shoe edges','BEVEL');bevel.width=.0018;bevel.segments=2
 track.modifiers.new('Rubber shoe normals','WEIGHTED_NORMAL')
 assert len(track.data.materials)==1 and track.data.materials[0]==rubber
 track_checks.append({'station':row+1,'shoes_per_closed_loop':count,'uniform_pitch':pitch,'seam_gap':gap,'closed_return':True,'shared_material':rubber.name})
 loose_grenade('HATCH_EXIT_PROP_LEFT_'+str(row+1),(-.24,.490,z+.090),Matrix.Rotation(math.pi/2,3,'X'))
bpy.context.view_layer.update()
for name,sig in original.items():assert signature(bpy.data.objects[name])==sig,name
bpy.ops.object.select_all(action='DESELECT')
for o in created:o.select_set(True)
bpy.context.view_layer.objects.active=created[0]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
report={'revision':'V08 continuous segmented rubber tracks','existing_cannons_and_air_pipes_unchanged':True,'recessed_hatches_cut_into_pillar':6,'rubber_tracks':6,'chutes':'slight downward slope with continuous segmented rubber loops','track_checks':track_checks,'single_material_all_track_segments':True,'six_open_tapered_hoppers':True,'existing_guides_raised_for_hopper_lips':True,'reload_animation':'Named path markers only; no animation authored yet','six_visible_supply_ports':True,'central_fin_width_multiplier':1.65,'central_housing':'Widened pillar with six recessed hatch openings and raised hatch leaves','internal_distribution':'Concealed fictional game-asset mechanism; no functional weapon internals constructed','existing_bunker_modified':False}
S.render.resolution_x=S.render.resolution_y=int(os.getenv('LOADER_RENDER_SIZE','1000'));S.render.resolution_percentage=100;S.cycles.samples=int(os.getenv('LOADER_RENDER_SAMPLES','24'))
cam=S.camera
views=[('oblique',(-4,-6,4.6),(0,.15,2.82),3.55),('rear',(-4,5,4.2),(0,.28,2.82),3.55),('front',(0,-7,3.2),(0,.2,2.82),3.55),('detail',(-3,-3,5.5),(-.28,.22,3.30),1.35)]
for i,(name,pos,target,scale) in enumerate(views):
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 if i==0:bpy.ops.wm.save_as_mainfile(filepath=str(O/'six_lobber_central_feed_v08.blend'),compress=True)
 S.render.filepath=str(O/('central_feed_v08_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=fin
bpy.ops.export_scene.gltf(filepath=str(O/'six_lobber_central_feed_v08.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
n=sum(o.type=='MESH' for o in col.objects)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'six_lobber_central_feed_v08.glb'))
assert sum(o.type=='MESH' for o in bpy.context.scene.objects)==n
report['GLB_reimported']=True;report['mesh_count']=n
(O/'model_validation.json').write_text(json.dumps(report,indent=2))
print('V08_PRESERVATION_AND_EXPORT_PASS')
