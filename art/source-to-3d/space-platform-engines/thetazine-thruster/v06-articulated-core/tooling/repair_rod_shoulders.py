"""Bounded two-new-rod repair: seat existing aft collars on rigid shaft shoulders."""
import bpy,json,hashlib,math,pathlib
from mathutils import Vector
R=pathlib.Path.cwd();stage=R/'build/thruster-resume-20261117/thetazine-v06-motion'
inp=stage/'core05-fixedbrackets';out=stage/'core06-seated-rods';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=inp/'thetazine-v06-static-bracket-pilot.blend';assert sha(src)=='a618053162f0ff3bf1db7ee4a8c14014c196c8980af17c20ca653c3ec0aed464'
bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));u=Vector((1,0,0));v=A.cross(u).normalized()
profile=[(.40,.064),(.88,.064),(.90,.10625),(2.0,.10625)]
changed=[]
for sign in (-1,1):
    o=bpy.data.objects[f'V06 giant actuator sliding rod {sign}'];old=o.data;N=64;origin=Vector((sign*1.15,-.787542462348938,-.37641555070877075))
    vs=[origin+A*z+r*(math.cos(i*math.tau/N)*u+math.sin(i*math.tau/N)*v)for z,r in profile for i in range(N)]
    fs=[];uv=[]
    for k in range(len(profile)-1):
        for i in range(N):
            fs.append((k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i))
            uv.append(((i/N,k/3),((i+1)/N,k/3),((i+1)/N,(k+1)/3),(i/N,(k+1)/3)))
    for k,reverse in [(0,True),(3,False)]:
        center=len(vs);vs.append(origin+A*profile[k][0])
        for i in range(N):
            ids=(center,k*N+(i+1)%N,k*N+i)if reverse else(center,k*N+i,k*N+(i+1)%N)
            fs.append(ids);uv.append(((.5,.5),(.5+.45*math.cos((i+1)*math.tau/N),.5+.45*math.sin((i+1)*math.tau/N)),(.5+.45*math.cos(i*math.tau/N),.5+.45*math.sin(i*math.tau/N))))
    me=bpy.data.meshes.new(o.name+' seated stepped shaft');me.from_pydata(vs,[],fs);me.update()
    layer=me.uv_layers.new(name='Axial mechanical islands')
    for face,coords in zip(me.polygons,uv):
        for loop,co in zip(face.loop_indices,coords):layer.data[loop].uv=co
        face.use_smooth=len(face.vertices)==4
    for material in old.materials:me.materials.append(material)
    o.data=me;o['V06_role']='Rigid stepped inner shaft: .064 radius through fore barrel; .10625 aft radius seats original collar bores.'
    changed.append(o.name)
source=out/'thetazine-v06-seated-rod-motion.blend';glb=out/'thetazine-v06-seated-rod-motion.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
for o in s.objects:o.select_set(o.type=='MESH'and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,
 export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,
 export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
repair={'status':'TWO_NEW_ROD_SHOULDERS_SEATED_PENDING_INDEPENDENT_EXPORT_CHECK','input':{'path':str(src),'sha256':sha(src)},'script_sha256':sha(pathlib.Path(__file__)),'changed_new_meshes_only':changed,'profile_axial_distance_radius':[list(p)for p in profile],'barrel_end_axial':.70,'collar_centers_axial':[1.0625,1.875],'original_collar_bore_radius':.10625,'fore_barrel_bore_radius':.069,'fore_rod_radius':.064,'native':{'path':str(source),'sha256':sha(source)},'glb':{'path':str(glb),'sha256':sha(glb)}}
oldmotion=json.loads((stage/'core-04e-side-actuators/side-actuator-motion.json').read_text());oldmotion['native']=repair['native'];oldmotion['glb']=repair['glb'];oldmotion['bounded_rod_seat_repair']=repair
(out/'side-actuator-motion.json').write_text(json.dumps(oldmotion,indent=2),encoding='utf-8')
details=json.loads((inp/'detail-manifest.json').read_text());details['native']=repair['native'];details['glb']=repair['glb'];details['bounded_rod_seat_repair']=repair
(out/'detail-manifest.json').write_text(json.dumps(details,indent=2),encoding='utf-8')
(out/'rod-shoulder-repair.json').write_text(json.dumps(repair,indent=2),encoding='utf-8')
print('SEATED_ROD_REPAIR_COMPLETE',json.dumps(repair),flush=True)
