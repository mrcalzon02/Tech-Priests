"""V06 first authored refinement: cleaved mineral, conforming clamps, cantilever.

No full sprites or runtime files. +Y is ship, -Y hangs over space; deck edge Y0.
"""
import bpy,bmesh,math,json,pathlib,sys,hashlib,itertools,random,shutil
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v05'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
PASS2='--pass2' in sys.argv;STEM='void-fusion-v07' if PASS2 else 'void-fusion-v06'
assert not (OUT/(STEM+'.blend')).exists()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v05.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
contract=json.loads((OLD/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
removed=[]
for o in list(S.objects):
    gone=o.name.startswith('V04 rock') and ('green fracture' in o.name or 'gripping jaw' in o.name)
    gone|=o.name.startswith('V04 mount')
    gone|=o.name.startswith('V02 mount') and ('bearer ear' in o.name or o.name.startswith(('V02 mount 03','V02 mount 04')))
    if gone:removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
contacts=[c for c in contract['contacts'] if c['a'] not in removed and c['b'] not in removed]
surface=[c for c in contract['surface_contacts'] if c['a'] not in removed and c['b'] not in removed]
M={k:bpy.data.materials[n] for k,n in [('hull','Spine blackened cast iron'),('bands','Worn bronze retaining bands'),('rail','Satin iron load rails'),('copper','Enclosed copper induction winding'),('ceramic','Glazed olive insulator'),('rock','Noctilith faceted black mineral')]}

# Actual region-specific PBR maps: broad grime/mineral variation, no stripe finish.
texture_plan=[];texdir=OUT/'textures';texdir.mkdir(exist_ok=True)
def remap_material(mat,color,metal,rough,role,preserve_normal=False):
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    for socket in ('Base Color','Metallic','Roughness')+(() if preserve_normal else ('Normal',)):
        for link in list(bs.inputs[socket].links):nt.links.remove(link)
    for kind in ('basecolor','metalrough'):
        im=bpy.data.images.new('V06 '+role+' '+kind,width=128,height=128,alpha=True);px=[]
        for v in range(128):
            for u in range(128):
                cloud=.55+.17*math.sin(u*.071+v*.034)+.12*math.sin(v*.13-u*.047)+.09*math.cos((u-73)**2*.0007+(v-25)**2*.001)
                grit=.012*math.sin(u*13.17+v*41.3)
                if kind=='basecolor':rgb=[max(.002,c*(.82+cloud*.25)+grit*.09) for c in color]
                else:rgb=[1,max(.12,min(.95,rough+(cloud-.5)*.14)),metal]
                px.extend((*rgb,1))
        im.pixels.foreach_set(px);im.filepath_raw=str(texdir/(role+'-'+kind+'.png'));im.file_format='PNG';im.save();im.pack()
        node=nt.nodes.new('ShaderNodeTexImage');node.image=im
        if kind=='basecolor':nt.links.new(node.outputs[0],bs.inputs['Base Color'])
        else:
            im.colorspace_settings.name='Non-Color';sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(node.outputs[0],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    texture_plan.append({'material':mat.name,'region':role,'color':color,'metallic':metal,'roughness':rough,'placement':'Broad restrained cloud/grime; no repeated stripe normals. Geometry edges/cast transitions provide highlights. Original skull anatomy normal preserved where applicable.'})
for key,col,met,rough in [('hull',(.046,.050,.043),.72,.63),('rail',(.10,.112,.11),.79,.52),('bands',(.255,.182,.080),.83,.49),('copper',(.24,.115,.043),.86,.43),('ceramic',(.065,.080,.034),.07,.35),('rock',(.009,.014,.011),.10,.51)]:remap_material(M[key],col,met,rough,key)
if PASS2:remap_material(M['rock'],(.004,.007,.005),.0,.86,'rough-black-mineral')
for mat in bpy.data.materials:
    if mat.name.startswith('Void Fusion cast supplied skull'):remap_material(mat,(.265,.188,.082),.78,.48,'skull-cast-'+mat.name[-1],True)
def simple(name,color,metal,rough,emit=None,strength=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    if emit:bs.inputs['Emission Color'].default_value=(*emit,1);bs.inputs['Emission Strength'].default_value=strength
    return m
M['fracture']=simple('V06 recessed energized noctilith cleavage',(.006,.11,.002),.06,.41,(.025,1,.001),2.2)
M['pad']=simple('V06 dark compressed ceramic contact pads',(.018,.026,.019),.03,.72)
M['edge']=simple('V06 actual dressed cast edge metal',(.16,.165,.14),.76,.58)
if PASS2:
    M['crushed']=simple('V07 crushed mineral fracture reveals',(.016,.022,.017),0,.93)
    remap_material(M['crushed'],(.016,.022,.017),0,.93,'crushed-fracture-reveals')

def mesh(name,verts,faces,mat,materials=None,indices=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o)
    for mm in (materials or [M[mat]]):me.materials.append(mm)
    if indices:
        for p,i in zip(me.polygons,indices):p.material_index=i
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=2e-8);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    # Surface-size-preserving planar triangle coordinates. Smart Projection
    # collapsed two narrow contact-jaw UV faces in the first V06 study.
    # These maps are tiling material regions, not a baked detail atlas.
    uv=me.uv_layers.new(name='PhysicalRegionUV')
    for p in me.polygons:
        a,b,c=[me.vertices[i].co for i in p.vertices];u=max((b-a,c-a,c-b),key=lambda q:q.length).normalized();normal=(b-a).cross(c-a).normalized();v=normal.cross(u)
        for li in p.loop_indices:
            q=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(q.dot(u)*2,q.dot(v)*2)
    return o
def replace(old,new):
    name=old.name;bpy.data.objects.remove(old,do_unlink=True);new.name=name;return new
def bevel(o,width=.002):
    o.data.materials.append(M['edge']);mod=o.modifiers.new('Actual dressed casting edges','BEVEL');mod.width=width;mod.segments=2;mod.affect='EDGES';mod.limit_method='ANGLE';mod.angle_limit=.5;mod.material=len(o.data.materials)-1
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
def rod(name,a,b,r,mat):
    d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(M[mat]);return o
def tree(o):
    bpy.context.view_layer.update();m=o.data;m.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
def seat(a,b,p,n,why):surface.append({'a':a.name,'b':b.name,'point':list(p),'normal':list(n),'tolerance':2e-5,'reason':why})

# Closed extruded channel sections preserve the existing top/bottom contact datum.
def channel(name,x0,x1,z0,z1,y0,y1,side):
    t=min((x1-x0)*.24,(z1-z0)*.23)
    pp=[(x0,z0),(x1,z0),(x1,z1),(x0,z1),(x0,z1-t),(x1-t,z1-t),(x1-t,z0+t),(x0,z0+t)]
    if side<0:pp=[(-x,z) for x,z in pp]
    vv=[(x,y,z) for y in (y0,y1) for x,z in pp];n=len(pp);ff=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    ff.extend([(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
    return mesh(name,vv,ff,'rail')
for side in (-1,1):
    old=bpy.data.objects['Continuous structural keel '+str(side)]
    replace(old,channel('new keel',.25,.35,.09,.18,-4.25,4.25,side))
    old=bpy.data.objects['V04 cage longitudinal crown rail '+str(side)]
    replace(old,channel('new crown',.1625,.2175,.8225,.8875,-3.81,3.91,side))

# Mineral half-space hulls and actual plane-cleaved closed fragments, not ico lumps.
def polyhedron(planes):
    vv=[]
    for a,b,c in itertools.combinations(planes,3):
        mat=Matrix((a[0],b[0],c[0]))
        if abs(mat.determinant())<1e-7:continue
        p=mat.inverted()@Vector((a[1],b[1],c[1]))
        if all(n.dot(p)<=d+2e-6 for n,d,_ in planes) and not any((p-q).length<2e-5 for q in vv):vv.append(p)
    if len(vv)<4:return None
    ff=[]
    for n,d,tag in planes:
        ids=[i for i,p in enumerate(vv) if abs(n.dot(p)-d)<1e-5]
        if len(ids)<3:continue
        center=sum((vv[i] for i in ids),Vector())/len(ids);u=n.cross(Vector((0,0,1)))
        if u.length<.1:u=n.cross(Vector((0,1,0)))
        u.normalize();v=n.cross(u);ids.sort(key=lambda i:math.atan2((vv[i]-center).dot(v),(vv[i]-center).dot(u)))
        ff.append((ids,tag,n))
    return vv,ff
ROCK_RECORD=[]
rocks=[]
for index,record in enumerate(contract['rock_bays']):
    old=bpy.data.objects[record['object']];y=old.location.y;half=record['half_length_design'];rng=random.Random(7301+index)
    base=[]
    def plane(n,d,tag='crust'):base.append((Vector(n).normalized(),d,tag))
    for axis,h in ((0,.245),(1,half*.98),(2,.25)):
        for sign in (-1,1):
            if PASS2 and axis==2 and sign==1:continue
            n=[0,0,0];n[axis]=sign;plane(n,h*(.91+rng.random()*.08))
    for sx,sz in itertools.product((-1,1),repeat=2):
        plane((sx*.90,.12*(index%3-1),sz*.78),.278+rng.random()*.018)
    for sy in (-1,1):
        plane((.31,sy*.91,.21),half*.80+.064)
        plane((-.27,sy*.86,-.43),half*.77+.083)
    if PASS2:
        # Distinct broken roof facets/chips and oblique natural faults per bay.
        for n,d in [((.35+.25*math.sin(index+1),.13*math.cos(index*2),.93),.198+rng.random()*.025),((-.62,.24*math.cos(index+2),.80),.216+rng.random()*.023),((.12,-.36-.1*math.sin(index),.91),.211+rng.random()*.025)]:plane(n,d)
    cleaves=[(Vector((.91,.18,-.42)).normalized(),.013),(Vector((.16,.94,.47)).normalized(),-.031),(Vector((-.22,.33,.94)).normalized(),.021)]
    if PASS2:
        rot=Matrix.Rotation(.31*math.sin(index*1.7+1),3,'Y')@Matrix.Rotation(.22*math.cos(index*1.2+.5),3,'Z')
        cleaves=[((rot@n).normalized(),d+.022*math.sin(index*1.9+j)) for j,(n,d) in enumerate(cleaves)]
    verts=[];faces=[];mi=[];fragment_count=0;recesses=0
    for signs in itertools.product((-1,1),repeat=3):
        planes=base+[(n*sign,d*sign-(.006 if PASS2 else .0045),'cleavage') for (n,d),sign in zip(cleaves,signs)]
        poly=polyhedron(planes)
        if not poly:continue
        vv,ff=poly
        if min(max(p[k] for p in vv)-min(p[k] for p in vv) for k in range(3))<.018:continue
        fragment_count+=1
        for ids,tag,n in ff:
            polygon=[vv[j]+Vector((0,y,.55)) for j in ids];start=len(verts);verts.extend(polygon);N=len(ids)
            if tag!='cleavage':faces.append(tuple(start+j for j in range(N)));mi.append(0);continue
            # A dark border and actual recessed walls frame each luminous inner
            # fracture face. No neon rod is overlaid on the external rock.
            center=sum(polygon,Vector())/N;inner=[center+(p-center)*(.90 if PASS2 else .84) for p in polygon]
            depth=.006 if PASS2 else .009
            if PASS2:
                for p in inner:
                    local=p-Vector((0,y,.55))
                    for nn,dd,_ in planes:
                        rate=-nn.dot(n)
                        if rate>1e-6:depth=min(depth,max(.0001,(dd-nn.dot(local))*.65/rate))
            deep=[p-n*depth for p in inner];ib=len(verts);verts.extend(inner);db=len(verts);verts.extend(deep)
            for j in range(N):
                k=(j+1)%N;faces.extend([(start+j,start+k,ib+k,ib+j),(ib+j,ib+k,db+k,db+j)]);mi.extend((0,1))
            faces.append(tuple(db+j for j in range(N)));mi.append(2);recesses+=1
    rock=replace(old,mesh('new cleaved rock',verts,faces,'rock',[M['rock'],M['crushed'] if PASS2 else M['pad'],M['fracture']],mi));rocks.append(rock)
    ROCK_RECORD.append({'object':rock.name,'fragments':fragment_count,'recessed_internal_fracture_faces':recesses,'gap':.009,'recess_depth':.009,'method':'Asymmetric clipped mineral hull, three oblique cleavage cuts; closed disconnected chunks intentional; actual inset emissive inner faces with dark reveals.'})

# Cast rectangular-section retaining bands replace pipe-like torus silhouettes.
for old in list(S.objects):
    if old.name.startswith('V04 rock') and 'open octet retaining ring' in old.name:
        center=old.location.copy();N=32;vv=[]
        for yy in (-.022,.022):
            for r in (.307,.341):
                for j in range(N):
                    a=math.tau*j/N;vv.append((r*math.cos(a),center.y+yy,center.z+r*math.sin(a)))
        ff=[]
        for j in range(N):
            k=(j+1)%N;ff.extend([(j,k,N+k,N+j),(2*N+j,3*N+j,3*N+k,2*N+k),(j,2*N+j,2*N+k,k),(N+j,N+k,3*N+k,3*N+j)])
        replace(old,mesh('new cast band',vv,ff,'rail'))

# Rock-conforming compression pads and shaped cast jaws feed load directly into
# the twin channels. Aft jaws hang on beams; they do not create deck contacts.
PAD_RECORD=[]
for index,rock in enumerate(rocks):
    tr=tree(rock);yc=contract['rock_bays'][index]['center_y']
    for side in (-1,1):
        coords=[]
        for zz in (.485,.55,.615):
            for yy in (yc-.055,yc,yc+.055):
                hit=tr.ray_cast(Vector((side*.5,yy,zz)),Vector((-side,0,0)),1)[0];assert hit is not None,(rock.name,side,yy,zz)
                coords.append(hit)
        # Shared fitted grids, with a real dark ceramic layer between mineral
        # and the substantial tapered jaw, not a block clipping into the rock.
        def fitted(name,inner,outer,role):
            vv=[tuple(p) for p in inner+outer];ff=[]
            for a in (0,1,3,4):ff.extend([(a,a+1,a+4,a+3),(9+a,12+a,13+a,10+a)])
            edge=[0,1,2,5,8,7,6,3]
            for a,b in zip(edge,edge[1:]+edge[:1]):ff.append((a,b,b+9,a+9))
            return mesh(name,vv,ff,role)
        outer=[p+Vector((side*.014,0,0)) for p in coords]
        pad=fitted('V06 rock%02d fitted ceramic contact %s'%(index,side),coords,outer,'pad')
        jawback=[Vector((side*.318,p.y,p.z)) for p in coords]
        jaw=fitted('V06 rock%02d shaped compression jaw %s'%(index,side),outer,jawback,'hull')
        for j in (0,2,4,6,8):seat(pad,rock,coords[j],(side,0,0),'Actual ceramic shoe inner surface conforms to current mineral triangles')
        for j in (2,4,6):seat(jaw,pad,outer[j],(side,0,0),'Cast jaw receiving surface mates actual ceramic outer face')
        # A flat-sided tapered cast web, closed and physically connected from
        # keel to jaw back. The bore-headed clamp bolts are retained separately.
        x=side*.30;z0=.18;z1=.55;vv=[]
        for yy in (yc-.045,yc+.045):
            vv.extend([(x-side*.032,yy,z0),(x+side*.032,yy,z0),(side*.334,yy,z1),(side*.286,yy,z1)])
        web=mesh('V06 rock%02d cast jaw-to-keel web %s'%(index,side),vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'rail')
        keel=bpy.data.objects['Continuous structural keel '+str(side)]
        seat(web,keel,(x,yc,.18),(0,0,1),'Suspended jaw cast-web lower face meets actual channel crown')
        # Seated through-head on the actual outer jaw plane, not a loose bolt.
        bolt=rod('V06 rock%02d jaw captive clamp bolt %s'%(index,side),(side*.318,yc,.55),(side*.343,yc,.55),.020,'bands')
        seat(bolt,jaw,(side*.318,yc,.55),(side,0,0),'Captive clamp bolt inner axial cap on actual jaw back face')
        PAD_RECORD.append({'rock':rock.name,'pad':pad.name,'jaw':jaw.name,'web':web.name,'side':side,'grounded_to':'Continuous structural keel '+str(side),'aft_policy':'Internal load path into cantilever beam, never a foundation receiver'})

# Preserve exact old contacts on replaced channel crown planes; remove only
# those referring to deleted foundation parts. Dress actual plate edges in metal.
for o in list(S.objects):
    if o.type=='MESH' and ('segmented rim armor' in o.name or o.name.startswith('V06 rock') and 'compression jaw' in o.name):
        # Fitted mineral/jaw faces remain exact; bevel rim armor only in pass1.
        if 'segmented rim armor' in o.name:bevel(o,.0014)

foundations=[o.name for o in S.objects if o.name.startswith('V02 mount') and 'ground sole' in o.name]
S['candidate_stage']='V06_PASS1_CLEAVED_MINERAL_CONFORMING_CLAMPS_FORE_ONLY_CANTILEVER'
S['deck_edge_y']=0.0;S['mount_policy']='Only fore-half foundation contacts (+Y). Entire -Y half including emitter hangs over empty space, carried by twin continuous channels.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/(STEM+'.blend');glb=OUT/(STEM+'.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
contract.update({'revision':'V06 first authored refinement and owner half-hanging mounting correction','blend_sha256':sha(blend),'glb_sha256':sha(glb),'previous_blend_sha256':sha(OLD/'void-fusion-v05.blend'),'previous_glb_sha256':sha(OLD/'void-fusion-v05.glb'),'contacts':contacts,'surface_contacts':surface,'authored_refinement':{'mineral':ROCK_RECORD,'contact_shoes':PAD_RECORD,'surface_plan':texture_plan,'pass':1,'open_inspection':'Inspect actual export before second repair pass. Do not infer final4of5.'},'hanging_mount':{'deck_edge_y':0,'deck_top_z':0,'model_frame':'+Y fore=vessel, -Y aft=space, Zup','intended_foundation_objects':foundations,'removed_aft_foundation_stations':[3,4],'policy':'No intended foundation receiver or sole at Y<0. Aft mineral clamps attach to continuous cantilever channels only. About half axial structure hangs beyond edge.','native_policy':'Model preserves native1x9/north/no-visible-port footprint. Root separately reconciles native supported-body/void masks; this art slice does not change them.'}})
(OUT/'source-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
for n in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt'):shutil.copy2(OLD/n,OUT/n)
print('V06_AUTHORED_PASS1_SAVED',len(surface),ROCK_RECORD,foundations)
