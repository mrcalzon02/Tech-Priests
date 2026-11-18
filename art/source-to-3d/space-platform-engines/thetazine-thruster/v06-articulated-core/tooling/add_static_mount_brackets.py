"""Localized fixed mounting shoes/ties only; no core, piston or route edits.

A static pilot accepts the immutable V05 source. Any later motion source needs
an explicit matching --motion-source-pin after the stage3 handoff, and must still
earn independent new swept-motion clearance. This script does not grant it.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import delaunay_2d_cdt

V05_PIN="f02f30ad740636d6fa7906a01c6b86af45d90cf1eb940a7c7fc627ed065a2f34"
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--source",type=Path,required=True)
p.add_argument("--manifest",type=Path,required=True)
p.add_argument("--out",type=Path,required=True)
p.add_argument("--motion-source-pin")
a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
source=a.source.resolve();out=a.out.resolve();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source_pin=sha(source)
assert source_pin==V05_PIN or a.motion_source_pin==source_pin,"Wait for stage3 motion source and pin"
record=json.loads(a.manifest.read_text())
assert record["native"]["sha256"]==source_pin or a.motion_source_pin==source_pin
if record["native"]["sha256"]!=source_pin:
    record["static_detail_baseline"]={"manifest_path":str(a.manifest.resolve()),"manifest_sha256":sha(a.manifest),
                                      "previous_native":record["native"]}
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;scene.frame_set(0);bpy.context.view_layer.update()
baseline_names={o.name for o in scene.objects}
collection=bpy.data.collections.new("V06_LOCALIZED_FIXED_MOUNT_BRACKETS")
scene.collection.children.link(collection)
materials={"steel":bpy.data.materials["Hydrogen steel"],"brass":bpy.data.materials["Hydrogen brass"],
           "cast":bpy.data.materials["Hydrogen cast"]}
new_rows=[];reliefs=[];new_seats=[]


def tree(obj):
    obj.data.calc_loop_triangles()
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],
        [tuple(t.vertices)for t in obj.data.loop_triangles],all_triangles=True)


def basis(normal):
    n=Vector(normal).normalized();r=Vector((1,0,0))if abs(n.x)<.8 else Vector((0,1,0))
    u=(r-n*r.dot(n)).normalized();return u,n.cross(u).normalized(),n


def finish(obj):
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method="FIXED",ngon_method="EAR_CLIP")
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=2e-7)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method="FIXED",ngon_method="EAR_CLIP")
    assert all(e.is_manifold for e in bm.edges),(obj.name,"Nonclosed new bracket")
    volume=bm.calc_volume(signed=True);assert volume>1e-9
    bm.to_mesh(obj.data);bm.free();obj.data.update();obj.data.calc_loop_triangles()
    xyz=np.asarray([v.co[:]for v in obj.data.vertices],dtype=np.float64)
    tri=np.asarray([q.vertices[:]for q in obj.data.loop_triangles]);q=xyz[tri]
    crosses=np.linalg.norm(np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]),axis=1)
    assert float(crosses.min())>=1e-10,(obj.name,"Boolean/primitive sliver",float(crosses.min()))
    while len(obj.data.uv_layers):obj.data.uv_layers.remove(obj.data.uv_layers[0])
    uv=obj.data.uv_layers.new(name="V06 fixed bracket physical face UV")
    for poly in obj.data.polygons:
        axes=np.argsort(np.abs(poly.normal))[:2]
        for li in poly.loop_indices:
            vertex=xyz[obj.data.loops[li].vertex_index]
            uv.data[li].uv=vertex[axes]*2+np.asarray((.217,.371))
    for t in obj.data.loop_triangles:
        pts=np.asarray([uv.data[i].uv[:]for i in t.loops],dtype=np.float64);d=pts[1:]-pts[0]
        assert abs(d[0,0]*d[1,1]-d[0,1]*d[1,0])>=1e-10,(obj.name,"Collapsed bracket UV")
    return volume


def mesh(name,vertices,faces,host,material,category):
    inv=host.matrix_world.inverted();data=bpy.data.meshes.new(name)
    data.from_pydata([list(inv@Vector(v))for v in vertices],[],faces);data.update()
    obj=bpy.data.objects.new(name,data);collection.objects.link(obj);obj.parent=host
    obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=Matrix.Identity(4)
    data.materials.append(materials[material]);obj["render_component"]="body"
    obj["v06_detail_category"]=category
    bpy.context.view_layer.update();finish(obj)
    row={"name":obj.name,"host":host.name,"category":category,"geometry_space":"receiving-host-local",
         "allowed_intersections":[host.name]}
    record.setdefault("details",[]).append(row);new_rows.append(row)
    return obj


def seat(obj,host,point,normal,reason):
    point=Vector(point);normal=Vector(normal).normalized()
    assert tree(obj).find_nearest(point)[3]<2e-5,(obj.name,"Missing actual bracket seat")
    assert tree(host).find_nearest(point)[3]<2e-5,(host.name,"Missing actual receiving face")
    local=host.matrix_world.inverted()@point
    local_normal=(host.matrix_world.to_3x3().transposed()@normal).normalized()
    row={"object":obj.name,"host":host.name,"point_host_local":list(local),"normal_host_local":list(local_normal),"reason":reason}
    record.setdefault("seats",[]).append(row);new_seats.append(row)


def actual_surface(host,point,normal):
    n=Vector(normal).normalized();hit=tree(host).ray_cast(Vector(point)+n*.15,-n,.3)
    assert hit[0]is not None and hit[1].dot(n)>.995,(host.name,"No actual flat receiving face")
    return hit[0]


def clipped(w,h,c):
    x,y=w*.5,h*.5
    return [(-x+c,-y),(x-c,-y),(x,-y+c),(x,y-c),(x-c,y),(-x+c,y),(-x,y-c),(-x,-y+c)]


def prism(name,host,point,normal,profile,thickness,material,category):
    u,v,n=basis(normal);point=Vector(point);count=len(profile)
    vertices=[point+u*x+v*y+n*z for z in (0,thickness)for x,y in profile]
    faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count)for i in range(count)]
    return mesh(name,vertices,faces,host,material,category)


def ring(name,host,point,normal,inner,outer,height,material,category,sides=24):
    u,v,n=basis(normal);point=Vector(point)
    vertices=[point+n*z+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r
              for z,r in [(0,inner),(0,outer),(height,outer),(height,inner)]for i in range(sides)]
    faces=[(j*sides+i,j*sides+(i+1)%sides,((j+1)%4)*sides+(i+1)%sides,((j+1)%4)*sides+i)
           for j in range(4)for i in range(sides)]
    return mesh(name,vertices,faces,host,material,category)


def rod(name,host,point,normal,radius,height,category,sides=12):
    return prism(name,host,point,normal,[(radius*math.cos(i*math.tau/sides),radius*math.sin(i*math.tau/sides))for i in range(sides)],height,"brass",category)


def bolt(prefix,plate,insert_host,point,normal,plate_thickness,radius=.012):
    u,v,n=basis(normal);point=Vector(point);height=.004
    washer=ring(prefix+" actual bored washer",plate,point,n,radius*.50,radius*1.5,height,"brass","fixed-bracket-fastener")
    head=rod(prefix+" retained six-flat head",plate,point+n*height,n,radius,.011,"fixed-bracket-fastener",6)
    stud=rod(prefix+" bounded insert stud",plate,point-n*(plate_thickness+.010),n,radius*.40,plate_thickness+.018,"intentional-fastener-insertion")
    for row in new_rows[-3:]:row["allowed_intersections"]=list({plate.name,washer.name,head.name,stud.name,insert_host.name}-{row["name"]})
    seat(washer,plate,point+u*radius*.9,n,"Washer annulus bears on actual new plate top")
    seat(head,washer,point+n*height+u*radius*.70,n,"Captive head underside bears on real washer")
    record.setdefault("fasteners",[]).append({"washer":washer.name,"head":head.name,"stud":stud.name,
        "receiving_host":plate.name,"insert_host":insert_host.name,"intentional_stud_insertion":plate_thickness+.010,
        "insertion_into_original_support":.010})
    return washer,head,stud


def perforated_cap(name,host,point,normal,originals):
    """Actual hole boundaries share one triangulated plate, with no cutter slivers."""
    u,v,n=basis(normal);point=Vector(point);outer=[Vector(q)for q in clipped(.40,.28,.025)]
    points=[Vector(q)for q in outer];edges=[];holes=[];rows=[]
    for i in range(len(points)):edges.append((i,(i+1)%len(points)))
    for original in originals:
        vertices=[original.matrix_world@q.co for q in original.data.vertices]
        center=sum(vertices,Vector())/len(vertices)
        xy=Vector(((center-point).dot(u),(center-point).dot(v)))
        radius=max(math.hypot((q-point).dot(u)-xy.x,(q-point).dot(v)-xy.y)for q in vertices)+.003
        loop=[xy+Vector((math.cos(i*math.tau/32),math.sin(i*math.tau/32)))*radius for i in range(32)]
        start=len(points);points+=loop
        edges += [(start+i,start+(i+1)%32)for i in range(32)];holes.append(loop)
        rows.append({"retained_original":original.name,"center_world":list(point+u*xy.x+v*xy.y),
                     "axis_world":list(n),"radius":radius,"projected_actual_head_margin":.003})
    coordinates,_,triangles,_,_,_=delaunay_2d_cdt(points,edges,[],0,1e-9)
    def inside(p,poly):
        value=False
        for a,b in zip(poly,poly[1:]+poly[:1]):
            if (a.y>p.y)!=(b.y>p.y) and p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x:value=not value
        return value
    kept=[]
    for face in triangles:
        assert len(face)==3
        centroid=sum((coordinates[i]for i in face),Vector((0,0)))/3
        if inside(centroid,outer)and not any(inside(centroid,hole)for hole in holes):kept.append(tuple(face))
    count=len(coordinates);vertices=[point+u*q.x+v*q.y+n*z for z in (0,.018)for q in coordinates]
    faces=[tuple(reversed(face))for face in kept]+[tuple(i+count for i in face)for face in kept]
    boundary={}
    for face in kept:
        for a,b in zip(face,face[1:]+face[:1]):boundary.setdefault(tuple(sorted((a,b))),[]).append((a,b))
    faces += [(a,b,b+count,a+count)for values in boundary.values()if len(values)==1 for a,b in values]
    obj=mesh(name,vertices,faces,host,"steel","fixed-bearing-shoe")
    for row in rows:reliefs.append(dict(row,part=obj.name,method="Constrained triangulated32-sided through-hole around complete actual old head"))
    return obj


caps={};z=Vector((0,0,1))
for side in (-1,1):
    for index in range(5):
        host=bpy.data.objects[f"Underlay side bearing block {side} {index}"]
        vv=[host.matrix_world@q.co for q in host.data.vertices]
        center=(Vector([min(p[k]for p in vv)for k in range(3)])+Vector([max(p[k]for p in vv)for k in range(3)]))*.5
        point=actual_surface(host,(center.x,center.y,max(q.z for q in vv)),z)
        prefix=f"V06 fixed bearing shoe {side} {index}"
        originals=[bpy.data.objects[f"Underlay block fastener {side} {index} {offset}"]for offset in (-.13,.13)]
        cap=perforated_cap(prefix+" fitted access cap",host,point,z,originals)
        for dx,dy in [(0,0),(0,-.10),(0,.10),(-.065,0),(.065,0)]:seat(cap,host,point+Vector((dx,dy,0)),z,"Actual original bearing-block top receives shaped shoe")
        # A tapered cast rib stays in the measured central lane between bolts.
        corners=[(-.045,-.047),(.045,-.047),(.045,.047),(-.045,.047)]
        upper=[(-.025,-.043),(.025,-.043),(.025,.043),(-.025,.043)]
        verts=[point+Vector((x,y,.018))for x,y in corners]+[point+Vector((x,y,.032))for x,y in upper]
        faces=[(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4)for i in range(4)]
        rib=mesh(prefix+" tapered load rib",verts,faces,cap,"cast","fixed-shoe-load-rib")
        seat(rib,cap,point+z*.018,z,"Tapered rib is seated on real machined cap")
        caps[side,index]=cap
        for offset in (-.08,.08):bolt(prefix+str(offset),cap,host,point+Vector((0,offset,.018)),z,.018)

# Short stepped straps bridge two EXISTING fixed receiving surfaces. They do not
# connect to the suspended core or span an invented unmounted longitudinal rail.
fore=bpy.data.objects["Underlay fore crossmember"]
for side in (-1,1):
    x=side*2.15;point=actual_surface(fore,(x,2.34,-.06),z)
    pad=prism(f"V06 fore fixed joint {side} seated pad",fore,point,z,clipped(.20,.09,.012),.016,"steel","fixed-fore-crossmember-pad")
    seat(pad,fore,point,z,"Actual existing fore crossmember supports joint pad")
    # Explicit Y/Z profile clears the old block rear edge atY2.28 before dropping.
    profile=[(2.22,.018),(2.285,.018),(2.325,point.z+.016),(2.375,point.z+.016),
             (2.375,point.z+.032),(2.317,point.z+.032),(2.277,.034),(2.22,.034)]
    vertices=[Vector((x+dx,y,zz))for dx in (-.040,.040)for y,zz in profile]
    count=len(profile);faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count)for i in range(count)]
    tie=mesh(f"V06 fore fixed joint {side} stepped load strap",vertices,faces,fore,"cast","fixed-fore-load-strap")
    tie_row=new_rows[-1];tie_row["allowed_intersections"]=[caps[side,0].name,pad.name]
    seat(tie,caps[side,0],(x,2.235,.018),z,"Strap fore landing rests on actual bearing-shoe cap")
    seat(tie,pad,(x,2.35,point.z+.016),z,"Strap rear landing rests on actual crossmember pad")
    for dx in (-.067,.067):
        washer,head,stud=bolt(f"V06 fore joint {side} {dx}",pad,fore,point+Vector((dx,0,.016)),z,.016,.010)
        # This joint is above the existing forebar/sidebearer overlap. If a stud
        # tip actually bears on that second fixed member, record that exact
        # opposed contact; do not exempt an unrelated collision.
        bearer=bpy.data.objects[f"Underlay continuous side bearer {side}"]
        toe=point+Vector((dx,0,-.010));hit=tree(bearer).find_nearest(toe)
        if hit[3]<2e-5 and hit[1].dot(z)>.995:
            seat(stud,bearer,toe,z,"Joint stud tip meets actual original sidebearer bearing plane")
            next(row for row in new_rows if row["name"]==stud.name)["allowed_intersections"].append(bearer.name)

bar=bpy.data.objects["Lower mounting crossmember"]
for side in (-1,1):
    local=Vector((max(q.co.x for q in bar.data.vertices)if side==1 else min(q.co.x for q in bar.data.vertices),0,0))
    n=(bar.matrix_world.to_3x3().inverted().transposed()@Vector((side,0,0))).normalized()
    point=actual_surface(bar,bar.matrix_world@local,n)
    cap=prism(f"V06 lower fixed crossbar {side} retained end plate",bar,point,n,clipped(.15,.09,.012),.018,"steel","fixed-lower-crossbar-end")
    seat(cap,bar,point,n,"Retained end plate bears on actual fixed crossbar end")
    u,_,_=basis(n)
    for offset in (-.043,.043):bolt(f"V06 lower end {side} {offset}",cap,bar,point+u*offset+n*.018,n,.018,.010)

for row in new_rows:
    obj=bpy.data.objects[row["name"]]
    assert all(abs((obj.matrix_world@v.co).x)<=2.535+1e-6 for v in obj.data.vertices),(obj.name,"Old overallX envelope exceeded")
scene.frame_set(1);bpy.context.view_layer.update()
blend=out/"thetazine-v06-static-bracket-pilot.blend";glb=out/"thetazine-v06-static-bracket-pilot.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
print("FIXED_BRACKET_SOURCE_READY",str(blend),sha(blend),flush=True)
for obj in scene.objects:obj.select_set(obj.type in {"MESH","EMPTY"}and not obj.get("render_only_volume"))
bpy.ops.export_scene.gltf(filepath=str(glb),use_selection=True,export_format="GLB",export_apply=True,
    export_current_frame=True,export_animations=True,export_animation_mode="SCENE",export_anim_scene_split_object=False,
    export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
record["native"]={"path":str(blend),"sha256":sha(blend)};record["glb"]={"path":str(glb),"sha256":sha(glb)}
record["localized_static_mounts"]={"input_source":str(source),"input_sha256":source_pin,"driver_sha256":sha(__file__),
    "new_detail_names":[q["name"]for q in new_rows],"new_seats":len(new_seats),"old_bolt_access_reliefs":reliefs,
    "scope":"Ten fixed bearing shoes, two real fore fixed joints and two lower crossbar ends only.",
    "motion_gate":"STATIC PILOT ONLY on V05; no new V06 motion clearance, no stage3 application yet"if source_pin==V05_PIN else"Stage3 source pin supplied; independent full new swept-motion clearance remains required"}
record["status"]="STATIC_FIXED_MOUNT_BRACKET_PILOT_REQUIRES_ACTUAL_VIEW_AND_V06_MOTION_CLEARANCE"
record["preservation"]="This add-on adds only fixed mounting child meshes; input stage04e core/actuator/hoses, animation, parents and all pre-existing mesh data are not edited. Original V05 preservation history is separate from the newly authorized V06 motion changes."
(out/"detail-manifest.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
assert sha(source)==source_pin
print("STATIC_BRACKET_PILOT_READY",len(new_rows),"new fixed details",flush=True)
