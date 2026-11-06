"""V09: source-traced stepped castings instead of stacked generic boxes.

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
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png"
SOURCE_SHA256 = "29442badbd53d2f69880fb625330ed071e6d362119e458952f575d53cc1bf700"
OUTPUT = None
COLLECTION = None
VISIBLE = None
MATERIALS = {}
FEATURES = []
CABLE_ROUTES = []
LAYER_ELEVATIONS = {"foundation_top":0.165, "chassis_top":0.475, "deck_top":0.556, "raised_controls":0.115}
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


def cable_gland(name, x, y, z):
    """Visible physical socket/strain relief, not a floating cable endpoint."""
    cylinder(name,x,y,z,.017,.031,MATERIALS["black_steel"],24)
    torus(name+"_metal_collar",x,y,z+.014,.016,.004,MATERIALS["brass"])
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
    octagonal_case("LAYER_1 Foundation perimeter steel slab",340,329,.025,.156,
                   638,625,45,dark)
    frame_ring("LAYER_1 Foundation exposed bolted rim",340,329,.155,.174,
               638,625,589,565,edge)
    # 2. Raised armored chassis with an exposed vertical FRONT face.
    octagonal_case("LAYER_2 Raised central machine chassis",340,315,.165,.475,
                   608,563,40,iron)
    frame_ring("LAYER_2 Chassis upper shoulder",340,315,.457,.483,
               607,561,564,516,dark)
    # 3. A smaller, higher control deck supports the monitor and wiring.
    octagonal_case("LAYER_3 Elevated control deck structural body",
                   340,254,.470,.556,486,424,29,panel)
    frame_ring("LAYER_3 Control deck machine-edge step",
               340,254,.547,.567,491,432,466,408,edge)
    cast_contour("LAYER_3 Shaped frontal equipment fascia",
        [(117,438),(559,439),(574,453),(558,478),
         (128,478),(107,454)],.470,.600,iron,.009)
    cube("LAYER_3 Narrow shadow reveal",340,476,.480,
         448,5,.014,crevice,.001)
    # Traced steel skirt and unequal trapezoidal lower supports, not
    # a stack of rectangular consumer-equipment boxes.
    cast_contour("Cast frontal armor stepped skirt",
        [(49,527),(630,527),(646,558),(627,601),
         (57,601),(38,562)],.422,.476,iron,.008)
    cast_contour("Forged bottom full-width armored shoe",
        [(78,575),(599,575),(579,625),(99,627)],
        .442,.493,panel,.006)
    cast_contour("Recessed front structural dark spar",
        [(103,481),(580,481),(574,532),(108,534)],
        .414,.470,dark,.005)
    cast_contour("Upper tapered front armor guard",
        [(132,437),(550,438),(571,456),
         (557,479),(140,479),(118,458)],
        .430,.483,iron,.006)
    cube("Inset bottom mechanical seam",332,556,.483,
         425,5,.010,crevice,.001)
    for index,x in enumerate((75,610)):
        cast_contour(f"Heavy cast front corner boot {index}",
            [(x-37,511),(x+39,511),(x+48,532),
             (x+45,600),(x+27,613),(x-43,613),
             (x-51,592),(x-47,532)],
            .305,.474,dark,.012)
        cast_contour(f"Purpose-shaped bolted front lug {index}",
            [(x-31,534),(x+29,533),(x+38,551),
             (x+31,580),(x-29,578),(x-37,559)],
            .450,.498,edge,.006)
    for x,y in [(119,452),(552,463),(127,568),(552,574),(75,74),(600,74)]:
        bolt("Milled chassis structural fastener",x,y,.478,1.52)

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
    cast_contour("Controller leading machined armor lip",
        [(177,417),(572,418),(577,428),
         (563,445),(185,445),(170,428)],
        .486,.516,iron,.004)

    # The three real recessed vent apertures, not printed dark stripes.
    for i,(y,w) in enumerate(((153,68),(177,67),(201,65))):
        cube(f"Physical vent cavity dark well {i}",223,y,.501,w,9,.004,crevice,.003)
        cube(f"Physical vent left inner sidewall {i}",188,y,.503,2,6,.008,dark,0)
        cube(f"Physical vent right inner sidewall {i}",256,y,.503,2,6,.008,dark,0)
    screws("Main upper cover",[(183,236),(402,240),(402,115),(182,116),(402,283)],.507)
    screws("Socket bank",[(442,131),(565,131),(440,290),(568,289)],.507)
    screws("Lower console",[(179,312),(565,315),(181,418),(566,416)],.513)
    for x,y in [(137,104),(139,325)]:
        bolt("Left long support rail boss",x,y,.511,1.20)

    # Source triple cylinders are substantial vertical pulse capacitors.
    # Their insulated tops and lower armored retaining collars should read
    # as three tall individual power-storage elements at shallow angles.
    for idx,x in enumerate((459,503,547)):
        cylinder(f"Capacitor {idx} cast retaining foot",x,172,.499,
                 .041,.024,dark,32)
        torus(f"Capacitor {idx} brass bottom collar",x,172,.520,
              .036,.007,brass)
        cylinder(f"Capacitor {idx} steel vertical shell",x,172,.555,
                 .034,.106,edge,32)
        cylinder(f"Capacitor {idx} dielectric cap",x,172,.611,
                 .032,.016,MATERIALS["insulator"],32)
        torus(f"Capacitor {idx} upper retaining ring",x,172,.624,
              .028,.005,brass)
        cylinder(f"Capacitor {idx} center terminal",x,172,.631,
                 .012,.022,dark,20)
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
    # Three source red/amber/green circles are KNIFE SWITCH handle ends.
    # Give each a physical pivot, moving steel blade and fixed contact.
    for idx,(x,color) in enumerate(((430,"red"),(505,"amber"),(550,"green"))):
        cube(f"Knife switch {idx} bolted insulated bed",x,369,.517,
             27,96,.024,dark,.003)
        cylinder(f"Knife switch {idx} hinge bearing",x,347,.539,
                 .021,.035,edge,28)
        torus(f"Knife switch {idx} metal handle collar",x,346,.560,
              .022,.004,brass)
        cylinder(f"Knife switch {idx} colored handle end",x,346,.568,
                 .018,.023,MATERIALS[color],28)
        curve(f"Knife switch {idx} forged moving blade",
              [(x,353,.566),(x,372,.573),(x,387,.552)],
              .008,MATERIALS["edge_steel"])
        cylinder(f"Knife switch {idx} fixed bottom contact",x,395,.535,
                 .018,.022,brass,24)
        cube(f"Knife switch {idx} lower electrical bus shoe",x,404,.524,
             17,18,.011,edge,.002)
        screws(f"Knife switch {idx} bed fixings",[(x,318),(x,414)],.537)
    # Distinctive central black selector remains separate from knife switches.
    cube("Central raised selector housing",467,363,.530,23,61,.034,iron,.002)
    cube("Black mechanical selector slot",467,363,.550,8,47,.005,crevice,.001)

    # All exposed wires terminate in actual built glands, capacitor lugs,
    # side feedthroughs, or bolted service junctions: no arbitrary open ends.
    cable_gland("Rear red HV input gland",181,58,.502)
    cable_gland("Capacitor red terminal gland",459,160,.553)
    routed_cable("Top red insulated cable",
        [(181,58,.502),(207,63,.539),(306,71,.552),
         (404,93,.568),(459,160,.553)],.011,MATERIALS["red_wire"],
        "Rear red HV input gland","Capacitor red terminal gland",
        "Rear HV entry to first pulse capacitor")
    cable_gland("Rear green logic input gland",266,58,.499)
    cable_gland("Capacitor green terminal gland",547,160,.552)
    routed_cable("Top bright green insulated cable",
        [(266,58,.499),(340,61,.547),(422,91,.557),
         (505,123,.568),(547,160,.552)],.010,MATERIALS["green_wire"],
        "Rear green logic input gland","Capacitor green terminal gland",
        "Frequency-control feedback to capacitor cluster")
    cable_gland("Rear copper service gland",164,63,.504)
    cube("Copper rear service junction block",284,80,.515,29,24,.031,iron,.002)
    cable_gland("Copper junction entry gland",284,80,.545)
    routed_cable("Top copper orange secondary wire",
        [(164,63,.504),(208,60,.533),(250,70,.543),
         (284,80,.545)],.0065,MATERIALS["copper"],
        "Rear copper service gland","Copper junction entry gland",
        "Protected tertiary service supply")
    for j,xx in enumerate((165,265,488)):
        cube(f"Gold upper conduit clip {j}",xx,55,.530,
             20,33,.028,brass,.003)
        screws(f"upper cable clip fixing {j}",[(xx,49)],.548)
    # Supply enters the chassis sidewall and disappears into the raised deck.
    # Those two junctions are explicitly modeled rather than cut-off curves.
    cable_gland("Right upper HV sidewall gland",624,206,.445)
    cable_gland("Right lower HV bus gland",614,406,.456)
    routed_cable("Right visible red high voltage feed",
        [(624,206,.445),(624,265,.454),(629,338,.466),
         (633,375,.467),(614,406,.456)],.013,MATERIALS["red_wire"],
         "Right upper HV sidewall gland","Right lower HV bus gland",
         "Externally protected HV supply down chassis side")
    cable_gland("Right control logic upper outlet",531,94,.497)
    cable_gland("Right control logic lower return",588,239,.465)
    routed_cable("Right green internal control conduit",
        [(531,94,.497),(567,123,.500),(580,177,.484),
         (588,239,.465)],.009,MATERIALS["green_wire"],
         "Right control logic upper outlet","Right control logic lower return",
         "Protected control signal from capacitor area to chassis return")

    # Corrugated fluid/heat hoses sit outside the raised control deck, on
    # the exposed chassis shoulder. End fittings physically grip the hose.
    for side in (-1,1):
        prefix="L" if side<0 else "R"
        x=66 if side<0 else 614
        top_gland=f"{prefix} rear hydraulic bulkhead connector"
        bottom_gland=f"{prefix} front hydraulic manifold connector"
        cable_gland(top_gland,x,84,.500)
        cable_gland(bottom_gland,x+8*side,405,.497)
        points=[(x,84,.500),(x-9*side,117,.507),
                (x-12*side,171,.516),(x-12*side,230,.509),
                (x-12*side,299,.502),(x-4*side,356,.507),
                (x+8*side,405,.497)]
        routed_cable(prefix+" actual perimeter ribbed hydraulic conduit",
           points,.022,MATERIALS["black_wire"],top_gland,bottom_gland,
           "External sealed heat-transfer hose, connected at both ends")
        for i in range(13):
            y=105+i*21
            xi=x-(10 if 1<i<9 else 4)*side
            torus(prefix+f" hydraulic rib {i:02d}",xi,y,.514,
                  .022,.003,MATERIALS["iron"],rotation=(math.pi/2,0,0))
        for y in (150,284,348):
            cube(prefix+f" steel hose retaining bracket {y}",x,y,.527,
                 44,23,.028,edge,.003)
            screws(prefix+f" hose bracket stud {y}",[(x,y)],.549)

    # Localized real 3D surface wear is source-grounded: prominent pitting
    # and cut-back paint occur on the original's blank armored steel faces.
    forged_patina_marks("Dark oxidized upper cover scars",192,389,112,213,
                        .502,210,"oxide",3101)
    forged_patina_marks("Bright cut-metal upper cover scratches",192,389,113,213,
                        .503,62,"edge_scar",3102)
    forged_patina_marks("Rusted middle cover surface",185,399,236,287,
                        .495,78,"oxide",3103)
    forged_patina_marks("Rusted upper socket carrier",447,551,128,214,
                        .499,74,"oxide",3104)
    forged_patina_marks("Ground left vertical cover plate",121,153,129,371,
                        .487,115,"oxide",3105)
    forged_patina_marks("Worn forward armored rail",189,553,477,528,
                        .477,120,"oxide",3106)
    forged_patina_marks("Forward rail exposed metal nicks",190,546,478,528,
                        .478,47,"edge_scar",3107)
    # Preserve strong physical separation between base, chassis and upper
    # machine controls. Lifting all parts indiscriminately produces floating
    # side hoses; named sidewall routes remain anchored at chassis height.
    chassis_external_prefix=(
        "L ","R ","Right visible red high voltage feed",
        "Right green internal control conduit","Right upper HV sidewall gland",
        "Right lower HV bus gland","Right control logic upper outlet",
        "Right control logic lower return",
        "Worn forward armored rail","Forward rail exposed metal nicks",
    )
    for obj in VISIBLE.objects:
        if obj not in fixed_lower_objects and not obj.name.startswith(chassis_external_prefix):
            obj.location.z+=LAYER_ELEVATIONS["raised_controls"]
    # Route end-glands that sit on the chassis are not lifted, ensuring
    # external cables are supported rather than hovering above its side.
    FEATURES.extend([
      "dark and bright genuinely modeled local surface metal scars",
      "chamfered source 1x1 enclosure and thick raised edge", "six structural fasteners",
      "left vertical bearing plate", "top maintenance cover with real vent wells",
      "three visibly raised industrial pulse capacitors", "green computer display with tiny geometry",
      "four colored indicator lamps", "three physical knife switches with colored handle ends",
      "real red-green cable conduits and gold clamps",
      "corrugated black hydraulic perimeter with clamps",
      "foundation slab / raised armored chassis / top instrument panel",
      "low rear cable drops and protected bulkhead endpoint glands",
      "source-traced irregular armor plates, split control faces, tapered front castings",
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
    scene.view_settings.view_transform = "AgX" if "AgX" in [
       item.identifier for item in scene.view_settings.bl_rna.properties["view_transform"].enum_items
    ] else "Standard"
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
    top=camera("CAMERA_SOURCE_MATCH_OBLIQUE",(0,-1.28,3.10),(0,0,.40),1.38)
    iso=camera("CAMERA_GAME_45_AZIMUTH_25_ELEVATION",(1.75,-1.75,1.63),(0,-.07,.47),1.58)
    detail=camera("CAMERA_VISIBLE_ENCLOSURE_DETAIL",(-1.20,-1.90,1.79),(0,-.07,.48),1.48)
    def area(name, pos, power, size):
        data=bpy.data.lights.new(name,"AREA")
        data.energy=power
        data.shape='DISK'
        data.size=size
        obj=bpy.data.objects.new(name,data)
        COLLECTION.objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(Vector((0,0,.26))-obj.location).to_track_quat("-Z","Y").to_euler()
    area("Warm studio keylight",(-2.2,-1.9,3.9),245,4.0)
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
    material("black_steel",(.026,.025,.024),.63,.73,.38)
    material("iron",(.067,.057,.048),.67,.75,.45)
    material("edge_steel",(.145,.122,.094),.79,.65,.38)
    material("worn_steel",(.089,.075,.060),.73,.72,.47)
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
    if len(CABLE_ROUTES)!=7:
        raise RuntimeError("Expected exactly seven individually terminated cable/hose routes")
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
            actual=gland.matrix_world.translation
            if (pos-actual).length>.018:
                raise RuntimeError("Cable not attached: "+wire["name"]+" to "+gland.name)
    save_render(scene,top,OUTPUT/"01_source_view_real_mesh.png")
    save_render(scene,iso,OUTPUT/"02_game_candidate_full_miner.png")
    save_render(scene,detail,OUTPUT/"03_visible_enclosure_detail.png")
    scene.camera=iso
    scene["asset"]="Tech Priests emergency miner"
    scene["asset_revision"]="V09 source-shaped castings and divided upper controls"
    scene["source_sprite_sha256"]=SOURCE_SHA256
    scene["source_sprite_visual_acceptance"]="PENDING"
    scene["technology_principle"]="DOWNWARD_FREQUENCY_MODULATED_LASER_ABLATION"
    scene["hidden_internal_geometry"]="NOT_MODELED"
    blend=OUTPUT/"tech_priests_emergency_miner_v09.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    if bpy.context.scene.get("asset") != "Tech Priests emergency miner":
        raise RuntimeError("Saved Blender scene identity readback failed")
    if len(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects)<75:
        raise RuntimeError("Saved Blender scene lost visible components")
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
    export=OUTPUT/"tech_priests_emergency_miner_v09.glb"
    bpy.ops.export_scene.gltf(filepath=str(export),export_format="GLB",
                              use_selection=True,export_apply=True)
    if not export.is_file() or export.stat().st_size<20000:
        raise RuntimeError("Missing real GLB source-visible geometry")
    report={
        "asset":"tech-priests-emergency-miner",
        "state":"V09 SPRITE-TRACED ARMOR AND CONTROLS REQUIRES VISUAL REVIEW",
        "candidate_revision":"V09",
        "original_source_sha256":SOURCE_SHA256,
        "source_sprite_replaced":False,
        "gameplay_changed":False,
        "source_visible_parts":len(real_objects),
        "source_visible_features":FEATURES,
        "layer_architecture":LAYER_ELEVATIONS,
        "view_angle_target_degrees":{"azimuth":45,"elevation":25},
        "visible_pulse_capacitors":3,
        "physical_knife_switches":3,
        "perimeter_hoses_visible_on_chassis_shoulders":True,
        "control_deck_width_reference_units":486,
        "source_contour_mesh_count":sum(
            "SOURCE_TRACED_CAST_SURFACE" in ob.data.name for ob in real_objects
            if ob.type=="MESH"),
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
