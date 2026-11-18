"""Match four authored shaft surfaces to unchanged source48-facet collar bores."""
import bpy,json,hashlib,pathlib,math
from mathutils import Vector
R=pathlib.Path.cwd();S=R/'build/thruster-resume-20261117/thetazine-v06-motion';inp=S/'core07-collar-aligned';out=S/'core08-matched-collar-facets';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=inp/'thetazine-v06-collar-aligned-motion.blend';assert sha(src)=='e1b22e8fc7123d85eeedc379bf3d46eea7a246a7923ee23720ac4405c00717f8'
bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));u=Vector((1,0,0));v=A.cross(u).normalized();N=48;names=[]
for sign in(-1,1):
    origin=Vector((sign*1.15,-.787542462348938,-.37641555070877075))+B*.05
    for name,profile,solid in[(f'Outer actuator body {sign}',[(0,.10625),(.70,.10625),(.70,.069),(0,.069)],False),(f'V06 giant actuator sliding rod {sign}',[(.4,.064),(.88,.064),(.90,.10625),(2,.10625)],True)]:
        o=bpy.data.objects[name];old=o.data
        vs=[origin+A*z+r*(math.cos(i*math.tau/N)*u+math.sin(i*math.tau/N)*v)for z,r in profile for i in range(N)];fs=[];uv=[];rows=len(profile)
        for k in range(rows-1 if solid else rows):
            n=(k+1)%rows
            for i in range(N):
                fs.append((k*N+i,k*N+(i+1)%N,n*N+(i+1)%N,n*N+i));uv.append(((i/N,k/rows),((i+1)/N,k/rows),((i+1)/N,(k+1)/rows),(i/N,(k+1)/rows)))
        if solid:
            for k,reverse in[(0,True),(3,False)]:
                center=len(vs);vs.append(origin+A*profile[k][0])
                for i in range(N):
                    fs.append((center,k*N+(i+1)%N,k*N+i)if reverse else(center,k*N+i,k*N+(i+1)%N));uv.append(((.5,.5),(.5+.45*math.cos((i+1)*math.tau/N),.5+.45*math.sin((i+1)*math.tau/N)),(.5+.45*math.cos(i*math.tau/N),.5+.45*math.sin(i*math.tau/N))))
        me=bpy.data.meshes.new(name+' source-matched48 facets');me.from_pydata(vs,[],fs);me.update();layer=me.uv_layers.new(name='Axial mechanical islands')
        for face,coords in zip(me.polygons,uv):
            for loop,co in zip(face.loop_indices,coords):layer.data[loop].uv=co
            face.use_smooth=len(face.vertices)==4
        for mat in old.materials:me.materials.append(mat)
        o.data=me;names.append(name)
source=out/'thetazine-v06-matched-collar-motion.blend';glb=out/'thetazine-v06-matched-collar-motion.glb';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
for o in s.objects:o.select_set(o.type=='MESH'and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
report={'status':'FOUR_SHAFTS_MATCH_UNCHANGED48FACET_COLLARS_PENDING_INDEPENDENT66_CHECK','input':{'path':str(src),'sha256':sha(src)},'native':{'path':str(source),'sha256':sha(source)},'glb':{'path':str(glb),'sha256':sha(glb)},'changed_meshes_only':names,'angular_sides':48,'angular_u':list(u),'angular_v':list(v),'script_sha256':sha(pathlib.Path(__file__)),'reason':'Match exact unchanged source collar bores; no axis/dimension/action change and no seating tolerance relaxation.'}
for name in('detail-manifest.json','side-actuator-motion.json'):
    j=json.loads((inp/name).read_text());j['native']=report['native'];j['glb']=report['glb'];j['bounded_matched_facet_repair']=report;(out/name).write_text(json.dumps(j,indent=2),encoding='utf-8')
(out/'matched-facet-repair.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('MATCHED_FACET_REPAIR_COMPLETE',json.dumps(report),flush=True)
