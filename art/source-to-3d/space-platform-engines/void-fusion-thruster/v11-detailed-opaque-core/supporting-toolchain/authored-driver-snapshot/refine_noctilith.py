"""Owner-directed exposed noctilith cage and nonchemical field projector."""
import bpy,math,json,pathlib,sys,hashlib,random,shutil
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3]
OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v03'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v04.blend').exists()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v03.blend'))
S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
contract=json.loads((OLD/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
removed=[]
for o in list(S.objects):
    if o.name.startswith(('Sealed longitudinal reaction','V02 casing','V02 mount')) and ('concave saddle' in o.name or o.name.startswith(('Sealed longitudinal reaction','V02 casing'))):
        removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
    elif o.name.startswith(('Hollow magnetic','Aft ','Fore bulkhead','Fore sealed','Fore shroud','Fore guard','Crown continuous','Band longitudinal keeper','Transverse retained vessel hoop')):
        removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
contacts=[c for c in contract['contacts'] if c['a'] not in removed and c['b'] not in removed]
surface=[c for c in contract['surface_contacts'] if c['a'] not in removed and c['b'] not in removed]
mats={k:bpy.data.materials[n] for k,n in [('hull','Spine blackened cast iron'),('bands','Worn bronze retaining bands'),('rail','Satin iron load rails'),('ceramic','Glazed olive insulator')]}
def simplemat(name,color,metal,rough,emission=None,strength=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    if emission:bs.inputs['Emission Color'].default_value=(*emission,1);bs.inputs['Emission Strength'].default_value=strength
    return m
mats['green']=simplemat('Noctilith energized fracture Necron green',(.015,.25,.001),.12,.29,(.06,1,.001),7)
mats['rock']=simplemat('Noctilith faceted black mineral',(.008,.012,.009),.13,.45)
# Coherent mineral atlas, not the metal panel-stripe texture of the old vessel.
for kind in ('basecolor','metalrough'):
    image=bpy.data.images.new('Noctilith mineral '+kind,width=128,height=128,alpha=True);pixels=[]
    for v in range(128):
        for u in range(128):
            noise=.5+.22*math.sin(u*.17+math.sin(v*.11)*2)+.18*math.sin(v*.23+u*.07)
            color=(.006+noise*.010,.009+noise*.013,.007+noise*.008) if kind=='basecolor' else (1,.36+noise*.19,.13)
            pixels.extend((*color,1))
    image.pixels.foreach_set(pixels);image.filepath_raw=str(OUT/('noctilith-'+kind+'.png'));image.file_format='PNG';image.save();image.pack()
    nt=mats['rock'].node_tree;bs=nt.nodes.get('Principled BSDF');t=nt.nodes.new('ShaderNodeTexImage');t.image=image
    if kind=='basecolor':nt.links.new(t.outputs[0],bs.inputs['Base Color'])
    else:
        image.colorspace_settings.name='Non-Color';sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(t.outputs[0],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
def finish(o,name,mat):
    o.name=name;o.data.materials.clear();o.data.materials.append(mats[mat]);return o
def box(name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat)
def cyl(name,pos,r,h,mat,axis='Y',vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=pos);o=bpy.context.object
    if axis=='Y':o.rotation_euler.x=math.pi/2
    return finish(o,name,mat)
def rod(name,a,b,r,mat):
    d=Vector(b)-Vector(a);o=cyl(name,(Vector(a)+Vector(b))/2,r,d.length,mat,axis='Z',vertices=12);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def ring(name,pos,r,tube,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=pos,major_radius=r,minor_radius=tube);o=bpy.context.object;o.rotation_euler.x=math.pi/2;return finish(o,name,mat)
def mesh(name,v,f,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(mats[mat]);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');return o
def bvh(o):
    bpy.context.view_layer.update();m=o.data;m.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
rocks=[];ROCKS=[]
for index,(y,half) in enumerate(((-3.12,.47),(-2.05,.49),(-.90,.48),(.19,.56),(1.60,.59),(2.69,.45),(3.55,.37))):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    o=bpy.context.object;o.name='V04 retained noctilith blackrock %02d'%index
    rng=random.Random(901+index)
    for v in o.data.vertices:
        s=.86+rng.random()*.23;v.co=(v.co.x*.26*s,v.co.y*half*s,v.co.z*.27*s)
    o.location=(0,y,.54);o.data.materials.append(mats['rock']);rocks.append(o)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.update();o.data.calc_loop_triangles()
    # Luminous fracture seams follow selected actual faceted rock edges.
    for j,e in enumerate(o.data.edges):
        if (j+index*3)%8 not in (0,1):continue
        aa,bb=[o.matrix_world@o.data.vertices[k].co for k in e.vertices]
        outward=((aa+bb)/2-o.location).normalized()*.003
        rod('V04 rock%02d green fracture%03d'%(index,j),aa+outward,bb+outward,.006,'green')
    ROCKS.append({'object':o.name,'center_y':y,'irregular_faceted_original_mesh':True,'half_length_design':half})
    # Two substantial open cage binding rings, not a continuous pressure skin.
    for side in (-1,1):
        yy=y+side*half*.72
        ring('V04 rock%02d open octet retaining ring %s'%(index,side),(0,yy,.54),.325,.026,'rail')
        for x in (-.27,.27):
            tie=rod('V04 rock%02d retaining tie %s %s'%(index,side,x),(x,yy,.18),(x,yy,.73),.024,'bands')
            keel='Continuous structural keel '+str(-1 if x<0 else 1)
            surface.append({'a':tie.name,'b':keel,'point':[x,yy,.18],'normal':[0,0,1],'tolerance':2e-5,'reason':'Actual retaining-tie lower cap seats on keel crown; repaired .02 gap seen in first V04 export support detail'})
        # Retained wedge grips at each axial ring, visibly clamping the stone.
        for x in (-.22,.22):box('V04 rock%02d gripping jaw %s %s'%(index,side,x),(x,yy,.53),(.105,.105,.20),'hull')

# Continuous thick upper cage rails and triangular end braces retain the bays.
for side in (-1,1):
    box('V04 cage longitudinal crown rail '+str(side),(side*.19,.05,.855),(.055,7.72,.065),'rail')
    for y in (-3.65,3.85):rod('V04 cage end brace %s %s'%(side,y),(side*.30,y,.18),(side*.19,y,.855),.032,'bands')
    # Two relic backplates are supported by real transverse top crossheads.
    for i,y in enumerate((contract['embedded_reliefs'][j]['support_plane_point'][1] for j in range(2))):
        box('V04 relic %02d crown crosshead %s'%(i,side),(side*.12,y,.797),(.22,.14,.055),'hull')

# Replace chemical-style bell completely: three identical separated field rings,
# four insulated standoffs, segmented electrode tiles and extraction-grid spokes.
for i,y in enumerate((-3.79,-4.08,-4.37)):
    ring('V04 field projector constant bore ring%02d'%i,(0,y,.51),.36,.025,'bands')
    if i!=1:ring('V04 field projector green inner aperture%02d'%i,(0,y,.51),.316,.011,'green')
    for a in range(0,360,45):
        angle=math.radians(a);x=.323*math.cos(angle);z=.51+.323*math.sin(angle)
        tile=box('V04 field stage%02d segmented emitter %03d'%(i,a),(x,y,z),(.055,.055,.085),'hull');tile.rotation_euler.y=angle
for i,a in enumerate((45,135,225,315)):
    angle=math.radians(a);x=.36*math.cos(angle);z=.51+.36*math.sin(angle)
    cyl('V04 projector retained standoff %02d'%i,(x,-4.02,z),.024,.78,'rail')
    for yy in (-3.81,-4.10,-4.31):cyl('V04 projector ceramic isolation %02d %s'%(i,yy),(x,yy,z),.037,.09,'ceramic')
for side in (-1,1):
    rod('V04 projector load brace '+str(side),(side*.30,-3.88,.18),(side*.255,-3.88,.765),.028,'rail')
    box('V04 projector grounded brace shoe '+str(side),(side*.30,-3.88,.20),(.10,.15,.07),'bands')
for a in range(0,180,30):
    th=math.radians(a);r=.28
    rod('V04 extraction grid electrode %03d'%a,(-r*math.cos(th),-4.355,.51-r*math.sin(th)),(r*math.cos(th),-4.355,.51+r*math.sin(th)),.006,'rail')
cyl('V04 extraction focal Necron green aperture',(0,-4.36,.51),.075,.018,'green',vertices=24)

# Keep current electrical induction units, but source working green is now real
# material emission from energized insulating cores and noctilith fractures.
for o in S.objects:
    if o.name.startswith('Insulator '):o.data.materials.clear();o.data.materials.append(mats['green'])

# Rock-fitted actual lower contact saddles. Ray samples target the actual current
# retained rock nearest each native mounting station, not the removed vessel.
for i,y in enumerate((4.31-(py-35)/511*8.70 for py in (130,194,277,341,470))):
    rock=min(rocks,key=lambda o:abs(o.location.y-y));tr=bvh(rock)
    xs=[-.16+j*.32/12 for j in range(13)];top=[]
    for x in xs:
        hit=tr.ray_cast(Vector((x,y,-.1)),Vector((0,0,1)),2)[0]
        assert hit is not None,('rock seat missing actual material',i,x,y,rock.name)
        top.append(hit.z)
    n=len(xs);verts=[]
    for yy in (y-.065,y+.065):
        for is_top in (False,True):verts.extend([(x,yy,top[j] if is_top else .21) for j,x in enumerate(xs)])
    faces=[]
    for j in range(n-1):faces.extend([(j,j+1,n+j+1,n+j),(2*n+j,3*n+j,3*n+j+1,2*n+j+1),(j,2*n+j,2*n+j+1,j+1),(n+j,n+j+1,3*n+j+1,3*n+j)])
    faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
    saddle=mesh('V04 mount %02d actual noctilith-fitted saddle'%i,verts,faces,'hull')
    # Narrow saddle is tied to each existing ear through a solid lateral bridge.
    for side in (-1,1):
        bridge=box('V04 mount %02d lateral saddle bridge %s'%(i,side),(side*.195,y,.23),(.12,.13,.04),'rail')
        ear=bpy.data.objects['V02 mount %02d bearer ear %s'%(i,side)]
        surface.append({'a':bridge.name,'b':ear.name,'point':[side*.225,y,.21],'normal':[0,0,1],'tolerance':2e-5,'reason':'Actual lower bridge plane seats on retained bearer ear'})
        surface.append({'a':bridge.name,'b':saddle.name,'point':[side*.15,y,.23],'normal':[1,0,0],'tolerance':.01501,'reason':'Purposeful lateral bridge insertion through saddle side by .015; bounded embed, not a zero-seat claim'})
    for j in (0,3,6,9,12):surface.append({'a':saddle.name,'b':rock.name,'point':[xs[j],y,top[j]],'normal':[0,0,1],'tolerance':2e-5,'reason':'Actual retained noctilith lower triangle and ray-fitted saddle crown'})

S['candidate_stage']='V04_EXPOSED_ELECTRIFIED_NOCTILITH_CAGE_AND_OPEN_FIELD_PROJECTOR_CANDIDATE'
S['owner_design']='Electrified noctilith rocks mechanically stabilized in cages; Necron green energy, megawatt input; exotic spatial ionic trails/time-space disruption, not chemical thrust.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v04.blend';glb=OUT/'void-fusion-v04.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
contract.update({'revision':'V04 owner exposed noctilith and field-projector design correction','blend_sha256':sha(blend),'glb_sha256':sha(glb),'contacts':contacts,'surface_contacts':surface,'rock_bays':ROCKS,'design_authority':{'owner_exact_concept':'Electrified NOCTILITH ROCKS crammed into mechanically stabilized CAGES; megawatts dumped in; quintessential NECRON GREEN glow; spatial ionic trails and space-time distortion moving the ship.','projector':'Exotic field projector between modern xenon thruster and raw electromagnetic space-time disruption/exotic particle emitter. No chemical flared bell: separated constant-bore field stages, insulated standoffs, extraction grid and energized aperture.','glb_working_appearance':'Actual emissive materials on real fracture geometry, induction cores and ring/aperture geometry. No distortion or trail simulation is claimed by GLB material emission.','future_runtime_gates':['Variable-operation green/cold/working layers','Spatial ionic trails and time-space distortion authoring','Fixed-north sprite projection and native final art integration','Real native field-FX appearance and gameplay validation']}})
(OUT/'source-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
for n in ('reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt'):shutil.copy2(OLD/n,OUT/n)
print('NOCTILITH_CAGE_SAVED',len(rocks),len(surface),blend)
