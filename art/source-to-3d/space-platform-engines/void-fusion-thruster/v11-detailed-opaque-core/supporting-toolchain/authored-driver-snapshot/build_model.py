"""Independent narrow sealed Void Fusion construction pilot, Blender 5.

Run blender --background --threads 2 --python-exit-code 12 --python THIS -- OUT.
No runtime prototype, source reference or other asset is modified.
"""
import bpy, math, sys, pathlib, json, hashlib
from mathutils import Vector

OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v01.blend').exists(), 'Use a fresh output directory.'
ROOT=pathlib.Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
S=bpy.context.scene
S.render.engine='CYCLES'; S.cycles.samples=24; S.cycles.use_denoising=True
S.render.threads_mode='FIXED'; S.render.threads=2
S.render.resolution_x=760; S.render.resolution_y=1100; S.render.resolution_percentage=100
S.render.image_settings.file_format='PNG'; S.render.film_transparent=False
S.world=bpy.data.worlds.new('Neutral dark workshop'); S.world.use_nodes=True
S.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.15,1)
S.world.node_tree.nodes['Background'].inputs[1].default_value=.5
S.view_settings.view_transform='AgX'
TEXTURES=OUT/'textures'; TEXTURES.mkdir(exist_ok=True)

def write_json(name,value):
    (OUT/name).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def material(name,color,metal=.7,rough=.46,region='plate'):
    """Each region has its own image maps, UV orientation and construction marks."""
    maps={}; n=128
    for kind in ('basecolor','metalrough','normal'):
        im=bpy.data.images.new(name+'-'+kind,width=n,height=n,alpha=True)
        pixels=[]
        for v in range(n):
            for u in range(n):
                wear=.018*math.sin(u*.37+v*.12)+.013*math.sin(v*.71-u*.19)
                # Long axial grain on conductors; broad casting variation on hull.
                if region=='conductor': wear+=.035*math.sin(u*.88)
                if region=='ceramic': wear=.008*math.sin(u*.13+v*.09)
                seam=(u%64<2 or v%64<2) if region=='plate' else False
                if kind=='basecolor': c=[max(.005,min(1,x*(.60 if seam else 1)+wear)) for x in color]
                elif kind=='metalrough': c=[1,max(.1,min(1,rough+wear*2)),metal]
                else: c=[.5+.014*math.sin(u*.8) if region=='conductor' else .5,.5,1]
                pixels.extend(c+[1])
        im.pixels.foreach_set(pixels); im.filepath_raw=str(TEXTURES/(name+'-'+kind+'.png')); im.file_format='PNG'; im.save(); im.pack()
        if kind!='basecolor': im.colorspace_settings.name='Non-Color'
        maps[kind]=im
    m=bpy.data.materials.new(name);m.use_nodes=True
    nt=m.node_tree; bs=nt.nodes.get('Principled BSDF')
    for kind,im in maps.items():
        t=nt.nodes.new('ShaderNodeTexImage');t.image=im;t.label=name+' authored '+kind
        if kind=='basecolor':nt.links.new(t.outputs['Color'],bs.inputs['Base Color'])
        elif kind=='normal':
            nn=nt.nodes.new('ShaderNodeNormalMap');nn.inputs['Strength'].default_value=.35
            nt.links.new(t.outputs['Color'],nn.inputs['Color']);nt.links.new(nn.outputs['Normal'],bs.inputs['Normal'])
        else:
            sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(t.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    return m

M={
 'hull':material('Spine blackened cast iron',(.065,.071,.062),.72,.53),
 'bands':material('Worn bronze retaining bands',(.30,.23,.12),.8,.43,'conductor'),
 'rail':material('Satin iron load rails',(.14,.15,.14),.82,.4,'conductor'),
 'copper':material('Enclosed copper induction winding',(.32,.18,.075),.88,.35,'conductor'),
 'ceramic':material('Glazed olive insulator',(.19,.24,.10),.08,.25,'ceramic'),
 'dark':material('Refractory nozzle interior',(.018,.025,.024),.25,.71,'ceramic'),
}
CONTACTS=[]
def finish(o,name,mat,bevel=0):
    o.name=name; o.data.materials.append(M[mat])
    if bevel:
        mod=o.modifiers.new('Machined edge radius','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    if not o.data.uv_layers:
        bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return o
def box(name,center,size,mat,bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,bevel)
def cyl(name,center,radius,length,mat,axis='Y',verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=length,location=center)
    o=bpy.context.object
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    if axis=='X':o.rotation_euler[1]=math.pi/2
    return finish(o,name,mat)
def ring(name,center,radius,tube,mat,axis='Y'):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=center,major_radius=radius,minor_radius=tube)
    o=bpy.context.object
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    if axis=='X':o.rotation_euler[1]=math.pi/2
    return finish(o,name,mat)
def rod(name,a,b,r,mat):
    d=Vector(b)-Vector(a);o=cyl(name,(Vector(a)+Vector(b))/2,r,d.length,mat,axis='Z',verts=16)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def seat(a,b,scope):CONTACTS.append({'a':a.name,'b':b.name,'scope':scope})
def empty(name,pos):
    o=bpy.data.objects.new(name,None);S.collection.objects.link(o);o.location=pos;o.empty_display_size=.1;return o

# Floor-space is native 1x9; +Y fore, -Y aft, Z up. No external sockets.
rails=[]
for side in (-1,1):rails.append(box('Continuous structural keel '+str(side),(side*.30,0,.12),(.10,8.5,.15),'rail'))
core=cyl('Sealed longitudinal reaction vessel',(0,0,.51),.285,7.60,'hull',verts=48)
for i,y in enumerate((-3.85,-2.25,0,2.25,3.85)):
    foot=box('Mount %02d sole'%i,(0,y,.045),(.86,.28,.09),'rail')
    saddle=box('Mount %02d riser'%i,(0,y,.145),(.64,.20,.16),'hull')
    seat(foot,saddle,'Sole and riser seat')
    for r in rails:seat(foot,r,'Keel captured by sole')
    for x in (-.37,.37):
        bolt=cyl('Mount %02d captive bolt %s'%(i,x),(x,y,.099),.033,.025,'bands',axis='Z',verts=6);seat(bolt,foot,'Bolt lower face seats on sole')
    empty('mount_'+str(i),(0,y,0))

# Two sealed axial side conductors with six insulated induction coil stations.
for side in (-1,1):
    x=side*.345
    side_rail=cyl('Sealed side conductor '+str(side),(x,0,.55),.038,7.1,'rail',verts=16)
    for i,y in enumerate((-3.0,-1.85,-.68,.68,1.85,3.0)):
        barrel=cyl('Insulator %s %02d'%(side,i),(x,y,.55),.071,.30,'ceramic',verts=24)
        for j in range(6):ring('Winding %s %02d turn%02d'%(side,i,j),(x,y-.12+j*.048,.55),.075,.012,'copper')
        for yy in (y-.19,y+.19):
            band=cyl('Coil collar %s %02d %s'%(side,i,yy),(x,yy,.55),.079,.065,'bands',verts=24)
            arm=box('Coil support %s %02d %s'%(side,i,yy),(side*.30,yy,.35),(.13,.075,.36),'hull');seat(band,arm,'Collar lower quadrant supported by upright');seat(arm,rails[0 if side<0 else 1],'Upright intersects continuous keel')

# Alternating cladding chambers and repeated cast rings follow the reference spine.
for i,y in enumerate((-3.45,-2.72,-1.37,0,1.37,2.72,3.45)):
    hoop=ring('Transverse retained vessel hoop %02d'%i,(0,y,.51),.292,.034,'bands')
    for a in (35,85,135,215,265,315):
        angle=math.radians(a);x=.304*math.sin(angle);z=.51+.304*math.cos(angle)
        # Radial stud passes through the hoop; retention is geometric, not floating.
        rod('Hoop %02d radial keeper %03d'%(i,a),(x*.94,y,.51+(z-.51)*.94),(x*1.05,y,.51+(z-.51)*1.05),.018,'rail')
    if abs(y)<3:
        for side in (-1,1):
            tab=box('Band longitudinal keeper %02d %s'%(i,side),(side*.14,y,.786),(.065,.14,.055),'bands');seat(tab,core,'Keeper base embedded in pressure-shell crown')

# Long top straps create the thin cage of the source without a copied flat decal.
for side in (-1,1):
    x=side*.13
    box('Crown continuous bronze rib '+str(side),(x,0,.775),(.038,6.98,.055),'bands')
    for y in (-2.05,-.72,.72,2.05):
        for yy in (y-.19,y+.19):
            box('Crown armored slat %s %s'%(side,yy),(side*.17,yy,.796),(.16,.11,.06),'hull')
        strip=box('Crown bronze inspection lid %s %s'%(side,y),(side*.17,y,.827),(.13,.23,.015),'bands',.003)
        for yy in (y-.07,y+.07):cyl('Lid rivet %s %s'%(side,yy),(side*.17,yy,.843),.012,.020,'rail',axis='Z',verts=8)

# Sealed fore crown and an actual hollow concentric magnetic exhaust collar aft.
cyl('Fore bulkhead',(0,3.81,.51),.288,.16,'bands',verts=48)
cyl('Fore sealed domed shroud',(0,4.05,.51),.275,.36,'hull',verts=48)
ring('Fore shroud seam',(0,3.94,.51),.278,.026,'bands')
cyl('Fore sealed end plate',(0,4.26,.51),.225,.10,'bands',verts=48)
for side in (-1,1):
    box('Fore guard '+str(side),(side*.19,3.92,.74),(.07,.72,.07),'bands')

def hollow_profile(name,profile,mat):
    # Closed cross section: outside flare, annular lip, inner wall, return seat.
    verts=[];n=48
    for y,r in profile:
        for i in range(n):
            a=2*math.pi*i/n;verts.append((r*math.cos(a),y,.51+r*math.sin(a)))
    faces=[]
    for j in range(len(profile)):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    return finish(o,name,mat)
nozzle=hollow_profile('Hollow magnetic exhaust throat',[(-3.62,.28),(-3.88,.34),(-4.20,.40),(-4.39,.41),(-4.39,.34),(-4.15,.32),(-3.88,.25),(-3.62,.21)],'dark')
for i,(y,r) in enumerate(((-3.72,.30),(-3.91,.355),(-4.12,.395),(-4.34,.415))):
    ring('Aft concentric pole band %02d'%i,(0,y,.51),r,.024,'bands')
    for a in range(0,360,60):
        th=math.radians(a);rod('Aft pole tie %02d %03d'%(i,a),((r-.025)*math.cos(th),y,.51+(r-.025)*math.sin(th)),((r+.025)*math.cos(th),y,.51+(r+.025)*math.sin(th)),.021,'rail')
for side in (-1,1):box('Aft rectangular guard '+str(side),(side*.31,-3.77,.67),(.09,.45,.16),'hull')

# Source suggests two cast circular reliquary motifs. These are mechanical dial
# studies; their skull/glyph iconography is deliberately not called a replica.
for i,y in enumerate((-2.95,3.12)):
    dial=cyl('Reliquary dial foundation '+str(i),(0,y,.806),.145,.12,'hull',axis='Z')
    ring('Reliquary brass bezel '+str(i),(0,y,.879),.126,.016,'bands',axis='Z')
    cyl('Reliquary sealed face '+str(i),(0,y,.874),.105,.02,'bands',axis='Z')
    for j in range(12):
        a=j*math.pi/6
        o=box('Reliquary %s radial tooth %02d'%(i,j),(.146*math.sin(a),y+.146*math.cos(a),.865),(.035,.055,.045),'rail',.003);o.rotation_euler[2]=-a
    cyl('Reliquary dark iris '+str(i),(0,y,.893),.047,.025,'dark',axis='Z',verts=24)
    seat(dial,core,'Dial pedestal seats on shell crown')

empty('origin_native_north_1x9',(0,0,0))
empty('aft_exhaust_axis',(0,-4.39,.51))
S['candidate_stage']='CONSTRUCTION_PILOT_NOT_RUNTIME_OR_OWNER_APPROVED'
S['native_policy']='1x9 fixed north; sealed script-serviced fluids; no visible pipe or invented wire socket'
S['reference_shape']='Long dark vessel, repeated brass binding bands, paired coil rails, fore crown and concentric aft rings'

def light(name,pos,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new(name,data);S.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
light('Key softbox',(4,-2,7),900,5);light('Rear rim',(-3,5,5),1100,4);light('Front fill',(1,-7,4),600,4)
camdata=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',camdata);S.collection.objects.link(cam);S.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=10.7
cam.location=(5,-8,12);cam.rotation_euler=(Vector((0,0,.4))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
blend=OUT/'void-fusion-v01.blend';glb=OUT/'void-fusion-v01.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
refs={}
for state in ('idle','run'):
    p=ROOT/f'tech-priests_src/graphics/entity/void-fusion-thruster/void-fusion-thruster-{state}.png';refs[str(p.relative_to(ROOT))]={'sha256':sha(p),'bytes':p.stat().st_size}
write_json('source-contract.json',{'prototype':'void-fusion-thruster','source_reference':refs,'source_recovery':'No existing authored narrow fusion source found in tracked source tree or original thruster work directories. Fresh V01 construction study.','native_contract':{'tile_width':1,'tile_height':9,'collision_box':[[-.45,-4.45],[.45,4.45]],'north_only':True,'visible_fluid_ports':0,'visible_wire_connector':'None declared; no socket invented','power_sink':'Invisible script proxy: 12MW nominal, 30MJ buffer, 30MW input; no model interface implied'},'model_frame':'+Y fore, -Y aft, Z up, ground Z0; origin center of native 1x9 rectangle','contacts':CONTACTS,'geometry_scope':'Rigid construction pilot; working coils, machinery, heat/exhaust and source-faithful emblem detail are future authored stages.','blend_sha256':sha(blend),'glb_sha256':sha(glb)})
print('VOID_CONSTRUCTION_SAVED',len([o for o in S.objects if o.type=='MESH']),blend,glb)
