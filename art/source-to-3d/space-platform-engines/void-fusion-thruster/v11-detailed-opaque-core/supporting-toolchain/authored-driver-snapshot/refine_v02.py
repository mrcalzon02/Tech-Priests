"""Bounded source-fidelity and real surface-seat pass, preserving V01."""
import bpy,math,json,sys,pathlib,hashlib,shutil
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3]
OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v01'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
HALF_EMBED='--half-embed' in sys.argv
STEM='void-fusion-v03' if HALF_EMBED else 'void-fusion-v02'
assert not (OUT/(STEM+'.blend')).exists(),'Use a fresh candidate directory'
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v01.blend'))
S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
contract=json.loads((OLD/'source-contract.json').read_text())
mats={k:bpy.data.materials[n] for k,n in [('hull','Spine blackened cast iron'),('bands','Worn bronze retaining bands'),('rail','Satin iron load rails'),('dark','Refractory nozzle interior')]}
removed=[]
for o in list(S.objects):
    if o.name.startswith(('Reliquary','Mount ','mount_','Crown continuous','Crown armored','Crown bronze','Lid rivet')):
        removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
contacts=[c for c in contract['contacts'] if c['a'] not in removed and c['b'] not in removed]
SURFACE=[]
def mesh(name,vertices,faces,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(vertices,[],faces);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(mats[mat])
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');return o
def box(name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mats[mat]);return o
def cyl(name,pos,r,h,mat,vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=pos);o=bpy.context.object;o.name=name;o.data.materials.append(mats[mat]);return o
def bvh(o):
    me=o.data;me.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in me.vertices],[list(t.vertices) for t in me.loop_triangles],all_triangles=True)
def surface_record(a,b,point,normal,reason):
    SURFACE.append({'a':a.name,'b':b.name,'point':list(point),'normal':list(normal),'tolerance':2e-5,'reason':reason})
def contact(a,b,why):contacts.append({'a':a.name,'b':b.name,'scope':why})
def arc_panel(name,y0,y1,angle0,angle1):
    # Closed thick panel: five actual longitudinal steps and three radial flutes.
    profile=[(y0,.291),(y0+.055,.311),(y0+.13,.319),(y1-.13,.319),(y1-.055,.311),(y1,.291)]
    n=12;verts=[]
    for inner in (False,True):
        for y,r in profile:
            for i in range(n+1):
                a=angle0+(angle1-angle0)*i/n;flute=.009*math.cos(3*math.pi*i/n)**2
                rad=.282 if inner else r+flute
                verts.append((rad*math.sin(a),y,.51+rad*math.cos(a)))
    w=n+1;layer=len(profile)*w;faces=[]
    for inner in (0,1):
        for j in range(len(profile)-1):
            for i in range(n):
                a=inner*layer+j*w+i;faces.append((a,a+1,a+1+w,a+w))
    for j in range(len(profile)-1):
        for i in (0,n):
            a=j*w+i;faces.append((a,a+w,a+w+layer,a+layer))
    for j in (0,len(profile)-1):
        for i in range(n):
            a=j*w+i;faces.append((a,a+layer,a+layer+1,a+1))
    return mesh(name,verts,faces,'hull')

