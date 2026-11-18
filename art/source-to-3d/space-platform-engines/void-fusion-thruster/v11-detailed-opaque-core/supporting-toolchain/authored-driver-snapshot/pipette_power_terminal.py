"""Asset-local Pipette ring-lug terminal with separate mate and wire sockets.

No saving/export, no shared Pipette edits, and no receiver geometry mutation.
The library ring_lug recipe is actually called. Its coaxial prototype eye/tang
layout and undersized conductor bore are transparently adapted into a seated
formed lug. Parent drivers must independently recheck the exported GLB.
"""
from __future__ import annotations
import hashlib, math, pathlib, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=pathlib.Path(__file__).resolve().parents[3]
PIPETTE=ROOT/'tools/fmpl/pipette'
if str(PIPETTE) not in sys.path:sys.path.insert(0,str(PIPETTE))
import library_fittings
assert pathlib.Path(library_fittings.__file__).resolve()==(PIPETTE/'library_fittings.py').resolve()

def _sha(path):return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
def _tree(obj):
    bpy.context.view_layer.update();m=obj.data;m.calc_loop_triangles()
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
def _uv_and_normals(obj):
    me=obj.data;bm=bmesh.new();bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    # Exact Boolean unions can retain sub-microunit slivers when translated far
    # along this long asset. Collapse only a numerically short edge, preserving
    # closed topology and the original 20-microunit mating tolerance.
    area=lambda f:(f.verts[1].co-f.verts[0].co).cross(f.verts[2].co-f.verts[0].co).length*.5
    for _ in range(30):
        tiny=[f for f in bm.faces if area(f)<5e-12]
        if not tiny:break
        edge=min(tiny[0].edges,key=lambda e:e.calc_length());length=edge.calc_length()
        if length>1e-5:
            # Collinear three-vertex Boolean fan: dissolve its middle vertex
            # rather than moving a broad endpoint or accepting a zero triangle.
            f=tiny[0];vs=list(f.verts);found=False
            for i,v in enumerate(vs):
                a,b=[q for q in vs if q!=v];ab=b.co-a.co;t=(v.co-a.co).dot(ab)/ab.length_squared
                if 0<t<1 and (v.co-(a.co+ab*t)).length<1e-7:
                    bmesh.ops.dissolve_verts(bm,verts=[v],use_face_split=False,use_boundary_tear=False);found=True;break
            if not found:raise RuntimeError(('Terminal collapsed face is not a local Boolean fan',obj.name,length,f.calc_area()))
        else:bmesh.ops.pointmerge(bm,verts=list(edge.verts),merge_co=edge.verts[0].co.copy())
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-8)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
    if any(area(f)<5e-12 for f in bm.faces):raise RuntimeError('Terminal microscopic-face repair incomplete')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
    uv=me.uv_layers.get('TerminalPhysicalUV') or me.uv_layers.new(name='TerminalPhysicalUV')
    for face in me.polygons:
        a,b,c=[me.vertices[i].co for i in face.vertices]
        u=max((b-a,c-a,c-b),key=lambda v:v.length).normalized();v=(b-a).cross(c-a).normalized().cross(u)
        for li in face.loop_indices:
            p=me.vertices[me.loops[li].vertex_index].co-a;uv.data[li].uv=(p.dot(u)*32,p.dot(v)*32)
def _components(obj):
    adjacency=[set() for _ in obj.data.vertices]
    for e in obj.data.edges:a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
    unseen=set(range(len(adjacency)));count=0
    while unseen:
        count+=1;todo=[unseen.pop()]
        while todo:
            i=todo.pop();new=adjacency[i]&unseen;unseen.difference_update(new);todo.extend(new)
    return count

