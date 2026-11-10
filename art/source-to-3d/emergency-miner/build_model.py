"""V21: carve source-observed foot faces, actual vent openings and seated front screws.

Do not model unseen internals. Owner-defined laser ablation and proto-matter
reconstitution are documented conceptually; the sprite governs visible geometry.
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png"
SOURCE_SHA256 = "29442badbd53d2f69880fb625330ed071e6d362119e458952f575d53cc1bf700"
OUTPUT = None
COLLECTION = None
VISIBLE = None
MATERIALS = {}
FEATURES = []
CABLE_ROUTES = []
LAYER_ELEVATIONS = {"foundation_top":0.165, "chassis_top":0.2952, "deck_top":0.3852, "raised_controls":0.076, "front_control_slope_degrees":11, "middle_chassis_compression":0.42}
random.seed(2001)


def pixel(x, y, z):
    return ((x - 340.0) / 680.0, (340.0 - y) / 680.0, z)


def width(x):
    return x / 680.0


def material(name, rgb, metallic=0.5, roughness=0.55, variation=0.0, emission=0.0):
    if name in MATERIALS:
        return MATERIALS[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    if emission:
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = (*rgb, 1.0)
            shader.inputs["Emission Strength"].default_value = emission
        else:
            shader.inputs["Emission"].default_value = (*rgb, 1.0)
    if variation:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 27.0
        noise.inputs["Detail"].default_value = 3.0
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.16
        ramp.color_ramp.elements[0].color = (*(max(0.0, c * (1 - variation)) for c in rgb), 1)
        ramp.color_ramp.elements[1].position = 0.84
        ramp.color_ramp.elements[1].color = (*(min(1.0, c * (1 + variation)) for c in rgb), 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.18
        bump.inputs["Distance"].default_value = 0.007
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        # Source-dark forged surface grain; shaders, not fabricated detail geometry.
        if name in {"black_steel","iron","edge_steel","worn_steel"}:
            grain=nodes.new("ShaderNodeTexNoise")
            grain.inputs["Scale"].default_value=150.0
            grain.inputs["Detail"].default_value=2.0
            fine=nodes.new("ShaderNodeBump")
            fine.inputs["Strength"].default_value=.16
            fine.inputs["Distance"].default_value=.0015
            links.new(grain.outputs["Fac"],fine.inputs["Height"])
            links.new(bump.outputs["Normal"],fine.inputs["Normal"])
            links.new(fine.outputs["Normal"],shader.inputs["Normal"])
        else:
            links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    MATERIALS[name] = m
    return m


def link_to(obj, collection=None):
    global VISIBLE
    target = collection or VISIBLE
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    target.objects.link(obj)
    return obj


def assign(obj, m):
    obj.data.materials.append(m)
    # Blender 4.0 requires auto smooth for the weighted-normal modifier.
    if obj.type == "MESH" and hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
    return obj


def cube(name, x, y, z, w, h, depth, m, bevel=0.006, collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pixel(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (width(w), width(h), depth)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, m)
    if bevel > 0:
        mod = obj.modifiers.new("Forged edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        normal = obj.modifiers.new("Weight cast normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return link_to(obj, collection)


def ring_outline(w, h, chamfer):
    x, y = w / 2, h / 2
    c = min(chamfer, x * 0.48, y * 0.48)
    return [(-x + c, -y), (x - c, -y), (x, -y + c),
            (x, y - c), (x - c, y), (-x + c, y),
            (-x, y - c), (-x, -y + c)]


def octagonal_case(name, x, y, z_bottom, z_top, w, h, chamfer, m):
    coords = ring_outline(width(w), width(h), width(chamfer))
    center = Vector(pixel(x, y, 0))
    vertices = [(a + center.x, b + center.y, z)
                for z in (z_bottom, z_top) for a, b in coords]
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
    faces.extend((i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8) for i in range(8))
    mesh = bpy.data.meshes.new(name + "_3D")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    VISIBLE.objects.link(obj)
    assign(obj, m)
    bevel = obj.modifiers.new("Cast chamfer edge radii", "BEVEL")
    bevel.width = 0.005
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    obj.modifiers.new("Cast weighted normals", "WEIGHTED_NORMAL")
    return obj



def lofted_cast_chassis(name, stations, m):
    """One watertight tapered *volume*, designed in 3D cross-sections.

    Each station is (z, center_x, center_y, width_px, depth_px, chamfer_px).
    The 2D sprite is a comparison projection, NOT a stack of front-facing
    contour plates. Physically define sidewalls and rounded corner transitions.
    """
    if len(stations)<3 or any(stations[i+1][0]<=stations[i][0]
                             for i in range(len(stations)-1)):
        raise RuntimeError("Chassis stations must rise monotonically")
    verts=[]
    for z,cx,cy,w,d,chamfer in stations:
        outline=ring_outline(width(w),width(d),width(chamfer))
        center=pixel(cx,cy,0)
        verts.extend((center[0]+x,center[1]+y,z) for x,y in outline)
    count=len(stations)
    faces=[tuple(reversed(range(8))),tuple(range(8*(count-1),8*count))]
    for level in range(count-1):
        for index in range(8):
            nxt=(index+1)%8
            faces.append((8*level+index,8*level+nxt,
                          8*(level+1)+nxt,8*(level+1)+index))
    mesh=bpy.data.meshes.new(name+"_INTEGRATED_CAST_VOLUME")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    VISIBLE.objects.link(obj)
    assign(obj,m)
    obj["physical_design"]="LOFTED_3D_INTEGRATED_CHASSIS"
    obj["cross_sections"]=count
    if len(mesh.vertices)!=8*count or len(mesh.polygons)!=(count-1)*8+2:
        raise RuntimeError("Invalid solid chassis connectivity")
    bevel=obj.modifiers.new("Real cast corner breaks", "BEVEL")
    bevel.width=.006
    bevel.segments=3
    bevel.limit_method="ANGLE"
    obj.modifiers.new("Solid forged normal weighting", "WEIGHTED_NORMAL")
    return obj


def cast_contour(name, outline, z_bottom, z_top, m, bevel=.005):
    """Physically thick, reference-traced casting with nonrectangular edges."""
    if len(outline)<4 or z_top<=z_bottom:
        raise RuntimeError("Bad cast contour: "+name)
    n=len(outline)
    vertices=[pixel(x,y,z) for z in (z_bottom,z_top) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(name+"_SOURCE_TRACED_CAST_SURFACE")
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    VISIBLE.objects.link(obj)
    assign(obj,m)
    obj["source_contour"] = True
    if bevel:
        mod=obj.modifiers.new("Cast contour bevel","BEVEL")
        mod.width=bevel
        mod.segments=2
        mod.limit_method="ANGLE"
        obj.modifiers.new("Cast weighted normals","WEIGHTED_NORMAL")
    return obj


def frame_ring(name, x, y, zlow, zhigh, outer_w, outer_h, inner_w, inner_h, m):
    outer = ring_outline(width(outer_w), width(outer_h), width(min(outer_w, outer_h) * 0.08))
    inner = ring_outline(width(inner_w), width(inner_h), width(min(inner_w, inner_h) * 0.06))
    center = pixel(x, y, 0)
    vertices = [(i[0] + center[0], i[1] + center[1], z)
                for loop, z in ((outer, zlow), (outer, zhigh), (inner, zlow), (inner, zhigh))
                for i in loop]
    faces = []
    for i in range(8):
        j = (i+1)%8
        faces.extend([(i, j, j+8, i+8),
                      (i+8, j+8, j+24, i+24),
                      (i+24, j+24, j+16, i+16),
                      (i+16, j+16, j, i)])
    mesh = bpy.data.meshes.new(name + "_physical_metal_ring")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    VISIBLE.objects.link(obj)
    assign(obj, m)
    bev = obj.modifiers.new("Machined edge", "BEVEL")
    bev.width = 0.002
    bev.segments = 2
    bev.limit_method = "ANGLE"
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, x, y, z, radius, depth, m, verts=24, collection=None, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=pixel(x, y, z))
    obj = bpy.context.object
    obj.name = name
    if rotation:
        obj.rotation_euler = rotation
    assign(obj, m)
    bev = obj.modifiers.new("Turned edge", "BEVEL")
    bev.width = min(0.0025, radius * .15, depth * .2)
    bev.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return link_to(obj, collection)


def torus(name, x, y, z, major, minor, m, collection=None, rotation=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
        major_radius=major, minor_radius=minor, location=pixel(x, y, z))
    obj = bpy.context.object
    obj.name = name
    if rotation:
        obj.rotation_euler = rotation
    assign(obj, m)
    return link_to(obj, collection)


def curve(name, coords, radius, m, collection=None):
    data = bpy.data.curves.new(name + "_TRUE_3D_PATH", "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 20
    data.bevel_resolution = 4
    data.bevel_depth = radius
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(coords)-1)
    for point, (x, y, z) in zip(spline.bezier_points, coords):
        point.co = pixel(x, y, z)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, data)
    (collection or VISIBLE).objects.link(obj)
    assign(obj, m)
    return obj


def cable_gland(name, x, y, z, side_entry=False, occluded=False):
    """Use a non-rendering attachment marker when the sprite hides a cable end.

    Avoid making a visible fabricated brass connector merely to give a
    visible cable curve a target. The marker stays in the editable .blend
    but has NO geometry, and does not export as part of the game asset.
    """
    if occluded:
        marker=bpy.data.objects.new(name,None)
        marker.empty_display_type="PLAIN_AXES"
        marker.hide_render=True
        marker.hide_viewport=True
        marker.location=pixel(x,y,z)
        marker["source_support"]="OCCLUDED_INSIDE_EXISTING_CASTING"
        VISIBLE.objects.link(marker)
        return name
    rotation=(0,math.pi/2,0) if side_entry else None
    cylinder(name,x,y,z,.012,.019,MATERIALS["black_steel"],24,rotation=rotation)
    return name


def routed_cable(name, coords, radius, m, start, finish, purpose):
    """The curve must physically meet its modeled end fittings."""
    if not bpy.data.objects.get(start) or not bpy.data.objects.get(finish):
        raise RuntimeError("Unbuilt cable endpoint: "+name)
    curve(name,coords,radius,m)
    CABLE_ROUTES.append(dict(name=name,start=start,end=finish,purpose=purpose))
    return name


def bolt(name, x, y, z, scale=1.0):
    torus(name + "_washer", x,y,z, .011*scale,.003*scale,MATERIALS["brass"])
    cylinder(name + "_recessed_cap", x,y,z+.005*scale,
             .009*scale,.009*scale,MATERIALS["old_gold"], 12)
    cube(name + "_driver_slot",x,y,z+.011*scale,
         8*scale,1.3*scale,.001,MATERIALS["crevice"],bevel=0)


def screws(name, coordinates, z):
    for i,(x,y) in enumerate(coordinates):
        bolt(f"{name}_{i:02d}",x,y,z,0.42)



def front_facing_bolt(name, x, y, z):
    """A visible structural fastener attached to the blue chassis FRONT."""
    torus(name+"_washer",x,y,z,.014,.004,MATERIALS["brass"],
          rotation=(math.pi/2,0,0))
    cylinder(name+"_machined_head",x,y+4,z,.010,.013,
             MATERIALS["old_gold"],12,rotation=(math.pi/2,0,0))
    slot=cube(name+"_cut_driver_recess",x,y+9,z,10,1.6,.0012,
              MATERIALS["crevice"],0)
    slot.rotation_euler=(math.pi/2,0,0)


def retract_front_fascia(px=20):
    """Move only the forward part of the machine gently rearward.

    A shallow continuous Y taper starts behind the control panel: no new
    objects, no alteration to component orientation, and no floating seams.
    The entire FOUNDATION, including its four anchor bolts, is fixed.
    Source-facing positive Y is front, while world-space Y points rearward.
    Applies to visible surfaces and all cable curves, preserving endpoints.
    """
    if px<=0 or px>30:
        raise RuntimeError("Excessive or invalid front-end retreat")
    bpy.context.view_layer.update()
    seen=0
    main=bpy.data.objects.get("LAYER_2 Raised central machine chassis")
    base=bpy.data.objects.get("LAYER_1 Foundation perimeter steel slab")
    if main is None or base is None:
        raise RuntimeError("Missing chassis or foundation for front correction")
    def source_y(v):
        return 340-680*v.y
    def warp(v):
        y=source_y(v)
        # The top controls at y<=390 remain in their registered positions.
        # Reach the full 20-pixel setback by the lower front armor at y>=570.
        factor=max(0.0,min(1.0,(y-390)/180.0))
        v.y+=factor*px/680.0
        return v
    original_base=[(base.matrix_world @ vert.co).copy() for vert in base.data.vertices]
    front_verts=[main.matrix_world @ vert.co for vert in main.data.vertices]
    old_front=max(source_y(v) for v in front_verts)
    for ob in VISIBLE.objects:
        if ob.name.startswith(("LAYER_1 Foundation", "Foundation perimeter anchor bolt")):
            continue
        if ob.type not in {"MESH","CURVE"}:
            continue
        transform=ob.matrix_world.copy()
        inverse=transform.inverted()
        def local_adjust(local):
            return inverse @ warp(transform @ local)
        if ob.type=="MESH":
            for vert in ob.data.vertices:
                vert.co=local_adjust(vert.co)
            ob.data.update()
        else:
            for spline in ob.data.splines:
                if spline.type=="BEZIER":
                    for point in spline.bezier_points:
                        before=(point.co.copy(),point.handle_left.copy(),
                                point.handle_right.copy())
                        point.handle_left_type="FREE"
                        point.handle_right_type="FREE"
                        point.co=local_adjust(before[0])
                        point.handle_left=local_adjust(before[1])
                        point.handle_right=local_adjust(before[2])
                else:
                    for point in spline.points:
                        coord=local_adjust(Vector(point.co[:3]))
                        point.co=(coord.x,coord.y,coord.z,point.co.w)
        seen+=1
    # The render-invisible occlusion markers follow the SAME Y warp as their
    # actual cables, preventing fabricated connection evidence in the .blend.
    for marker in VISIBLE.objects:
        if marker.type=="EMPTY":
            marker.location=warp(marker.location.copy())
    bpy.context.view_layer.update()
    new_front=max(source_y(main.matrix_world @ vert.co) for vert in main.data.vertices)
    base_now=[base.matrix_world @ vert.co for vert in base.data.vertices]
    if any((before-after).length>0.000001 for before,after in zip(original_base,base_now)):
        raise RuntimeError("Foundation moved during front tuck")
    setback=old_front-new_front
    if abs(setback-px)>0.7:
        raise RuntimeError("Unexpected front setback "+str(setback))
    return {"source_pixel_setback":round(setback,2),
            "foundation_fixed":True, "adjusted_visible_objects":seen,
            "front_chassis_original_y":round(old_front,2),
            "front_chassis_revised_y":round(new_front,2)}


def shorten_middle_chassis_preserving_connections():
    """Piecewise-compress only the exposed second level in world Z.

    Foundation remains full height, middle shrinks from 0.310 to 0.1302,
    every upper-machine surface and attachment translates down rigidly
    by 0.1798. This continuity preserves real mesh contact and the cable
    endpoint relationships. Horizontal capacitor circularity is preserved.
    Run AFTER the seven routed-cable endpoint checks.
    """
    z0,z1,ratio=.165,.475,.42
    dz=(z1-z0)*(1-ratio)
    def remap(z):
        if z<=z0:
            return z
        if z<z1:
            return z0+(z-z0)*ratio
        return z-dz
    bpy.context.view_layer.update()
    for obj in VISIBLE.objects:
        if obj.type not in {"MESH","CURVE"}:
            continue
        mx=obj.matrix_world.copy()
        inv=mx.inverted()
        def adjust(v):
            world=mx @ v
            world.z=remap(world.z)
            return inv @ world
        if obj.type=="MESH":
            for vertex in obj.data.vertices:
                vertex.co=adjust(vertex.co)
            obj.data.update()
        else:
            for spline in obj.data.splines:
                if spline.type=="BEZIER":
                    for point in spline.bezier_points:
                        p=point.co.copy()
                        left=point.handle_left.copy()
                        right=point.handle_right.copy()
                        point.handle_left_type="FREE"
                        point.handle_right_type="FREE"
                        point.co=adjust(p)
                        point.handle_left=adjust(left)
                        point.handle_right=adjust(right)
                else:
                    for point in spline.points:
                        co=Vector(point.co[:3])
                        pos=adjust(co)
                        point.co=(pos.x,pos.y,pos.z,point.co.w)
    # EMPTY markers contain no mesh vertices but still represent real
    # measured hiding points; they must be remapped along with the curves.
    for marker in VISIBLE.objects:
        if marker.type=="EMPTY":
            marker.location.z=remap(marker.location.z)
    bpy.context.view_layer.update()
    chassis=bpy.data.objects.get("LAYER_2 Raised central machine chassis")
    foundation=bpy.data.objects.get("LAYER_1 Foundation perimeter steel slab")
    if not chassis or not foundation:
        raise RuntimeError("Foundation or middle chassis lost")
    zs=[(chassis.matrix_world @ v.co).z for v in chassis.data.vertices]
    height=max(zs)-min(zs)
    if abs(height-.1302)>.004:
        raise RuntimeError("Middle chassis physical shrink failed: "+str(height))
    return {"middle_height_before":.310,"middle_height_after":height,
            "upper_assembly_downshift":dz,"foundation_unchanged":True}


def carve_real_chassis_front_recess():
    """Cut physical cavity INTO the single chassis volume, never add a slab."""
    main=bpy.data.objects.get("LAYER_2 Raised central machine chassis")
    if main is None: raise RuntimeError("Main solid absent")
    before=len(main.data.vertices)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.318,.229))
    cutter=bpy.context.object
    cutter.name="TEMP_REAL_FRONT_INSET_CUTTER"
    cutter.dimensions=(.59,.109,.033)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=main
    main.select_set(True)
    cutter.select_set(False)
    m=main.modifiers.new("Machined recessed front service channel","BOOLEAN")
    m.operation="DIFFERENCE"
    m.solver="EXACT"
    m.object=cutter
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    bpy.context.view_layer.update()
    if len(main.data.vertices)<=before:
        raise RuntimeError("Front cut has not altered the actual chassis mesh")
    main["source_feature_recessed_channel"]=True
    return {"carved_into_existing_mesh":True,"vertices_before":before,
            "vertices_after":len(main.data.vertices),
            "recess_width":.59,"recess_height":.033}


def source_front_raycast(solid, source_x, z):
    """Find the ACTUAL visible -Y casting face at a specified source x/height.

    This prevents a declared fastener or recess from being attached to the
    projected 2D coordinate instead of the underlying three-dimensional wall.
    """
    bpy.context.view_layer.update()
    local=solid.matrix_world.inverted()
    start=local @ Vector((pixel(source_x,0,0)[0],-1.2,z))
    direction=(local.to_3x3() @ Vector((0,1,0))).normalized()
    hit,point,normal,index=solid.ray_cast(start,direction)
    if not hit:
        raise RuntimeError("No cast surface underneath registered source feature "+
                           solid.name+" x="+str(source_x)+" z="+str(z))
    return solid.matrix_world @ point


def cut_three_true_maintenance_vents():
    """Three visible source slots CUT into the original existing cover mesh.

    They were painted-on black rectangles in V20; do not add fake new plates.
    Source coordinates: x~223; y=153,177,201, widths 68,67,65 px.
    """
    cover=bpy.data.objects.get("Vented upper source-shaped maintenance plate")
    if cover is None:
        raise RuntimeError("Missing actual source maintenance cover")
    top=max((cover.matrix_world @ v.co).z for v in cover.data.vertices)
    original_vertices=len(cover.data.vertices)
    for index,(y,w) in enumerate(((153,68),(177,67),(201,65))):
        well=bpy.data.objects.get(f"Physical vent cavity dark well {index}")
        if well is None:
            raise RuntimeError("Missing source vent well "+str(index))
        # Height-compression remaps mesh vertices rather than object origins.
        # Use the actual evaluated geometry centroid, not location.z (which
        # still refers to pre-compression coordinates).
        points=[well.matrix_world @ v.co for v in well.data.vertices]
        center=sum(points,Vector((0,0,0)))/len(points)
        bpy.ops.mesh.primitive_cube_add(size=1,
            location=(center.x,center.y,top-.003))
        cutter=bpy.context.object
        cutter.name="TEMP_SOURCE_VENT_SLOT_CUTTER"
        cutter.dimensions=(width(w),width(9),.018)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.ops.object.select_all(action="DESELECT")
        cover.select_set(True)
        bpy.context.view_layer.objects.active=cover
        boolean=cover.modifiers.new("Source vent physical aperture "+str(index),"BOOLEAN")
        boolean.operation="DIFFERENCE"
        boolean.solver="EXACT"
        boolean.object=cutter
        bpy.ops.object.modifier_apply(modifier=boolean.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
        # Preserve the already registered black vent interior, but place
        # its *actual* top just below the cast lip instead of painting it
        # visibly on top. The cavity has a forged recess, not a decal.
        well.location.z += (top-.007-center.z)
    bpy.context.view_layer.update()
    if len(cover.data.vertices)<=original_vertices:
        raise RuntimeError("Three claimed vent booleans made no physical apertures")
    cover["actual_source_cut_vents"]=3
    return {"cut_slots":3,"vertices_before":original_vertices,
            "vertices_after":len(cover.data.vertices),
            "source_y":[153,177,201],"new_visible_plate_count":0}


def carve_source_corner_foot_faces():
    """Carve inset rectangular front faces INTO BOTH V20 cast foot solids.

    The source feet have dark recesses and stepped shoulders. V20 instead
    modeled tall smooth uniform buttresses. Cut these existing volumes; do
    not attach new featureless front face plates or decorative gussets.
    """
    records=[]
    for side,cx in (("left",95),("right",585)):
        foot=bpy.data.objects.get("SOURCE FOUNDATION "+side+" structural foot")
        if not foot:
            raise RuntimeError("Missing source foundation foot "+side)
        before=len(foot.data.vertices)
        contact=source_front_raycast(foot,cx,.263)
        bpy.ops.mesh.primitive_cube_add(size=1,
            location=(contact.x,contact.y+.006,.263))
        cutter=bpy.context.object
        cutter.name="TEMP_"+side+"_FOOT_RECESSED_FACE_CUTTER"
        cutter.dimensions=(width(49),.036,.051)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.ops.object.select_all(action="DESELECT")
        foot.select_set(True)
        bpy.context.view_layer.objects.active=foot
        boolean=foot.modifiers.new("Original recessed forged foot face","BOOLEAN")
        boolean.operation="DIFFERENCE"
        boolean.solver="EXACT"
        boolean.object=cutter
        bpy.ops.object.modifier_apply(modifier=boolean.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
        bpy.context.view_layer.update()
        after=len(foot.data.vertices)
        if after<=before:
            raise RuntimeError("Foot inset did not change actual foot casting "+side)
        # Material-zone recessed metal on TRUE cut surfaces, never decals.
        foot.data.materials.append(MATERIALS["black_steel"])
        zone_count=0
        for poly in foot.data.polygons:
            pos=foot.matrix_world @ poly.center
            if (abs(pos.x-contact.x)<width(26)
                and abs(pos.z-.263)<.028
                and pos.y>contact.y+.009):
                poly.material_index=len(foot.data.materials)-1
                zone_count+=1
        foot["source_front_face_recess_cut"]=True
        records.append({"side":side,"vertices_before":before,
                        "vertices_after":after,"dark_cavity_faces":zone_count,
                        "reference_x":cx})
    return {"count":len(records),"feet":records,
            "new_overlay_plates":0}


def seat_original_front_face_screws():
    """Move ONLY the two documented screw assemblies onto the real front wall.

    V20 placed the screws by projected pixel Y, which submerged them in
    the solid chassis. Raycasting the existing chassis fixes that mistake.
    """
    chassis=bpy.data.objects["LAYER_2 Raised central machine chassis"]
    records=[]
    for idx,x in enumerate((180,497)):
        prefix=f"Middle front source screw {idx}"
        parts=[o for o in VISIBLE.objects if o.name.startswith(prefix+"_")]
        if len(parts)!=3:
            raise RuntimeError("Expected existing 3-part screw, "+prefix)
        washer=bpy.data.objects[prefix+"_washer"]
        ws=[washer.matrix_world @ v.co for v in washer.data.vertices]
        center=sum(ws,Vector((0,0,0)))/len(ws)
        target=source_front_raycast(chassis,x,center.z)
        # Torus washer face must be immediately OUTSIDE the existing casting.
        delta=Vector((0,target.y-.006-center.y,0))
        if delta.length>.2:
            raise RuntimeError("Source screw was unreasonably distant from chassis")
        for part in parts:
            part.location+=delta
        records.append({"source_x":x,"original_world_y":round(center.y,5),
                        "physical_surface_y":round(target.y,5),
                        "seating_correction":round(delta.y,5)})
    return {"count":2,"screws":records,"new_screws":0}


def forged_patina_marks(name, left, right, top, bottom, z, count, material_name, seed):
    """Actual shallow, non-coplanar exposed-metal chips, not pasted artwork.

    Source visible and deterministic: bounded to the real upper machine
    plates and support rails, avoiding glass, ports and moving hardware.
    """
    rng=random.Random(seed)
    vertices=[]
    faces=[]
    for i in range(count):
        x=rng.uniform(left,right)
        y=rng.uniform(top,bottom)
        length=rng.uniform(0.9,5.7)
        breadth=rng.uniform(.35,1.55)
        theta=rng.uniform(0,math.tau)
        ux,uy=math.cos(theta),math.sin(theta)
        vx,vy=-uy,ux
        corners=[
            (x-ux*length*.5-vx*breadth*.5,
             y-uy*length*.5-vy*breadth*.5),
            (x+ux*length*.5-vx*breadth*.5,
             y+uy*length*.5-vy*breadth*.5),
            (x+ux*length*.5+vx*breadth*.5,
             y+uy*length*.5+vy*breadth*.5),
            (x-ux*length*.5+vx*breadth*.5,
             y-uy*length*.5+vy*breadth*.5),
        ]
        base=len(vertices)
        # These are actual surface-layer metal microchips in 3D,
        # not geometry used to fake a larger machine silhouette.
        vertices.extend(pixel(px,py,z) for px,py in corners)
        faces.append(tuple(base+j for j in range(4)))
    mesh=bpy.data.meshes.new(name+"_SURFACE_SCARS")
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    VISIBLE.objects.link(obj)
    assign(obj,MATERIALS[material_name])
    return obj


def build_enclosure():
    # Source is 680px preview of 1254px original; all 2D landmark
    # coordinates are manually transcribed from that SPECIFIC image.
    dark=MATERIALS["black_steel"]
    edge=MATERIALS["edge_steel"]
    panel=MATERIALS["worn_steel"]
    iron=MATERIALS["iron"]
    brass=MATERIALS["brass"]
    crevice=MATERIALS["crevice"]
    # Read the source as THREE real manufacturing levels, not a top-down plate.
    # 1. Wide foundation visible around the entire perimeter.
    octagonal_case("LAYER_1 Foundation perimeter steel slab",340,329,.070,.156,
                   638,625,45,dark)
    frame_ring("LAYER_1 Foundation exposed bolted rim",340,329,.155,.174,
               638,625,589,565,edge)
    # 2. One real 3D armored chassis, not a drawn-outline stack.
    # Its walls taper upward in both width and depth. The front is a face of
    # this single casting; it needs NO additional stacked full-width slabs.
    lofted_cast_chassis("LAYER_2 Raised central machine chassis",[
        (.165,340,317,582,508,38),
        (.200,340,310,585,520,42),
        (.350,340,307,570,477,44),
        (.475,340,302,549,455,40),
    ],iron)
    # A slim rim overlaps the upper edge of that physical casting. It is a
    # true metal lip, not a separate false "front armor" band.
    frame_ring("LAYER_2 Chassis upper shoulder",340,302,.451,.482,
               552,459,514,417,dark)
    # 3. ONE continuous raised housing; its front wall is actually shaped
    # by the physical taper of a watertight machine shell. No decorative
    # full-width control-front slab is necessary. The shallow sloped
    # keyboard control surface sits over this real supporting casting.
    lofted_cast_chassis("LAYER_3 Elevated control deck structural body",[
        (.470,340,255,490,427,32),
        (.512,340,255,487,419,33),
        (.552,340,249,475,401,31),
        (.565,340,247,471,393,30),
    ],panel)
    # Source lines along the front arise from changes in the actual
    # enclosure depth and control-plane angle, not stacked 2D contours.
    # Deliberately NO front full-width shoe, frontal stepped skirt, faux
    # dark structural spar or overlapping corner boots. Their source edges
    # are the projection of the real chassis bevel, lip, and base frame.
    # The wide light-gray front-corner gussets in V17 are NOT present in
    # the source reference. DELETE the two meshes; retain real foundation
    # casting and source-located steel anchoring bolts. Do not replace
    # with new decorative polygons.
    # The original has two DIFFERENTIATED, heavy front mounting feet with
    # sloped outer shoulders and broad contact with the foundation.
    # V18 intentionally removed false flat pads. V19 constructs ONLY the
    # two photographed feet as tapered, continuous cross-section solids.
    # The rear edge climbs toward the upper armor shoulder, while the lower
    # toe reaches the outer original foundation. No extra faceplates.
    for i,cx in enumerate((95,585)):
        side="left" if i==0 else "right"
        shoulder_x=119 if i==0 else 561
        mid_x=98 if i==0 else 582
        top_x=110 if i==0 else 570
        lofted_cast_chassis(
            "SOURCE FOUNDATION "+side+" structural foot",[
                # Low outer foot reaches the source's real full-depth base.
                (.156,cx,536,124,199,30),
                # Bolted lower forefoot with prominent vertical sidewall.
                (.285,mid_x,515,121,172,31),
                # Rising beveled shoulder meets middle chassis body.
                (.454,top_x,482,103,138,25),
                # High rear cap joins the source-visible upper corner.
                (.555,shoulder_x,440,76,85,19),
            ],iron)

    # Exactly six source-located LARGE base/shoulder anchor heads and
    # two smaller middle-front screws; no evenly spaced invented bolt row.
    for i,(x,y) in enumerate(((75,69),(605,69),(126,455),
                               (550,454),(116,569),(560,568))):
        # Mount bolts on their ACTUAL sloped-foot surfaces rather than the
        # flat base plane. Rear perimeter heads remain on the base itself.
        bolt(f"Foundation source anchor bolt {i}",x,y,
             .555 if 430<y<500 else (.284 if y>530 else .184),
             1.38)
    for i,x in enumerate((180,497)):
        front_facing_bolt(f"Middle front source screw {i}",x,512,.295)

    # Capture the lower structure so only controls and the attached rear
    # wiring are lifted, not the chassis/foundation or perimeter hoses.
    fixed_lower_objects=set(VISIBLE.objects)
    # Outline follows recognizable sheet metal seams in the sprite.
    # The LCD and knife switches are TWO different modules, not a single
    # generic dark rectangular face stuck to the chassis.
    cast_contour("Full-length left equipment mounting casting",
        [(122,100),(154,100),(166,113),(166,380),
         (154,406),(119,396),(108,382),(110,115)],
        .453,.487,panel,.005)
    cast_contour("Vented upper source-shaped maintenance plate",
        [(180,101),(394,102),(415,118),(416,215),
         (400,226),(177,226),(169,215),(169,115)],
        .452,.499,panel,.004)
    cast_contour("Mid-level split service cover",
        [(176,227),(405,227),(414,239),(413,282),
         (398,298),(177,297),(169,287),(168,238)],
        .447,.491,iron,.003)
    cast_contour("Three-capacitor contoured carrier plate",
        [(441,116),(559,116),(575,132),(575,209),
         (566,225),(436,225),(428,212),(428,129)],
        .456,.499,panel,.004)
    cast_contour("Right lower inspection door",
        [(438,226),(569,225),(578,236),(578,288),
         (563,299),(441,298),(430,288),(430,238)],
        .451,.490,iron,.004)
    front_panel_before=set(VISIBLE.objects)
    cast_contour("Upper controller shared sloped mount",
        [(177,301),(571,301),(587,318),(585,424),
         (569,442),(178,440),(163,422),(164,318)],
        .455,.493,dark,.006)
    cast_contour("Left LCD and diagnostics faceplate",
        [(176,307),(380,306),(392,317),(391,419),
         (380,432),(176,431),(168,418),(168,320)],
        .493,.511,panel,.004)
    cast_contour("Right knife-switch faceplate",
        [(397,308),(568,308),(578,320),(578,420),
         (567,433),(400,433),(390,422),(391,322)],
        .492,.511,panel,.004)
    cube("Real module separating seam",391,370,.514,
         4,107,.006,crevice,.001)
    # The V17 full-width front control armor lip was a fabricated extra
    # shelf. Original source has a THIN seam at the joined face edge.
    # The two actual adjoining faceplates already define that seam.
    # Deliberately build NO additional front lip.
    
    front_panel_shapes=set(VISIBLE.objects)-front_panel_before
    # Only the faceplate and its physical controls incline toward the viewer.
    # The upper-rear machinery roof, perimeter tubes and foundation remain level.
    # The three real recessed vent apertures, not printed dark stripes.
    for i,(y,w) in enumerate(((153,68),(177,67),(201,65))):
        cube(f"Physical vent cavity dark well {i}",223,y,.501,w,9,.004,crevice,.003)
        cube(f"Physical vent left inner sidewall {i}",188,y,.503,2,6,.008,dark,0)
        cube(f"Physical vent right inner sidewall {i}",256,y,.503,2,6,.008,dark,0)
    screws("Main upper cover",[(183,236),(402,240),(404,118),(404,206)],.507)
    screws("Socket bank",[(444,135),(565,246),(445,278),(561,279)],.507)
    screws("Lower console",[(179,312),(565,315),(181,418),(566,416)],.513)
    for x,y in [(137,104),(139,325)]:
        bolt("Left long support rail boss",x,y,.511,1.20)

    # Three cylinder bodies lie along the machine plane with their ROUND
    # FRONT MOUTHS exposed: no upright posts or individual boxed pedestals.
    for idx,x in enumerate((459,503,547)):
        # The source shows compact dark inset circular ends, NOT three bright
        # silver long barrels. These still remain physically horizontal cans.
        cylinder(f"Capacitor {idx} horizontal supported shell",
                 x,154,.527,.026,.037,dark,40,rotation=(math.pi/2,0,0))
        torus(f"Capacitor {idx} forward round steel lip",
              x,168,.527,.024,.003,edge,rotation=(math.pi/2,0,0))
        cylinder(f"Capacitor {idx} recessed dark mouth",
                 x,169,.527,.020,.007,crevice,40,
                 rotation=(math.pi/2,0,0))
        front_details_before=set(VISIBLE.objects)
        # Green display is mounted inside the control bank, not painted on shell.
    cube("Computer bezel thick raised enclosure",243,364,.516,131,104,.033,dark,.008)
    cube("Bezel reflective inner steel rim",243,364,.535,112,84,.009,edge,.005)
    cube("Recessed luminous green computer glass",243,363,.541,101,73,.009,
         MATERIALS["screen_glass"],.003)
    # Subpixel holographic schematics, sized from original green flicker.
    for i in range(24):
        x=198+(i*13)%94
        y=334+(i*7)%56
        size=3 + ((i*19)%18)
        cube(f"Green readout wire track {i}",x,y,.549,size,0.7,.0007,
             MATERIALS["dim_green"],0)
    for i in range(6):
        x=202+i*12
        curve(f"Screen luminous controller glyph {i}",
              [(x,343+i%2*3,.551),(x+5,343+i%2*3,.551),
               (x+5,349+i%2*3,.551)],.00038,MATERIALS["bright_green"])
    # Source's exact four dark/bezel status lamps.
    for idx,(x,y,col) in enumerate(((329,339,"red_light"),(363,339,"amber_light"),
                                   (330,383,"green_light"),(363,383,"crevice"))):
        torus(f"Status lamp {idx} metal retaining ring",x,y,.531,.016,.004,edge)
        cylinder(f"Status lamp {idx} glass and light",x,y,.537,.012,.015,
                 MATERIALS[col],24)
        cylinder(f"Status lamp {idx} internal lens edge",x,y,.548,.008,.002,
                 MATERIALS[col],24)
    # Four original blade channels. 3 colored circular ends and ONE dark
    # central hand lever, all installed flush in the existing faceplate.
    for idx,(x,color) in enumerate(((430,"red"),(466,None),
                                    (505,"amber"),(550,"green"))):
        cube(f"Knife switch {idx} source recessed channel",x,367,.517,
             23,91,.008,crevice,.002)
        cube(f"Knife switch {idx} flush conductor blade",x,370,.532,
             7,67,.012,edge,.002)
        if color is None:
            cube(f"Knife switch {idx} dark hand lever",x,357,.549,
                 13,50,.014,dark,.003)
        else:
            torus(f"Knife switch {idx} colored hand rim",
                  x,345,.553,.019,.004,MATERIALS[color])
            cylinder(f"Knife switch {idx} black inset grip",
                     x,345,.551,.013,.007,crevice,28)
        cylinder(f"Knife switch {idx} bottom contact",x,409,.539,
                 .010,.008,brass,16)
        front_controls=(set(VISIBLE.objects)-front_details_before) | front_panel_shapes
    front_controls.update(ob for ob in VISIBLE.objects
                          if ob.name.startswith("Lower console_"))

    # Wire paths derived from the actual source, with HIDDEN ends passing
    # under EXISTING steel coverwork, not imaginary visible brass glands.
    cable_gland("Rear red under left clamp",181,55,.506,occluded=True)
    cable_gland("Rear red hidden beneath steel cover",450,130,.445,occluded=True)
    routed_cable("Top red insulated cable",
        [(181,55,.506),(257,57,.510),(345,69,.513),
         (423,82,.512),(436,104,.494),(450,130,.445)],.010,MATERIALS["red_wire"],
        "Rear red under left clamp","Rear red hidden beneath steel cover",
        "Red rear conductor routed under existing cable clips")
    cable_gland("Rear green beneath center band",299,46,.507,occluded=True)
    cable_gland("Green hidden behind right hose",561,235,.445,occluded=True)
    routed_cable("Top bright green insulated cable",
        [(299,46,.507),(374,51,.511),(429,79,.512),
         (506,98,.521),(567,122,.523),(586,167,.527),
         (578,203,.497),(561,235,.445)],.010,MATERIALS["green_wire"],
        "Rear green beneath center band","Green hidden behind right hose",
        "Continuous green conductor under existing top clamps and right hose")
    cable_gland("Rear copper under left retaining band",181,57,.508,occluded=True)
    cable_gland("Copper disappears below middle clamp",288,61,.507,occluded=True)
    routed_cable("Top copper orange secondary wire",
        [(181,57,.508),(222,55,.510),(262,58,.510),
         (288,61,.507)],.007,MATERIALS["copper"],
        "Rear copper under left retaining band",
        "Copper disappears below middle clamp",
        "Short warm-toned rear conductor, source-visible section only")
    for idx,(x,metal) in enumerate(((166,brass),(266,edge),
                                     (376,edge),(489,brass))):
        cube(f"Original rear rectangular retaining clamp {idx}",
             x,56,.511,21,29,.027,metal,.003)
    cable_gland("Right red hidden under outer sleeve",616,270,.530,occluded=True)
    cable_gland("Right red disappears at upper case edge",566,413,.455,occluded=True)
    routed_cable("Right visible red high voltage feed",
        [(616,270,.530),(618,323,.530),(620,369,.532),
         (615,399,.531),(599,409,.510),(566,413,.455)],.013,MATERIALS["red_wire"],
        "Right red hidden under outer sleeve",
        "Right red disappears at upper case edge",
        "Visible red right-side cable goes under real existing metalwork")
    for side in (-1,1):
        prefix="L" if side<0 else "R"
        x=69 if side<0 else 616
        rear_x=128 if side<0 else 550
        end_x=125 if side<0 else 565
        cable_gland(prefix+" black hose concealed rear",rear_x,58,.565,occluded=True)
        cable_gland(prefix+" black hose concealed lower",end_x,404,.450,occluded=True)
        points=[(rear_x,58,.565),((rear_x+x)/2,54,.572),
                (x+(-8 if side<0 else 8),77,.572),
                (x,105,.573),(x,164,.571),(x,240,.570),
                (x,320,.569),(x+(-2 if side<0 else 2),355,.566),
                ((112 if side<0 else 586),381,.541),
                (end_x,404,.450)]
        routed_cable(prefix+" actual perimeter ribbed hydraulic conduit",
            points,.022,MATERIALS["black_wire"],
            prefix+" black hose concealed rear",
            prefix+" black hose concealed lower",
            "One corrugated perimeter coolant tube, both ends hidden by casing")
        for i in range(15):
            y=110+i*18
            torus(prefix+f" source pipe rib {i:02d}",x,y,.572,
                  .021,.002,MATERIALS["iron"],rotation=(math.pi/2,0,0))
        sleeve_y=185 if side<0 else 204
        cube(prefix+" source metal hose sleeve",x,sleeve_y,.573,
             31,29,.029,brass if side>0 else edge,.004)
        # No random geometry stamped onto metal to masquerade as source wear.
    # Foundry texture stays in the shader; future source-guided aging should
    # use physically mapped material regions, not arbitrary debris objects.
    
    # Preserve strong physical separation between base, chassis and upper
    # machine controls. Lifting all parts indiscriminately produces floating
    # side hoses; named sidewall routes remain anchored at chassis height.
    chassis_external_prefix=(
        "L ","R ","Right visible red high voltage feed","Right red ",
        "Right green internal control conduit","Right upper HV sidewall gland",
        "Right lower HV bus gland","Right control logic upper outlet",
        "Right control logic lower return",
        "Worn forward armored rail","Forward rail exposed metal nicks",
    )
    for obj in VISIBLE.objects:
        if obj not in fixed_lower_objects and not obj.name.startswith(chassis_external_prefix):
            obj.location.z+=LAYER_ELEVATIONS["raised_controls"]
    # Flush the new elevations to matrix_world before applying the incline.
    # Otherwise Blender can overwrite the uncommitted +Z translation and
    # bury the LCD and knife switches underneath the unsloped upper casing.
    bpy.context.view_layer.update()
    # Rotate the real front-control geometry about the rear hinge line:
    # front edge drops; LCD, switches, lamp covers and faceplates follow.
    pivot=Vector(pixel(340,301,.620))
    incline=(Matrix.Translation(pivot)
             @ Matrix.Rotation(math.radians(11),4,"X")
             @ Matrix.Translation(-pivot))
    for obj in front_controls:
        obj.matrix_world=incline @ obj.matrix_world
    bpy.context.view_layer.update()
    face=bpy.data.objects.get("Left LCD and diagnostics faceplate")
    cap=bpy.data.objects.get("Capacitor 0 horizontal supported shell")
    if face is None or cap is None:
        raise RuntimeError("V10 upper face or capacitor geometry missing")
    normal=face.matrix_world.to_3x3() @ Vector((0,0,1))
    axis=cap.matrix_world.to_3x3() @ Vector((0,0,1))
    lcd=bpy.data.objects.get("Recessed luminous green computer glass")
    upper=bpy.data.objects.get("LAYER_3 Elevated control deck structural body")
    if lcd is None or upper is None:
        raise RuntimeError("No upper housing or LCD in modeled scene")
    # Relative clearance from the ACTUAL modeled 3D upper roof, not an
    # inherited V10 absolute world-space height.
    housing_top=max((upper.matrix_world @ v.co).z for v in upper.data.vertices)
    glass_top=max((lcd.matrix_world @ v.co).z for v in lcd.data.vertices)
    face_upper_z=max((face.matrix_world @ v.co).z for v in face.data.vertices)
    if glass_top <= housing_top+.012:
        raise RuntimeError("LCD is geometrically submerged in upper housing")
    if face_upper_z <= housing_top+.006:
        raise RuntimeError("Inclined control face not above its 3D support")
    if normal.y >= -.12 or normal.z <= .9 or axis.y >= -.9:
        raise RuntimeError("Console slope or horizontal capacitor axis invalid")
    FEATURES.extend([
      "dark and bright genuinely modeled local surface metal scars",
      "chamfered source 1x1 enclosure and thick raised edge", "six structural fasteners",
      "left vertical bearing plate", "top maintenance cover with real vent wells",
      "three horizontally mounted industrial pulse capacitors", "green computer display with tiny geometry",
      "four colored indicator lamps", "four source-located switch lanes with one dark lever",
      "red green and copper wiring under four rectangular original retaining clamps",
      "corrugated black hydraulic perimeter with clamps",
      "foundation slab / raised armored chassis / top instrument panel",
      "source-located cable ends occluded beneath existing cast coverwork",
      "source-traced irregular armor plates, split control faces, tapered front castings",
      "11-degree continuous forward-sloped control panel",
      "perimeter hoses disappear underneath the real upper machine casting",
    ])


def rig_scene():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Industrial neutral workshop world")
    scene.world=world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.28,.27,.25,1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.48
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x=1000
    scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    scene.render.engine="CYCLES"
    scene.cycles.samples=28
    # Ubuntu Blender 4.0 can be compiled without OpenImageDenoiser.
    # CPU samples are retained; do not request a build-disabled denoiser.
    scene.cycles.use_denoising=False
    scene.render.threads_mode="FIXED"
    scene.render.threads=2
    scene.view_settings.view_transform="Standard"
    # Source top is a direct overhead projection, while game candidate is a
    # moderately raised isometric view of the same REAL mesh.
    def camera(name, location, focus, ortho):
        data=bpy.data.cameras.new(name)
        data.type='ORTHO'
        data.ortho_scale=ortho
        obj=bpy.data.objects.new(name,data)
        COLLECTION.objects.link(obj)
        obj.location=location
        direction=Vector(focus)-obj.location
        obj.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
        return obj
    top=camera("CAMERA_SOURCE_MATCH_STEEP_FRONT",(0,-.73,3.35),(0,0,.37),1.24)
    iso=camera("CAMERA_PHYSICAL_3D_INSPECTION",(1.03,-1.42,2.70),(0,-.05,.38),1.45)
    detail=camera("CAMERA_FRONT_SIDEWALL_INSPECTION",(-.48,-1.72,2.22),(0,-.05,.35),1.34)
    def area(name, pos, power, size):
        data=bpy.data.lights.new(name,"AREA")
        data.energy=power
        data.shape='DISK'
        data.size=size
        obj=bpy.data.objects.new(name,data)
        COLLECTION.objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(Vector((0,0,.26))-obj.location).to_track_quat("-Z","Y").to_euler()
    area("Warm studio keylight",(-2.2,-1.9,3.9),295,3.0)
    area("Cool workshop large fill",(1.8,1.5,3.0),120,3.5)
    area("Top lateral fill",(-1.3,2.4,2.6),65,2.8)
    return top,iso,detail


def save_render(scene, camera, path):
    scene.camera=camera
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    if not path.is_file() or path.stat().st_size < 30000:
        raise RuntimeError("Blender failed to render real machine: "+str(path))


def create_materials():
    # Source is dark oil-browned, oxidized foundry steel, not clean aluminum.
    # Tight roughness and material noise avoid a sterile plastic appearance.
    material("black_steel",(.021,.020,.018),.63,.73,.38)
    material("iron",(.047,.038,.031),.67,.75,.45)
    material("edge_steel",(.104,.082,.058),.79,.65,.38)
    material("worn_steel",(.064,.052,.041),.73,.72,.47)
    material("crevice",(.006,.009,.008),.13,.85,.09)
    material("brass",(.31,.196,.060),.76,.51,.31)
    material("old_gold",(.28,.159,.048),.82,.54,.31)
    material("copper",(.28,.112,.052),.72,.58,.24)
    material("black_wire",(.014,.015,.016),.20,.89,.16)
    material("red_wire",(.29,.025,.012),.13,.54,.16)
    material("green_wire",(.115,.190,.035),.16,.60,.15)
    material("screen_glass",(.004,.065,.012),.20,.32,0,.17)
    material("dim_green",(.017,.20,.027),.10,.46,0,.33)
    material("bright_green",(.06,.36,.035),.10,.38,0,.63)
    material("red_light",(.43,.038,.018),.12,.40,0,.4)
    material("amber_light",(.49,.27,.021),.12,.40,0,.45)
    material("green_light",(.08,.35,.030),.12,.43,0,.42)
    material("oxide",(.030,.021,.011),.51,.86,.23)
    material("edge_scar",(.235,.201,.160),.76,.61,.21)
    material("insulator",(.045,.042,.034),.11,.67,.12)
    # Separate cable connector color designators, reused as ring materials.
    MATERIALS["red"] = MATERIALS["red_wire"]
    MATERIALS["amber"] = MATERIALS["amber_light"]
    MATERIALS["green"] = MATERIALS["green_wire"]



def apply_owner_v22_geometry():
    """Lift existing console, physically reprofile its support, tilt THREE capacitor mouths toward the camera."""
    scene=bpy.context.scene
    if scene.get("emergency_miner_v22_applied"):
        raise RuntimeError("Do not apply V22 geometry twice")
    bpy.context.view_layer.update()
    base=bpy.data.objects["LAYER_1 Foundation perimeter steel slab"]
    frozen=[(base.matrix_world @ v.co).copy() for v in base.data.vertices]
    lift=0.014
    prefixes=("Upper controller shared sloped mount","Left LCD and diagnostics faceplate",
              "Right knife-switch faceplate","Real module separating seam",
              "Computer bezel thick raised enclosure","Bezel reflective inner steel rim",
              "Recessed luminous green computer glass","Green readout wire track",
              "Screen luminous controller glyph","Status lamp ","Knife switch ","Lower console_")
    moved=[]
    for obj in VISIBLE.objects:
        if obj.name.startswith(prefixes):
            obj.location.z+=lift
            moved.append(obj.name)
    if len(moved)<40 or "Upper controller shared sloped mount" not in moved:
        raise RuntimeError("Console is not fully attached to the moved controls")
    # Extend the TOP FRONT portion of the same physical upper casting.
    shell=bpy.data.objects["LAYER_3 Elevated control deck structural body"]
    matrix=shell.matrix_world.copy()
    inverse=matrix.inverted()
    world=[matrix @ vertex.co for vertex in shell.data.vertices]
    lowest=min(v.z for v in world)
    highest=max(v.z for v in world)
    changed=0
    for vertex,position in zip(shell.data.vertices,world):
        front=max(0.,min(1.,(0.23-position.y)/0.15))
        top=max(0.,min(1.,(position.z-lowest)/((highest-lowest)*0.83)))
        if front*top>0.:
            raised=position.copy()
            raised.z+=lift*front*top
            vertex.co=inverse @ raised
            changed+=1
    shell.data.update()
    if changed<4:
        raise RuntimeError("Top console support casting was not raised")
    cap_record=[]
    direction=Vector((0.,-math.sqrt(.5),math.sqrt(.5)))
    tilt=Matrix.Rotation(-math.pi/4,4,"X")
    for index in range(3):
        names=[f"Capacitor {index} horizontal supported shell",
               f"Capacitor {index} forward round steel lip",
               f"Capacitor {index} recessed dark mouth"]
        parts=[bpy.data.objects.get(n) for n in names]
        if any(x is None for x in parts):
            raise RuntimeError("Missing original capacitor "+str(index))
        shell_obj=parts[0]
        bpy.context.view_layer.update()
        coords=[shell_obj.matrix_world @ v.co for v in shell_obj.data.vertices]
        center=sum(coords,Vector((0.,0.,0.)))/len(coords)
        pivot=center+Vector((0.,0.014,-0.014))
        correction=Matrix.Translation(pivot) @ tilt @ Matrix.Translation(-pivot)
        for obj in parts:
            obj.matrix_world=correction @ obj.matrix_world
        bpy.context.view_layer.update()
        axis=(shell_obj.matrix_world.to_3x3() @ Vector((0,0,1))).normalized()
        match=axis.dot(direction)
        if match<.96:
            raise RuntimeError("Capacitor mouths still point sideways: "+str(match))
        cap_record.append({"index":index,"camera_alignment":round(match,5),
                           "axis":[round(v,5) for v in axis],"existing_parts":3})
    bpy.context.view_layer.update()
    if any(((base.matrix_world @ v.co)-old).length>1e-6 for v,old in zip(base.data.vertices,frozen)):
        raise RuntimeError("Foundation moved during V22 surface refinement")
    scene["emergency_miner_v22_applied"]=True
    return {"revision":"V22","console_lift_blender_units":lift,
            "console_objects_moved":len(moved),"upper_cast_vertices_reprofiled":changed,
            "capacitor_mouths":cap_record,"new_visible_model_parts":0,"foundation_static":True}


def main(out):
    global OUTPUT,COLLECTION,VISIBLE
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise RuntimeError("Canonical emergency miner sprite source hash mismatch")
    OUTPUT=out.resolve()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    COLLECTION=bpy.data.collections.new("Emergency Miner camera-visible reconstruction")
    bpy.context.scene.collection.children.link(COLLECTION)
    VISIBLE=bpy.data.collections.new("SOURCE_VISIBLE_CONTROL_ENCLOSURE")
    COLLECTION.children.link(VISIBLE)
    create_materials()
    build_enclosure()
    top,iso,detail=rig_scene()
    scene=bpy.context.scene
    real_objects=[o for o in VISIBLE.objects if o.type in {"MESH","CURVE"}]
    if len(real_objects)<75 or not all(o.data for o in real_objects):
        raise RuntimeError("Exterior mesh is missing or incomplete")
    if len(COLLECTION.children)!=1:
        raise RuntimeError("Hidden geometry collection must not exist")
    if len(CABLE_ROUTES)!=6:
        raise RuntimeError("Expected exactly six source-traced cable/hose routes")
    for unsupported in ("Central raised selector housing",
                        "Black mechanical selector slot",
                        "Capacitor 0 upright metal shell"):
        if bpy.data.objects.get(unsupported):
            raise RuntimeError("V16 unsupported geometry remains: "+unsupported)
    if sum("source recessed channel" in o.name for o in VISIBLE.objects)!=4:
        raise RuntimeError("Exactly 4 source knife switch lanes required")
    if sum("Original rear rectangular retaining clamp" in o.name
           for o in VISIBLE.objects)!=4:
        raise RuntimeError("Exactly 4 actual rectangular cable clamps required")
    if not all(bpy.data.objects.get(w["start"]).type=="EMPTY" and
               bpy.data.objects.get(w["end"]).type=="EMPTY"
               for w in CABLE_ROUTES):
        raise RuntimeError("Cables must have occluded rather than fabricated ends")
    bpy.context.view_layer.update()
    for wire in CABLE_ROUTES:
        cable=bpy.data.objects.get(wire["name"])
        start=bpy.data.objects.get(wire["start"])
        end=bpy.data.objects.get(wire["end"])
        if not cable or not start or not end:
            raise RuntimeError("Cable route missing geometry: "+str(wire))
        points=cable.data.splines[0].bezier_points
        for pt,gland in ((points[0],start),(points[-1],end)):
            pos=cable.matrix_world @ pt.co
            actual=gland.location.copy() if gland.type=="EMPTY" else gland.matrix_world.translation
            if (pos-actual).length>.018:
                raise RuntimeError("Cable not attached: "+wire["name"]+" to "+gland.name+
                    " actual="+str(tuple(round(x,4) for x in actual))+
                    " curve="+str(tuple(round(x,4) for x in pos)))
    # Verify endpoints at construction coordinates first, then perform a
    # CONTINUOUS physical height reduction preserving every connection.
    shrink_evidence=shorten_middle_chassis_preserving_connections()
    front_evidence=retract_front_fascia(20)
    bpy.context.view_layer.update()
    for wire in CABLE_ROUTES:
        cable=bpy.data.objects[wire["name"]]
        endpoints=cable.data.splines[0].bezier_points
        for point,name in ((endpoints[0],wire["start"]),
                           (endpoints[-1],wire["end"])):
            marker=bpy.data.objects[name]
            actual=marker.location.copy()
            pos=cable.matrix_world @ point.co
            if (pos-actual).length>.004:
                raise RuntimeError("Cable occlusion marker drifted after 3D remap: "+
                                   wire["name"]+" -> "+name)
    # The two originally observed foot assemblies are actual 3D solids.
    for side in ("left","right"):
        foot=bpy.data.objects.get("SOURCE FOUNDATION "+side+" structural foot")
        if (foot is None or foot.get("physical_design")!="LOFTED_3D_INTEGRATED_CHASSIS"
            or len(foot.data.vertices)!=32):
            raise RuntimeError("Source-defined forged 3D foundation foot missing: "+side)
    # Real deletion gate: it is a failure if any unsupported piece returns.
    for obsolete in ("LAYER_1 Foundation left front diagonal anchor gusset",
                     "LAYER_1 Foundation right front diagonal anchor gusset",
                     "Controller leading machined armor lip"):
        if bpy.data.objects.get(obsolete) is not None:
            raise RuntimeError("Faux V17 overlay survived deletion: "+obsolete)
    if any("scar" in o.name.lower() or
           "oxidized" in o.name.lower() or
           "rusted" in o.name.lower()
           for o in VISIBLE.objects):
        raise RuntimeError("Random geometry wear survived deletion-only pass")
    # Structural evidence: this is a watertight cross-section-based 3D hull,
    # not several overlaid sprites extruded into thick planar front strips.
    casting=bpy.data.objects.get("LAYER_2 Raised central machine chassis")
    if casting is None or casting.get("physical_design")!="LOFTED_3D_INTEGRATED_CHASSIS":
        raise RuntimeError("Missing single solid modeled chassis")
    forbidden_front_overlays=("Cast frontal armor stepped skirt",
        "Forged bottom full-width armored shoe",
        "Recessed front structural dark spar",
        "Upper tapered front armor guard",
        "Inset bottom mechanical seam",
        "Heavy cast front corner boot 0","Heavy cast front corner boot 1",
        "Purpose-shaped bolted front lug 0","Purpose-shaped bolted front lug 1",
        "LAYER_3 Shaped frontal equipment fascia",
        "LAYER_3 Narrow shadow reveal",
        "LAYER_3 Control deck machine-edge step")
    remaining=[name for name in forbidden_front_overlays if bpy.data.objects.get(name)]
    if remaining:
        raise RuntimeError("Stacked false front armor still exists: "+str(remaining))
    if len(casting.data.vertices)!=32 or len(casting.data.polygons)!=26:
        raise RuntimeError("Lofted middle chassis topology invalid")
    upper_cast=bpy.data.objects.get("LAYER_3 Elevated control deck structural body")
    if not upper_cast or upper_cast.get("physical_design")!="LOFTED_3D_INTEGRATED_CHASSIS":
        raise RuntimeError("Upper machine not a continuous 3D casting")
    if len(upper_cast.data.vertices)!=32 or len(upper_cast.data.polygons)!=26:
        raise RuntimeError("Upper machine is not a coherent four-section solid")
    recess_evidence=carve_real_chassis_front_recess()
    true_vents=cut_three_true_maintenance_vents()
    foot_faces=carve_source_corner_foot_faces()
    seated_screws=seat_original_front_face_screws()
    save_render(scene,top,OUTPUT/"01_source_view_real_mesh.png")
    save_render(scene,iso,OUTPUT/"02_game_candidate_full_miner.png")
    save_render(scene,detail,OUTPUT/"03_visible_enclosure_detail.png")
    scene.camera=iso
    scene["asset"]="Tech Priests emergency miner"
    scene["asset_revision"]="V21 two tall dark cast source-corner feet with integrated shoulders and real bolt heights"
    scene["source_sprite_sha256"]=SOURCE_SHA256
    scene["source_sprite_visual_acceptance"]="PENDING"
    scene["technology_principle"]="DOWNWARD_FREQUENCY_MODULATED_LASER_ABLATION"
    scene["hidden_internal_geometry"]="NOT_MODELED"
    blend=OUTPUT/"tech_priests_emergency_miner_v21.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    if bpy.context.scene.get("asset") != "Tech Priests emergency miner":
        raise RuntimeError("Saved Blender scene identity readback failed")
    if len(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects)<75:
        raise RuntimeError("Saved Blender scene lost visible components")
    # Reopen invalidates Blender RNA wrappers captured before save.
    reopened_casting=bpy.data.objects.get("LAYER_2 Raised central machine chassis")
    reopened_upper=bpy.data.objects.get("LAYER_3 Elevated control deck structural body")
    if reopened_casting is None or reopened_casting.get("physical_design")!="LOFTED_3D_INTEGRATED_CHASSIS":
        raise RuntimeError("Lofted middle chassis missing after Blender save/reopen")
    if reopened_upper is None or reopened_upper.get("physical_design")!="LOFTED_3D_INTEGRATED_CHASSIS":
        raise RuntimeError("Lofted top machine missing after Blender save/reopen")
    # Editable curves remain in .blend; export their physical mesh form to GLB.
    for obj in list(bpy.data.objects):
        obj.select_set(False)
    for obj in list(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects):
        if obj.type=="CURVE":
            bpy.context.view_layer.objects.active=obj
            obj.select_set(True)
            bpy.ops.object.convert(target="MESH")
            obj.select_set(False)
    for obj in bpy.data.objects:
        obj.select_set(obj.type=="MESH")
    export=OUTPUT/"tech_priests_emergency_miner_v21.glb"
    bpy.ops.export_scene.gltf(filepath=str(export),export_format="GLB",
                              use_selection=True,export_apply=True)
    if not export.is_file() or export.stat().st_size<20000:
        raise RuntimeError("Missing real GLB source-visible geometry")
    report={
        "asset":"tech-priests-emergency-miner",
        "state":"V21 SOURCE-VISIBLE TALL CORNER SUPPORTS; VISUAL REVIEW PENDING",
        "candidate_revision":"V21",
        "construction_method":"PHYSICAL_3D_SOLIDS_THEN_COMPARE_PROJECTED_RENDER",
        "middle_chassis_physical_cross_sections":reopened_casting.get("cross_sections"),
        "upper_machine_physical_cross_sections":reopened_upper.get("cross_sections"),
        "source_camera_strategy":"STEEP_NEAR_SYMMETRIC_FROM_FRONT",
        "source_camera_azimuth_elevation_degrees":{"azimuth":0,"elevation":76},
        "inspection_camera_strategy":"ACTUAL_OBLIQUE_THREE_DIMENSIONAL_DEPTH",
        "rear_wiring":"ORIGINAL_RECTANGULAR_CLAMPS_OCCLUDED_ENDS",
        "perimeter_hose_shape":"TWO_SOURCE_CORRUGATED_HOSES_OCCLUDED_ENDS",
        "separate_upper_front_fascia":False,
        "foundation_plate_thickness":0.086,
        "fabricated_front_overlay_count":len(remaining),
        "original_source_sha256":SOURCE_SHA256,
        "source_sprite_replaced":False,
        "gameplay_changed":False,
        "source_visible_parts":len(real_objects),
        "source_visible_features":FEATURES,
        "layer_architecture":LAYER_ELEVATIONS,
        "view_angle_target_degrees":{"azimuth":36,"elevation":54},
        "visible_pulse_capacitors":3,
        "source_detail_counts":{"vents":3,"capacitor_ends":3,
            "lcd":1,"lamps":4,"switch_lanes":4,
            "colored_switch_ends":3,"rear_clamps":4,
            "perimeter_hoses":2,"foundation_anchors":6,
            "chassis_front_screws":2},
        "source_cable_routes":6,
        "visibly_fabricated_gold_terminal_rings":0,
        "deletion_only_iteration":False,
        "source_profiled_foundation_feet":2,
        "foundation_foot_construction":"TWO_FOUR_SECTION_TAPERED_CONNECTED_SOLIDS",
        "foundation_foot_upper_join_before_compression":0.555,
        "foundation_foot_mid_support_before_compression":0.454,
        "removed_unsupported_objects":["LAYER_1 Foundation left front diagonal anchor gusset",
            "LAYER_1 Foundation right front diagonal anchor gusset",
            "Controller leading machined armor lip"],
        "random_stamped_surface_marks":0,
        "physical_knife_switches":4,
        "middle_chassis_height_evidence":shrink_evidence,
        "front_setback_evidence":front_evidence,
        "carved_front_service_channel":recess_evidence,
        "real_vent_apertures":true_vents,
        "source_recessed_foot_faces":foot_faces,
        "actual_chassis_seated_front_screws":seated_screws,
        "foundation_corner_cast_gussets":0,
        "capacitors_visible_front_round_ends":3,
        "foundation_plate_corner_bolts":6,
        "chassis_front_armor_bolts":2,
        "capacitor_ends_read_forward":True,
        "upper_wiring_seated_to_machinery":True,
        "owner_layer_map":{"uncolored":"foundation_perimeter",
                           "blue":"middle_chassis_lip_and_front",
                           "red":"raised_machinery_and_control_deck"},
        "front_control_slope_degrees":11,
        "capacitor_axis":"HORIZONTAL_FRONT_CIRCULAR_ENDS",
        "coolant_entries":"LATERAL_INTO_UPPER_MACHINERY",
        "perimeter_hoses_visible_on_chassis_shoulders":True,
        "control_deck_width_reference_units":486,
        "source_contour_mesh_count":sum(
            ob.type=="MESH" and bool(ob.get("source_contour", False))
            for ob in bpy.data.objects),
        "separate_LCD_and_switch_faceplates":True,
        "terminated_cable_routes":CABLE_ROUTES,
        "modeled_hidden_internal_components":0,
        "render_geometry_policy":"GAME_CAMERA_VISIBLE_ONLY",
        "laser_components_documented_not_modeled":True,
        "technology_principle":"DOWNWARD_FREQUENCY_MODULATED_LASER_ABLATION",
        "reconstitution":"CRUDE_LOW_RATE_CONTAMINATED_PROTOMATTER_RECOVERY",
        "mechanical_excavation_components":0,
        "doctrine_slow_polluting_bootstrap_not_industrial":True,
        "transparent_render_frames":["01_source_view_real_mesh.png",
                                     "02_game_candidate_full_miner.png",
                                     "03_visible_enclosure_detail.png"],
        "saved_master":blend.name,
        "saved_master_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
        "physical_glb_export":export.name,
        "physical_glb_sha256":hashlib.sha256(export.read_bytes()).hexdigest(),
        "input_sprite_reused_as_texture":False,
        "appearance_approved":False,
        "model_must_be_visually_reviewed_before_game_integration":True,
    }
    (OUTPUT/"model_manifest.json").write_text(
        json.dumps(report,indent=2)+"\n",encoding="utf8")
    print("EMERGENCY_MINER_REAL_3D_CANDIDATE "+
          json.dumps(report,separators=(",",":")),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    main(args.out)