# Existing 1x9 mounting reference remains unchanged. Native Y mapping uses the
# first 192x576 cell and manual visible landmark centers, not invented 3D recovery.
def y_from_pixel(y):return 4.31-(y-35)/(546-35)*8.70
mapping={'source_cell':[0,0,192,576],'visible_body_extent_y':[35,546],'model_y_extent':[4.31,-4.39],'method':'Manually identified sprite landmark rectangles. Longitudinal interpolation only; depth/perspective not asserted recovered.','features':[
 {'name':'Fore skull and cog reliquary','crop_xyxy':[73,55,120,108],'center_y_px':81,'model_y':y_from_pixel(81)},
 {'name':'Aft skull and cog reliquary','crop_xyxy':[73,385,121,436],'center_y_px':410,'model_y':y_from_pixel(410)},
 {'name':'Five retaining and mounting band stations','crop_xyxy':[[55,121,137,139],[55,186,137,202],[55,269,137,285],[55,333,137,349],[55,461,137,479]],'center_y_px':[130,194,277,341,470],'model_y':[y_from_pixel(y) for y in (130,194,277,341,470)]},
 {'name':'Long stepped/fluted central casing','crop_xyxy':[65,108,127,385],'scope':'Segmented raised shoulders, longitudinal relief and recessed seam transitions; no pixel replica claimed'},
 {'name':'Aft concentric exhaust structure','crop_xyxy':[54,442,138,546],'scope':'V01 hollow annular throat retained; source-profile refinement still open'}]}
(OUT/'reference-feature-mapping.json').write_text(json.dumps(mapping,indent=2)+'\n')

# Adjust keel bottom to exact sole-top and saddle-bottom contact planes.
rails=[bpy.data.objects['Continuous structural keel '+str(side)] for side in (-1,1)]
for r in rails:
    # V01 bevel already applied: preserve cross-section but rescale its actual Z.
    lo=min(v.co.z for v in r.data.vertices);hi=max(v.co.z for v in r.data.vertices)
    for v in r.data.vertices:v.co.z=(v.co.z-lo)/(hi-lo)*.09-.045
    r.location.z=.135
core=bpy.data.objects['Sealed longitudinal reaction vessel'];coretree=bvh(core)
for i,py in enumerate((130,194,277,341,470)):
    y=y_from_pixel(py);sole=box('V02 mount %02d ground sole'%i,(0,y,.045),(.86,.27,.09),'rail')
    # Concave saddle uses actual source vessel triangle intersections at 17 x's.
    xs=[-.24+j*.48/16 for j in range(17)];top=[]
    for x in xs:
        hit=coretree.ray_cast(Vector((x,y,-.1)),Vector((0,0,1)),2)[0];assert hit is not None
        top.append(hit.z)
    verts=[]
    for yy in (y-.09,y+.09):
        for zrow in ('bottom','top'):
            verts.extend([(x,yy,.21 if zrow=='bottom' else top[j]) for j,x in enumerate(xs)])
    n=len(xs);faces=[]
    for j in range(n-1):
        faces.extend([(j,j+1,n+j+1,n+j),(2*n+j,3*n+j,3*n+j+1,2*n+j+1),(j,2*n+j,2*n+j+1,j+1),(n+j,n+j+1,3*n+j+1,3*n+j)])
    faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
    saddle=mesh('V02 mount %02d vessel-fitted concave saddle'%i,verts,faces,'hull')
    for r,side in zip(rails,(-1,1)):
        contact(sole,r,'Exact sole top Z.09 / keel bottom Z.09')
        for dy in (-.07,0,.07):surface_record(sole,r,(side*.30,y+dy,.09),(0,0,1),'Actual sole/keel contacting planes')
    # Two ears transfer load from narrower saddle to keels without passing a
    # full-width block through the low central vessel surface.
    for side,r in zip((-1,1),rails):
        ear=box('V02 mount %02d bearer ear %s'%(i,side),(side*.275,y,.195),(.15,.18,.03),'rail')
        contact(ear,r,'Bearer ear bottom Z.18 on keel crown')
        surface_record(ear,r,(side*.30,y,.18),(0,0,1),'Actual bearer ear/keel planes')
        surface_record(ear,saddle,(side*.225,y,.21),(0,0,1),'Ear supports concave saddle outer bottom strip')
    for j in (0,2,4,12,14,16):
        x=xs[j];p=(x,y,top[j]);surface_record(saddle,core,p,(0,0,1),'Saddle crown ray-fitted to actual vessel lower triangles')
    for side in (-1,1):
        bolt=cyl('V02 mount %02d captive sole bolt %s'%(i,side),(side*.37,y,.1025),.032,.025,'bands',6)
        surface_record(bolt,sole,(side*.37,y,.09),(0,0,1),'Actual captive bolt lower cap seats on sole')

