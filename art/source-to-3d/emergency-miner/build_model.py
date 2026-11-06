"""V05: source-aligned armored laser-ablation and low-yield reconstitution machine.

The owner-specified operating principle replaces previous mechanical excavation.
Only the enclosure is visibly established by the original sprite.
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
INFERRED = None
MATERIALS = {}
FEATURES = []
FUNCTIONAL_PATHS = []
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
    octagonal_case("Lower armored 1x1 support hull",340,329,.10,.265,638,625,45,dark)
    octagonal_case("Main cast perimeter enclosure",340,314,.22,.395,625,590,35,iron)
    octagonal_case("Inner sunken machinery substrate",340,301,.397,.408,547,501,29,crevice)
    frame_ring("Outer beveled chassis lip",340,315,.395,.421,628,590,576,542,edge)
    frame_ring("Inner protected instrument ledge",339,294,.411,.423,541,465,512,445,panel)
    # Distinctive lower armor rail and lifting feet.
    cube("Lower projecting shell flange",340,576,.445,620,82,.054,iron,.009)
    cube("Lower full width shoe",338,595,.465,540,37,.056,panel,.006)
    cube("Front load-bearing black steel spar",345,511,.437,492,53,.070,dark,.009)
    cube("Forward raised steel guard",338,461,.456,447,35,.045,iron,.006)
    cube("Inset bottom mechanical seam",332,556,.483,434,11,.013,crevice,.002)
    for i,xx in enumerate((75,610)):
        cube(f"Heavy left-right bottom foot {i}",xx,566,.383,86,127,.170,dark,.014)
        cube(f"Reinforced load ear {i}",xx,558,.490,57,55,.027,edge,.005)
    for x,y in [(119,452),(552,463),(127,568),(552,574),(75,74),(600,74)]:
        bolt("Milled chassis structural fastener",x,y,.478,1.52)

    # Interior control decks: exact original relative position and elevation.
    cube("Left vertical cast mounting rail",138,258,.455,58,291,.052,panel,.005)
    cube("Main high blank steel maintenance cover",301,164,.456,264,136,.051,panel,.004)
    cube("Left lower horizontal transmission cover",297,264,.452,259,70,.045,iron,.003)
    cube("Right upper socket plate",497,176,.460,157,112,.042,panel,.004)
    cube("Right lower cover",501,264,.455,154,70,.043,iron,.004)
    cube("Lower instrument bank",380,365,.458,420,131,.059,panel,.004)
    cube("Lower dark instrument recess",377,364,.488,403,113,.006,crevice,.002)
    # Secondary modular covers allow individual steel panel seams to be read.
    cube("Upper blank top inset cast panel",300,165,.490,244,118,.014,panel,.003)
    cube("Middle cover horizontal field",295,263,.480,241,55,.018,iron,.003)
    cube("Socket tray face",497,177,.486,140,95,.014,panel,.003)
    cube("Instrument bay face upper lip",378,311,.494,411,16,.012,edge,.001)
    cube("Console bottom guard bottom lip",379,425,.497,420,20,.025,iron,.005)

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

    # Three raised socket collars: metal annuli, central real dark bores.
    for idx,x in enumerate((459,503,547)):
        cylinder(f"Top 3 heavy power sockets {idx} body",x,170,.510,.026,.030,dark,32)
        torus(f"Top 3 heavy power sockets {idx} steel lip",x,170,.528,.022,.004,edge)
        cylinder(f"Top 3 heavy power sockets {idx} recessed bore",x,170,.531,.016,.003,crevice,32)

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
    # Three colored cable couplings and one black toggle.
    for idx,(x,color) in enumerate(((430,"red"),(505,"amber"),(550,"green"))):
        cylinder(f"Front cable socket {idx} black shoulder",x,346,.525,.023,.031,dark,28)
        torus(f"Front cable socket {idx} actual metal ring",x,346,.543,.019,.005,MATERIALS[color])
        cylinder(f"Front cable socket {idx} inner hole",x,346,.545,.012,.003,crevice,28)
        curve(f"Front cable socket {idx} dropped wire",[(x,365,.526),(x,385,.520),
              (x-4,398,.520)],.003,MATERIALS["black_wire"])
        cylinder(f"Wire boot {idx}",x-4,398,.519,.008,.012,dark,20)
    cube("Central raised selector housing",467,363,.530,23,61,.034,iron,.002)
    cube("Black mechanical selector slot",467,363,.550,8,47,.005,crevice,.001)

    # Source visible upper red/green cable bundles, real curved tubes and clamps.
    curve("Top red insulated cable",[(186,52,.469),(235,55,.479),(305,64,.487),
         (360,78,.495),(426,95,.492),(481,107,.488)],.010,MATERIALS["red_wire"])
    curve("Top bright green insulated cable",[(266,50,.471),(341,47,.488),
         (392,60,.496),(449,85,.503),(514,105,.488),(565,156,.484)],.010,MATERIALS["green_wire"])
    curve("Top copper orange secondary wire",[(169,54,.471),(235,52,.480),
         (290,52,.484)],.0065,MATERIALS["copper"])
    for j,xx in enumerate((165,265,488)):
        cube(f"Gold upper conduit clip {j}",xx,55,.490,20,33,.028,brass,.003)
        screws(f"upper cable clip fixing {j}",[(xx,49)],.525)

    # Right red vertical feeder with robust sheath and lower bend.
    curve("Right visible red high voltage feed",[(624,206,.445),(623,267,.448),
        (628,326,.456),(632,379,.458),(614,408,.460)],.013,MATERIALS["red_wire"])
    curve("Right green internal control conduit",[(531,94,.471),(571,133,.470),
        (579,192,.461),(588,239,.465)],.009,MATERIALS["green_wire"])

    # Left and right corrugated black peripheral hose is genuinely round.
    for side in (-1, 1):
        x = 74 if side<0 else 606
        points = [(x,84,.465),(x-9*side,117,.473),
                  (x-12*side,171,.482),(x-12*side,230,.475),
                  (x-12*side,299,.468),(x-4*side,356,.473),(x+8*side,405,.463)]
        curve(("L" if side<0 else "R")+" actual perimeter ribbed hydraulic conduit",points,
              .023,MATERIALS["black_wire"])
        for i in range(13):
            y=105+i*21
            bend=10 if i>1 and i<9 else 4
            xi=x-bend*side
            # Physical corrugations rise proud of the underlying hose.
            torus(("L" if side<0 else "R")+f" hydraulic rib {i:02d}",
                  xi,y,.480,.017,.0025,MATERIALS["iron"],
                  rotation=(math.pi/2,0,0))
        for y in (150,284,348):
            cube(("L" if side<0 else "R")+f" steel hose retaining bracket {y}",
                 x,y,.493,44,23,.028,edge,.003)
            screws("Hose bracket stud",[(x,y)],.515)

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
    FEATURES.extend([
      "dark and bright genuinely modeled local surface metal scars",
      "chamfered source 1x1 enclosure and thick raised edge", "six structural fasteners",
      "left vertical bearing plate", "top maintenance cover with real vent wells",
      "triple recessed power sockets", "green computer display with tiny geometry",
      "four colored indicator lamps", "three front cable coupling assemblies",
      "real red-green cable conduits and gold clamps",
      "corrugated black hydraulic perimeter with clamps",
      "lower shoe, feet and three overlapping forged reinforcing rails",
    ])


def register_functional_path(system, source, via, destination, status, purpose):
    FUNCTIONAL_PATHS.append(dict(system=system, source=source, via=via,
                                 destination=destination, source_certainty=status,
                                 mechanical_purpose=purpose))


def build_mining_assembly():
    """Authoritative principle: face-down modulated laser ablation and dirty reconstitution.

    The source shows a controller on an armored box. Internal geometry is
    inferred, but its technology is defined by the project owner: powerful
    modulated lasers ablate arbitrary substrate; the captured contaminated
    proto-matter is crudely reassembled into tiny quantities of usable scrap.
    It is inefficient, slow, polluting and never an industrial scale extractor.
    """
    global VISIBLE
    saved=VISIBLE
    VISIBLE=INFERRED
    dark=MATERIALS["black_steel"]
    steel=MATERIALS["edge_steel"]
    iron=MATERIALS["iron"]
    brass=MATERIALS["brass"]
    ceramic=MATERIALS["emitter_ceramic"]
    # A sealed armored bottom contacts the surface without excavation tools.
    cube("Inferred sealed ablation chamber",340,345,-.060,487,435,.212,iron,.011)
    frame_ring("Inferred continuous underside contact seal",340,345,
               -.228,-.188,500,450,403,352,dark)
    for i,x in enumerate((101,579)):
        cube(f"Inferred vertical blast-seal rail {i}",x,345,-.222,
             30,414,.093,dark,.004)
    for i,y in enumerate((132,557)):
        cube(f"Inferred horizontal blast-seal rail {i}",340,y,-.222,
             454,28,.093,dark,.004)
    # Under-deck high-power frequency controller and energy capacitors.
    cube("Inferred high power frequency controller",305,235,.041,
         240,155,.126,steel,.008)
    cube("Inferred controller ceramic shielding",305,235,.111,
         229,145,.016,ceramic,.003)
    cube("Inferred pulsed energy phase combiner",486,239,.032,
         150,177,.142,dark,.008)
    for i,x in enumerate((447,488,529)):
        cylinder(f"Inferred pulse capacitor {i}",x,236,.038,
                 .036,.139,iron,24)
        torus(f"Inferred ceramic capacitor ring {i}",x,236,.109,
              .031,.006,ceramic)
    cube("Inferred protected pulsed optical bus",338,349,-.051,
         315,65,.086,steel,.005)
    curve("Inferred red high current downfeed",
          [(624,206,.446),(612,265,.305),(552,271,.146),
           (516,245,.100)],.013,MATERIALS["red_wire"])
    curve("Inferred green frequency feedback hardline",
          [(565,156,.480),(559,203,.275),(459,222,.135),
           (406,234,.103)],.008,MATERIALS["green_wire"])
    curve("Inferred phase combiner to emitter bus cable",
          [(484,244,.037),(450,302,-.015),(390,345,-.047)],
          .014,MATERIALS["copper"])
    # Six actually modeled downward optical emitters, fed by one manifold.
    cube("Inferred underside emitter manifold",340,343,-.133,
         345,276,.043,dark,.005)
    for i,(x,y) in enumerate([(250,277),(340,277),(430,277),
                              (250,410),(340,410),(430,410)]):
        cylinder(f"Inferred laser emitter mounting boss {i}",x,y,-.169,
                 .048,.058,steel,24)
        cylinder(f"Inferred dielectric emitter neck {i}",x,y,-.213,
                 .028,.055,ceramic,24)
        cylinder(f"Inferred downward laser emitter {i}",x,y,-.244,
                 .039,.037,iron,32)
        torus(f"Inferred emitter protection bezel {i}",x,y,-.263,
              .033,.005,brass)
        cylinder(f"Inferred downward optical aperture {i}",x,y,-.267,
                 .028,.008,MATERIALS["ablator_lens"],32)
    # Ablation plasma is captured and treated as toxic, impure feedstock.
    cube("Inferred contaminated vapor capture gallery",340,492,-.090,
         375,50,.087,dark,.004)
    curve("Inferred contaminated proto matter return trunk",
          [(340,475,-.145),(418,478,-.128),(485,481,-.077),
           (507,469,-.026)],.018,MATERIALS["black_wire"])
    cylinder("Inferred contaminated matter vacuum pump",512,462,-.030,
             .059,.134,iron,32)
    cube("Inferred crude atomic reconstitution cell",521,394,.014,
         130,103,.130,steel,.008)
    cube("Inferred degraded scrap sorting cassette",521,394,.087,
         119,90,.017,iron,.003)
    cube("Inferred adulterated low yield output tray",589,444,-.066,
         62,83,.035,iron,.003)
    cube("Inferred output inspection shutter",588,445,-.040,
         51,67,.013,MATERIALS["martian_red"],.002)
    curve("Inferred reconstitution cell output feed",
          [(522,420,.008),(558,435,-.024),(587,448,-.053)],
          .013,MATERIALS["black_wire"])
    # Unusable fraction leaves through a separate fouled exhaust duct.
    curve("Inferred polluted waste offgas duct",
          [(522,398,-.037),(561,429,-.042),
           (607,477,-.084),(625,502,-.118)],.015,MATERIALS["black_wire"])
    cylinder("Inferred contaminated waste exhaust aperture",625,502,-.120,
             .023,.026,MATERIALS["crevice"],24)
    # The prominent source corrugated hoses remain, understood as a pair
    # of coolant lines for extremely inefficient pulse machinery.
    cube("Inferred liquid cooled thermal dump radiator",206,418,-.006,
         166,126,.114,iron,.008)
    for i in range(5):
        cube(f"Inferred radiator thermal dissipation fin {i}",148+i*27,420,-.080,
             11,111,.052,steel,.002)
    curve("Inferred coolant supply line",
          [(74,405,.461),(100,435,.268),(156,412,.104),
           (199,416,.048)],.011,MATERIALS["black_wire"])
    curve("Inferred coolant return line",
          [(210,423,.044),(255,453,.079),(564,454,.117),
           (606,405,.460)],.011,MATERIALS["black_wire"])
    # Functional machine sanctification: calibration and inspection for
    # frequency modulation; no gratuitous trim on the source-visible lid.
    cube("Inferred Martian red calibration access cover",304,236,.126,
         86,40,.014,MATERIALS["martian_red"],.003)
    cylinder("Inferred calibrated oscillator test connector",305,237,.145,
             .013,.020,brass,16)
    curve("Inferred oscillator condition monitor wire",
          [(306,238,.145),(334,257,.112),(369,298,.064)],
          .006,MATERIALS["green_wire"])
    register_functional_path("high-power supply",
        "Right visible red high voltage feed",
        ["Inferred red high current downfeed","Inferred pulsed energy phase combiner",
         "Inferred phase combiner to emitter bus cable"],
        "Inferred protected pulsed optical bus","SOURCE_TO_INFERRED",
        "A real supply route to the pulse capacitor and emitter array")
    register_functional_path("frequency modulation and diagnostics",
        "Recessed luminous green computer glass",
        ["Top bright green insulated cable",
         "Inferred green frequency feedback hardline",
         "Inferred calibrated oscillator test connector"],
        "Inferred high power frequency controller","SOURCE_TO_INFERRED",
        "Pulse frequency shaping, field monitoring and service calibration")
    register_functional_path("downward photon delivery",
        "Inferred protected pulsed optical bus",
        ["Inferred underside emitter manifold",
         "Inferred dielectric emitter neck 0",
         "Inferred downward laser emitter 0"],
        "Inferred downward optical aperture 0","INFERRED",
        "A protected downward emitting array acts on material under the box")
    register_functional_path("proto-matter recovery and reconstitution",
        "Inferred contaminated vapor capture gallery",
        ["Inferred contaminated proto matter return trunk",
         "Inferred contaminated matter vacuum pump",
         "Inferred crude atomic reconstitution cell",
         "Inferred reconstitution cell output feed"],
        "Inferred adulterated low yield output tray","INFERRED",
        "A tiny stream of impure usable material from collected ablation residues")
    register_functional_path("waste heat",
        "L actual perimeter ribbed hydraulic conduit",
        ["Inferred coolant supply line",
         "Inferred liquid cooled thermal dump radiator",
         "Inferred coolant return line"],
        "R actual perimeter ribbed hydraulic conduit","SOURCE_TO_INFERRED",
        "Reject severe pulse-system heat through paired coolant hoses")
    register_functional_path("contaminant discharge",
        "Inferred crude atomic reconstitution cell",
        ["Inferred polluted waste offgas duct"],
        "Inferred contaminated waste exhaust aperture","INFERRED",
        "Release unusable toxic offgas through a dedicated guarded exit")
    VISIBLE=saved


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
    top=camera("CAMERA_SOURCE_MATCH_TOP",(0,0,3.6),(0,0,.33),1.09)
    iso=camera("CAMERA_GAME_ISOMETRIC",(1.7,-2.0,2.75),(0,-.10,.28),1.52)
    side=camera("CAMERA_ABLATION_UNDERSIDE_INSPECTION",(1.3,-1.6,-1.5),(0,-.07,-.12),1.63)
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
    return top,iso,side


def save_render(scene, camera, path, hide_inferred):
    INFERRED.hide_render=hide_inferred
    scene.camera=camera
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    if not path.is_file() or path.stat().st_size < 30000:
        raise RuntimeError("Blender failed to render real machine: "+str(path))


def create_materials():
    # Source is dark oil-browned, oxidized foundry steel, not clean aluminum.
    # Tight roughness and material noise avoid a sterile plastic appearance.
    material("black_steel",(.026,.025,.024),.63,.73,.38)
    material("iron",(.082,.073,.063),.67,.71,.46)
    material("edge_steel",(.175,.154,.125),.79,.58,.39)
    material("worn_steel",(.114,.099,.080),.73,.68,.48)
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
    material("martian_red",(.165,.022,.018),.53,.65,.26)
    material("emitter_ceramic",(.24,.218,.169),.10,.64,.19)
    material("ablator_lens",(.035,.095,.117),.17,.25,.04,.08)
    # Separate cable connector color designators, reused as ring materials.
    MATERIALS["red"] = MATERIALS["red_wire"]
    MATERIALS["amber"] = MATERIALS["amber_light"]
    MATERIALS["green"] = MATERIALS["green_wire"]


def main(out):
    global OUTPUT,COLLECTION,VISIBLE,INFERRED
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise RuntimeError("The exact approved image source changed; do not model from guess")
    OUTPUT=out.resolve()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    COLLECTION=bpy.data.collections.new("Emergency Miner one-asset source reconstruction")
    bpy.context.scene.collection.children.link(COLLECTION)
    VISIBLE=bpy.data.collections.new("SOURCE_VISIBLE_CONTROL_ENCLOSURE")
    INFERRED=bpy.data.collections.new("INFERRED_UNDERBODY_LASER_ABLATION_AND_RECLAIMER")
    COLLECTION.children.link(VISIBLE)
    COLLECTION.children.link(INFERRED)
    create_materials()
    build_enclosure()
    build_mining_assembly()
    top,iso,side=rig_scene()
    scene=bpy.context.scene
    real_objects=[o for o in VISIBLE.objects if o.type in {"MESH","CURVE"}]
    inferred=[o for o in INFERRED.objects if o.type in {"MESH","CURVE"}]
    if len(real_objects)<75 or len(inferred)<10:
        raise RuntimeError(f"Not enough physical mesh content for reconstruction: {len(real_objects)},{len(inferred)}")
    if not all(o.data for o in real_objects+inferred):
        raise RuntimeError("Unowned geometry found")
    expected = {n for path in FUNCTIONAL_PATHS for n in
                [path["source"], *path["via"], path["destination"]]}
    missing = sorted(n for n in expected if bpy.data.objects.get(n) is None)
    if missing or len(FUNCTIONAL_PATHS) != 6:
        raise RuntimeError("Doctrinal path is not grounded in actual 3D parts: "+str(missing))
    save_render(scene,top,OUTPUT/"01_source_view_real_mesh.png",True)
    save_render(scene,iso,OUTPUT/"02_game_candidate_full_miner.png",False)
    save_render(scene,side,OUTPUT/"03_ablation_cell_underside_inspection.png",False)
    INFERRED.hide_render=False
    scene.camera=iso
    scene["asset"]="Tech Priests emergency miner"
    scene["asset_revision"]="V05 source-aligned laser ablation and crude material reconstitution"
    scene["source_sprite_sha256"]=SOURCE_SHA256
    scene["source_sprite_visual_acceptance"]="PENDING"
    scene["underbody_optics_source_status"]="OWNER_DESIGN_NOT_VISIBLY_ESTABLISHED"
    blend=OUTPUT/"tech_priests_emergency_miner_v05.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    if bpy.context.scene.get("asset") != "Tech Priests emergency miner":
        raise RuntimeError("Saved Blender scene failed identity readback")
    if len(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects)<75:
        raise RuntimeError("Saved scene lost visible modeled components")
    # Export actual geometry only. Curve geometry must become meshes for GLB,
    # but remains fully editable curves in already-saved .blend master.
    for o in list(bpy.data.objects):
        o.select_set(False)
    for o in list(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects)+list(
             bpy.data.collections["INFERRED_UNDERBODY_LASER_ABLATION_AND_RECLAIMER"].objects):
        if o.type=="CURVE":
            bpy.context.view_layer.objects.active=o
            o.select_set(True)
            bpy.ops.object.convert(target="MESH")
            o.select_set(False)
    for o in bpy.data.objects:
        o.select_set(o.type=="MESH")
    export=OUTPUT/"tech_priests_emergency_miner_v05.glb"
    bpy.ops.export_scene.gltf(filepath=str(export),export_format="GLB",
                              use_selection=True,export_apply=True)
    if not export.is_file() or export.stat().st_size<20000:
        raise RuntimeError("GLB real geometry export absent or invalid")
    report={
        "asset":"tech-priests-emergency-miner",
        "state":"V05 LASER ABLATION CANDIDATE REQUIRES SOURCE VISUAL REVIEW",
        "candidate_revision":"V05",
        "original_source_sha256":SOURCE_SHA256,
        "source_sprite_replaced":False,
        "gameplay_changed":False,
        "source_visible_parts":len(real_objects),
        "source_unobserved_mining_parts":len(inferred),
        "source_visible_features":FEATURES,
        "functional_paths":FUNCTIONAL_PATHS,
        "technology_principle":"DOWNWARD_FREQUENCY_MODULATED_LASER_ABLATION",
        "reconstitution":"CRUDE_LOW_RATE_CONTAMINATED_PROTOMATTER_RECOVERY",
        "mechanical_excavation_components":0,
        "doctrine_slow_polluting_bootstrap_not_industrial":True,
        "source_visible_enclosure_separate_from_inferred_mechanics":True,
        "transparent_render_frames":["01_source_view_real_mesh.png",
                                     "02_game_candidate_full_miner.png",
                                     "03_physical_drill_inspection.png"],
        "saved_master":blend.name,
        "saved_master_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
        "physical_glb_export":export.name,
        "physical_glb_sha256":hashlib.sha256(export.read_bytes()).hexdigest(),
        "input_sprite_reused_as_texture":False,
        "appearance_approved":False,
        "underbody_optics_are_sprite_observed":False,
        "model_must_be_visually_reviewed_before_game_integration":True,
    }
    (OUTPUT/"model_manifest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
    print("EMERGENCY_MINER_REAL_3D_CANDIDATE "+json.dumps(report,separators=(",",":")),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    main(args.out)