def build_power_terminal(receiving_parent, pad_point, pad_normal, wire_tangent,
                         copper_material, insulator_material,
                         wire_diameter=.014, prefix='Pipette power terminal',
                         collection=None, architecture_id='wire_single_bare_copper',
                         seating_tolerance=2e-5):
    """Build one retained formed ring lug on an ACTUAL planar receiving pad.

    ``pad_point`` is a proposed mating datum, validated against receiver and
    constructed lug surfaces. It is NOT reused as the wire-entry socket.
    ``wire_tangent`` points OUT from the barrel into its external lead; it is
    projected into the pad plane. Run a continuous wire through returned
    ``wire_entry_socket`` to ``wire_stop_socket`` (or reverse for a start end).
    No extra conductor stub is created, avoiding a duplicate/hidden wire.

    Returns object names, actual source mate/bore measurements, recipe/adaptation
    records, source surface-contact probes and separately measured wire sockets.
    Raises on a nonplanar/uncovered pad, disconnected conductor, blocked bore or
    wrong material/type. Only newly owned objects are created/removed.
    """
    if bpy.context.mode!='OBJECT':raise RuntimeError('Terminal builder needs OBJECT mode')
    if receiving_parent.type!='MESH':raise ValueError('Receiving parent must be an actual mesh')
    if architecture_id not in ('wire_single_bare_copper','wire_single_insulated_solid'):
        raise ValueError('This fixture accepts only ring_lug-compatible single-wire architectures')
    if copper_material is None or insulator_material is None:raise ValueError('Real copper and insulator materials required')
    if not .002<=wire_diameter<=.05:raise ValueError('Wire OD outside this bounded asset fixture')
    if any(o.name.startswith(prefix+' |') for o in bpy.context.scene.objects):raise ValueError('Use a unique terminal prefix')
    p=Vector(pad_point);n=Vector(pad_normal).normalized();t=Vector(wire_tangent);t-=n*t.dot(n)
    if t.length<1e-7:raise ValueError('Wire tangent must have a component along the pad')
    t.normalize();u=n.cross(t).normalized()
    col=collection or bpy.context.scene.collection
    active=bpy.context.view_layer.objects.active;selected=list(bpy.context.selected_objects);owned=[]
    def world(a,b,c):return p+t*a+u*b+n*c
    def create(label,vertices,faces,material,role):
        name=prefix+' | '+label;me=bpy.data.meshes.new(name+' mesh');me.from_pydata(vertices,[],faces);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);me.materials.append(material);owned.append(name)
        o['pipette_architecture_id']=architecture_id;o['pipette_joint_id']='ring_lug';o['pipette_asset_owned']=True;o['pipette_role']=role;o['pipette_wire_od']=wire_diameter
        _uv_and_normals(o);return o
    def from_spec(spec,transform,material):return create(spec['name'],[transform(Vector(v)) for v in spec['vertices']],spec['faces'],material,spec['role'])
    def cylinder(label,a,b,radius,material,role,sides=24):
        spec=library_fittings.rod(tuple(a),tuple(b),radius,arch=architecture_id,label=label,role=role,sides=sides)
        return from_spec(spec,lambda v:v,material)
    try:
        design_diameter=wire_diameter*2.2;r=design_diameter/2
        call={'architecture_id':architecture_id,'joint_id':'ring_lug','port':{'id':prefix+'.recipe_local','xyz_bu':[0,0,0],'outward_normal':[1,0,0]},'diameter':design_diameter}
        raw=library_fittings.build(**call)  # REQUIRED actual typed library call.
        barrel_spec=next(s for s in raw if s['role']=='wire-crimp-barrel')
        eye_spec=next(s for s in raw if s['role']=='flat-ring-lug')
        bridge_spec=next(s for s in raw if s['role']=='solid-lug-bridge')
        barrel_outer=r*.74;bore=wire_diameter*.5*1.06;barrel_length=r*1.3
        assert barrel_outer>bore*1.3
        eye_outer=r*1.23;eye_bore=r*.39;eye_thickness=r*.22
        axis_height=barrel_outer+wire_diameter*.014
        barrel_center_t=eye_outer+barrel_length*.55
        tmin=barrel_center_t-barrel_length*.5;tmax=barrel_center_t+barrel_length*.5
        source_center=Vector(tuple(sum(v[k] for v in barrel_spec['vertices'])/len(barrel_spec['vertices']) for k in range(3)))
        old_bore=r*.31
        def barrel_transform(v):
            v=v-source_center;rad=math.hypot(v.y,v.z);new_r=bore if rad<(old_bore+barrel_outer)/2 else barrel_outer
            return world(barrel_center_t+v.x,v.y*new_r/rad,axis_height+v.z*new_r/rad)
        barrel=from_spec(barrel_spec,barrel_transform,copper_material)
        ec=Vector(tuple(sum(v[k] for v in eye_spec['vertices'])/len(eye_spec['vertices']) for k in range(3)))
        eye=from_spec(eye_spec,lambda v:world((v-ec).y,(v-ec).z,eye_thickness*.5+(v-ec).x),copper_material)
        # Adapt the recipe's short block to a real formed conductive tang that
        # overlaps the eye annulus and lower crimp wall, while staying OUT of bore.
        tang_rows=[(eye_outer*.45,0,eye_thickness,wire_diameter*.46),
                   (eye_outer*.80,0,eye_thickness,wire_diameter*.46),
                   (barrel_center_t,wire_diameter*.025,axis_height-bore-wire_diameter*.035,wire_diameter*.32)]
        vv=[]
        for x,z0,z1,w in tang_rows:vv.extend([world(x,-w,z0),world(x,w,z0),world(x,w,z1),world(x,-w,z1)])
        ff=[(3,2,1,0),(8,9,10,11)]
        for k in range(2):
            for j in range(4):ff.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
        tang=create('Formed connected conductive tang',vv,ff,copper_material,'adapted-solid-lug-bridge')
        stop_thickness=wire_diameter*.12
        stop=cylinder('Conductor insertion endstop',world(tmin,0,axis_height),world(tmin+stop_thickness,0,axis_height),barrel_outer*.90,copper_material,'actual-wire-insertion-stop')
        # True union, not a collection join: this removes internal overlapping
        # walls and creates one connected conductive barrel/tang/eye surface.
        body=barrel
        for other in (eye,tang,stop):
            mod=body.modifiers.new('Actual conductive union','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=other
            bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
        old_name=body.name;body.name=prefix+' | Connected formed ring lug';owned.append(body.name)
        _uv_and_normals(body)
        if _components(body)!=1:raise RuntimeError('Constructed conductive fixture is not one connected component')
        body['pipette_original_recipe']='library_fittings.build(single_wire,ring_lug)';body['pipette_asset_adaptation']='reoriented seated eye; enlarged wire bore; formed connected tang; unioned real insertion stop'
        # Insulating cover fits actual barrel OUTER polygon (not a free-floating
        # ring and not a cable gland falsely used for this single-wire family).
        boot_center=barrel_center_t+barrel_length*.5-wire_diameter*.32
        boot_spec=library_fittings.annul((0,0,0),(1,0,0),barrel_outer*1.13,barrel_outer,wire_diameter*.46,arch=architecture_id,label='Insulating crimp-barrel cover',role='seated-insulating-barrel-cover',sides=24)
        boot=from_spec(boot_spec,lambda v:world(boot_center+v.x,v.y,axis_height+v.z),insulator_material)
        # Eye-retaining hardware: stud ends at actual pad plane; an actual
        # washer and bored six-flat nut bear on the eye's upper face.
        stud_r=eye_bore*.71
        stud=cylinder('Receiving stud',p,world(0,0,eye_thickness+wire_diameter*.62),stud_r,copper_material,'pad-seated-retaining-stud')
        washer_h=wire_diameter*.14
        washer_spec=library_fittings.annul(tuple(world(0,0,eye_thickness+washer_h/2)),tuple(n),eye_bore*1.38,stud_r*1.04,washer_h,arch=architecture_id,label='Eye retaining washer',role='eye-seated-retaining-washer')
        washer=from_spec(washer_spec,lambda v:v,copper_material)
        nut_h=wire_diameter*.27
        nut_spec=library_fittings.annul(tuple(world(0,0,eye_thickness+washer_h+nut_h/2)),tuple(n),eye_bore*1.55,stud_r*1.07,nut_h,arch=architecture_id,label='Retaining six-flat nut',role='actual-bored-retaining-nut',hex_outer=True)
        nut=from_spec(nut_spec,lambda v:v,copper_material)
        bpy.context.view_layer.update();bt=_tree(body);pt=_tree(receiving_parent)
        mate=[];sample_r=(eye_bore+eye_outer)/2
        for j in range(8):
            a=math.tau*j/8;q=world(sample_r*math.cos(a),sample_r*math.sin(a),0)
            pad_hit=pt.ray_cast(q+n*.025,-n,.05);lug_hit=bt.ray_cast(q-n*.012,n,.03)
            if pad_hit[0] is None or lug_hit[0] is None:raise RuntimeError('Actual pad/lug mating sample misses geometry')
            pe=(pad_hit[0]-q).length;le=(lug_hit[0]-q).length
            if max(pe,le)>seating_tolerance:raise RuntimeError('Actual fitting backface does not mate actual receiving pad')
            if abs(pad_hit[1].dot(n))<.985:raise RuntimeError('Receiving pad is not planar in proposed mate frame')
            mate.append({'a':body.name,'b':receiving_parent.name,'point':list(q),'normal':list(n),'tolerance':seating_tolerance,'actual_pad_ray_error':pe,'actual_lug_backface_ray_error':le,'reason':'Measured actual lug annular backface and real receiving pad; separate from wire-entry socket'})
        actual_vertices=[body.matrix_world@v.co for v in body.data.vertices]
        actual_front=max((v-p).dot(t) for v in actual_vertices)
        front_ring=[v for v in actual_vertices if abs((v-p).dot(t)-actual_front)<1e-6]
        entry=sum(front_ring,Vector())/len(front_ring)
        stop_hits=[]
        for j in range(9):
            off=Vector() if j==0 else (u*math.cos(math.tau*(j-1)/8)+n*math.sin(math.tau*(j-1)/8))*wire_diameter*.495
            hit=bt.ray_cast(entry+off+t*.003,-t,barrel_length+.006)
            if hit[0] is None:raise RuntimeError('Wire bore has no actual insertion stop')
            expected=world(tmin+stop_thickness,0,axis_height)+off
            error=(hit[0]-expected).length
            if error>seating_tolerance:raise RuntimeError('Adapted tang/union blocks actual wire-OD bore before endstop')
            stop_hits.append({'wire_cross_section_probe':j,'actual_hit':list(hit[0]),'expected_stop_face_point':list(expected),'error':error})
        stop_point=Vector(stop_hits[0]['actual_hit'])
        entry_socket={'id':prefix+'.wire_entry','xyz':list(entry),'normal':list(t),'role':'sink','payloads':['power'],'parent_mesh':body.name}
        stop_socket={'id':prefix+'.wire_stop','xyz':list(stop_point),'normal':list(t),'role':'sink','payloads':['power'],'parent_mesh':body.name}
        body['pipette_wire_entry_xyz']=list(entry);body['pipette_wire_entry_normal']=list(t);body['pipette_wire_stop_xyz']=list(stop_point);body['pipette_mate_datum_xyz']=list(p);body['pipette_mate_normal']=list(n)
        return {'objects':[o.name for o in (body,boot,stud,washer,nut)],'conductor_object':body.name,'wire_entry_socket':entry_socket,'wire_stop_socket':stop_socket,'surface_contacts':mate,'source_mating_measurement':{'proposed_pad_point':list(p),'normal':list(n),'actual_backface_min_offset':min((v-p).dot(n) for v in actual_vertices),'max_sample_error':max(max(x['actual_pad_ray_error'],x['actual_lug_backface_ray_error']) for x in mate),'sample_count':len(mate),'wire_entry_is_distinct_from_mate':(entry-p).length>wire_diameter},'source_bore_measurement':{'wire_od':wire_diameter,'adapted_bore_radius':bore,'minimum_polygonal_bore_radius_design':bore*math.cos(math.pi/24),'wire_radial_clearance_design':bore*math.cos(math.pi/24)-wire_diameter/2,'actual_insertion_depth':(entry-stop_point).dot(t),'endstop_probes':stop_hits},'pipette_recipe':{'actual_call':call,'module_sha256':_sha(PIPETTE/'library_fittings.py'),'geometry_module_sha256':_sha(PIPETTE/'library_geometry.py'),'architecture_catalog_sha256':_sha(PIPETTE/'architecture_catalog.v1.json'),'original_generated_meshes':raw,'adaptations':['Reoriented bolt eye onto actual receiving-pad plane; public recipe XYZ is not interpreted as physical mate','Enlarged prototype crimp bore to wire radius*1.06 while preserving a real copper wall','Replaced original short tang block with a formed connected tang; exact-unioned barrel/tang/eye/actual conductor stop','Separate actual wire-entry and insertion-stop sockets measured after construction; no duplicate internal wire stub','Added physically retained stud/washer/bored nut and outer crimp-cover; no cable-gland misclassification']},'limits':['Source fixture measurements only; parent must independently reimport actual GLB and remeasure reported probes/sockets','No electrical rating, ampacity, native Factorio port or electrical simulation claim','Ring lug and wire are asset-local adaptations of Pipette prototype recipes; shared libraries unchanged']}
    except Exception:
        for name in owned:
            obj=bpy.data.objects.get(name)
            if obj is not None:bpy.data.objects.remove(obj,do_unlink=True)
        raise
    finally:
        for obj in bpy.context.selected_objects:obj.select_set(False)
        for obj in selected:
            if obj.name in bpy.data.objects:obj.select_set(True)
        if active is not None and active.name in bpy.data.objects:bpy.context.view_layer.objects.active=active