# Five independently stepped body bays, four thick panels around each bay.
for i,(a,b) in enumerate(((-3.43,-2.39),(-1.75,-.84),(-.69,.32),(.47,1.48),(1.63,2.92))):
    for j,(l,h) in enumerate(((-78,-43),(-39,-6),(6,39),(43,78))):
        arc_panel('V02 casing bay%02d fluted stepped panel%02d'%(i,j),a,b,math.radians(l),math.radians(h))

# Actual source-supported skull in a continuous toothed cog, mounted flat on the
# upper vessel. Donor anatomy/UV/topology are not flattened or procedurally replaced.
DONOR=ROOT/'art/source-to-3d/conclave-center/v02-supplied-skull/supplied-skull'
records=[];EMBEDDING=[]
for i,y in enumerate((y_from_pixel(81),y_from_pixel(410))):
    verts=[];N=160;ri=.105
    for z in (.792,.846):
        for outer in (False,True):
            for j in range(N):
                a=math.tau*j/N;r=(.178 if j%8 in (2,3,4,5) else .155) if outer else ri
                verts.append((r*math.cos(a),y+r*math.sin(a),z))
    faces=[]
    for j in range(N):
        k=(j+1)%N;faces.extend([(j,k,N+k,N+j),(2*N+j,3*N+j,3*N+k,2*N+k),(j,2*N+j,2*N+k,k),(N+j,N+k,3*N+k,3*N+j)])
    cog=mesh('V02 reliquary %02d continuous twenty-tooth cog'%i,verts,faces,'bands')
    backplate=cyl('V02 reliquary %02d closed relief backplate'%i,(0,y,.814),.141,.052,'hull')
    with bpy.data.libraries.load(str(DONOR/'craneo.v2.packed.blend'),link=False) as (src,dst):
        assert 'Craneo' in src.objects;dst.objects=['Craneo']
    skull=dst.objects[0];S.collection.objects.link(skull);skull.parent=None
    for mod in list(skull.modifiers):skull.modifiers.remove(mod)
    original_vertices=[tuple(v.co) for v in skull.data.vertices]
    original_uv=[tuple(u.uv) for u in skull.data.uv_layers.active.data]
    lo=Vector([min(v[k] for v in original_vertices) for k in range(3)]);hi=Vector([max(v[k] for v in original_vertices) for k in range(3)]);center=(lo+hi)/2
    # A flat face-up skull exposed its underside from the aft review/game view.
    # Mount the actual casting at 45 degrees: face aft/up, forehead fore/up,
    # teeth aft/source-bottom. Preserve the rejected flat V02 study separately.
    scale=.263/(hi.z-lo.z);rot=Matrix.Rotation(-math.pi/4,4,'X')
    frame=rot@Matrix.Scale(scale,4)@Matrix.Translation(-center)
    zz=[(frame@v.co).z for v in skull.data.vertices];shift=Vector((0,y,.834-min(zz)))
    skull.matrix_world=Matrix.Translation(shift)@frame;skull.name='V02 reliquary %02d supplied DGordillo skull'%i
    if HALF_EMBED:
        # Owner correction: bury at least half of the actual casting along the
        # real closed medallion's face normal, without flattening donor anatomy.
        plane=.840;fraction=.505
        current=[(skull.matrix_world@v.co).z for v in skull.data.vertices]
        depth=max(current)-min(current);delta=plane+(1-fraction)*depth-max(current)
        skull.matrix_world=Matrix.Translation((0,0,delta))@skull.matrix_world
        embedded=[(skull.matrix_world@v.co).z-plane for v in skull.data.vertices]
        EMBEDDING.append({'skull':skull.name,'support':backplate.name,'support_plane_point':[0,y,plane],'support_plane_normal':[0,0,1],'direction':'Actual closed medallion upper cap normal; translation into support along -Z','total_directional_depth':max(embedded)-min(embedded),'behind_plane_depth':-min(embedded),'exposed_directional_depth':max(embedded),'embedded_fraction':-min(embedded)/(max(embedded)-min(embedded)),'minimum_embedded_fraction':.5,'translation_into_mount':-delta,'owner_instruction':'At least halfway bury skulls inside their supporting surface; keep facial features readable.'})
    mat=mats['bands'].copy();mat.name='Void Fusion cast supplied skull '+str(i)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
    # Anatomy UVs require anatomy-normal detail, not the band's directional normal.
    for link in list(bs.inputs['Normal'].links):links.remove(link)
    tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(DONOR/'dgordillo-sculpt-normal.png'),check_existing=True);tex.image.colorspace_settings.name='Non-Color';tex.image.pack()
    norm=nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.4;links.new(tex.outputs['Color'],norm.inputs['Color']);links.new(norm.outputs[0],bs.inputs['Normal'])
    skull.data.materials.clear();skull.data.materials.append(mat)
    assert original_vertices==[tuple(v.co) for v in skull.data.vertices]
    assert original_uv==[tuple(u.uv) for u in skull.data.uv_layers.active.data]
    skull.data.calc_loop_triangles();records.append({'object':skull.name,'source_mesh':'Craneo','vertices':len(skull.data.vertices),'triangles':len(skull.data.loop_triangles),'uniform_scale':scale,'source_mesh_vertices_unchanged':True,'original_uv_unchanged':True,'rotation':'-45 degrees around X; face aft/up, forehead fore/up, teeth aft/source-bottom; rejected flat V02 retained','donor_sha256':sha(DONOR/'craneo.v2.packed.blend')})
    # Backmost actual skull vertex embeds .006 into the actual backplate crown.
    if not HALF_EMBED:
        back=min((skull.matrix_world@v.co for v in skull.data.vertices),key=lambda p:p.z)
        SURFACE.append({'a':skull.name,'b':backplate.name,'point':list(back),'normal':[0,0,1],'tolerance':.00601,'reason':'Actual original skull rear surface embeds .006 into closed casting backplate; maximum seat depth recorded'})
    contact(cog,backplate,'Continuous cog seat overlaps closed relief backplate')

for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/(STEM+'.blend');glb=OUT/(STEM+'.glb')
S['candidate_stage']='V02_SOURCE_FIDELITY_SURFACE_SEAT_CANDIDATE_NOT_RUNTIME_APPROVED'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
contract.update({'revision':'V03 owner half-embedded skull reliefs' if HALF_EMBED else 'V02 source-specific reliquary/casing/mount refinement','previous_blend_sha256':sha(OLD/'void-fusion-v01.blend'),'blend_sha256':sha(blend),'glb_sha256':sha(glb),'contacts':contacts,'surface_contacts':SURFACE,'embedded_reliefs':EMBEDDING,'reference_feature_mapping':'reference-feature-mapping.json','source_skull_reuse':records,'geometry_scope':'Rigid construction refinement; no animation, native sprite or runtime promotion. Original donor mesh and UV unchanged under uniform transform.'})
(OUT/'source-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
(OUT/'supplied-skull-reuse.json').write_text(json.dumps({'source':str(DONOR),'instances':records},indent=2)+'\n')
shutil.copy2(DONOR/'ATTRIBUTION.txt',OUT/'ATTRIBUTION.txt')
with (OUT/'ATTRIBUTION.txt').open('a') as f:f.write('\nVoid Fusion V02 adaptation: unchanged original mesh and UV, uniform scaling and rotation, cast-bronze material using original sculpt normal; mounted inside two solid cog reliquaries.\n')
print('VOID_V02_REFINEMENT_SAVED',len(SURFACE),blend)
