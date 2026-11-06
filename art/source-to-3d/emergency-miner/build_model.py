"""Source-grounded editable 3D Emergency Miner v01.

Reconstruct the visible control enclosure as physical Blender geometry.
Keep the *inferred*, mechanically functional-looking bore head in its own
collection. The true original sprite is the sole visual authority; both
renders are diagnostic candidates, never approved game art.
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
        cube(f"Gold upper conduit clip {j}",xx,55,.498,24,39,.036,brass,.003)
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
              .018,MATERIALS["black_wire"])
        for i in range(13):
            y=105+i*21
            bend=10 if i>1 and i<9 else 4
            xi=x-bend*side
            # Physical corrugations rise proud of the underlying hose.
            torus(("L" if side<0 else "R")+f" hydraulic rib {i:02d}",
                  xi,y,.480,.017,.0025,MATERIALS["edge_steel"],
                  rotation=(math.pi/2,0,0))
        for y in (150,284,348):
            cube(("L" if side<0 else "R")+f" steel hose retaining bracket {y}",
                 x,y,.493,44,23,.028,edge,.003)
            screws("Hose bracket stud",[(x,y)],.515)

    FEATURES.extend([
      "chamfered source 1x1 enclosure and thick raised edge", "six structural fasteners",
      "left vertical bearing plate", "top maintenance cover with real vent wells",
      "triple recessed power sockets", "green computer display with tiny geometry",
      "four colored indicator lamps", "three front cable coupling assemblies",
      "real red-green cable conduits and gold clamps",
      "corrugated black hydraulic perimeter with clamps",
      "lower shoe, feet and three overlapping forged reinforcing rails",
    ])


def build_mining_assembly():
    # The exact supplied sprite does not depict a drill. Keep all conjectural
    # mining parts in a SEPARATE Blender collection for honest source comparison.
    global VISIBLE, INFERRED
    saved = VISIBLE
    VISIBLE = INFERRED
    iron=MATERIALS["iron"]
    dark=MATERIALS["black_steel"]
    steel=MATERIALS["edge_steel"]
    gold=MATERIALS["brass"]
    # Rear suspension and visible compact bevelled motor/transmission.
    cube("Inferred underside ore intake frame",340,535,.185,229,95,.115,dark,.008)
    cube("Inferred forward gearbox",340,608,.165,141,110,.095,iron,.009)
    for side in (-1,1):
        x=340+side*82
        cube("Inferred suspension leg",x,594,.165,26,123,.080,steel,.006)
        cylinder("Inferred arm metal kingpin",x,535,.210,.026,.050,gold,20)
        cylinder("Inferred secondary pivot",x,620,.215,.016,.030,dark,20)
    # Axial auger protrudes toward the FRONT/south, below original lower lip.
    # Cylinder Z local is rotated to Y global. Deep helical steel tooth exists.
    cylinder("Inferred drilling spindle",340,688,.165,.040,.28,dark,28,
             rotation=(math.pi/2,0,0))
    cylinder("Inferred replaceable auger guard",340,652,.165,.064,.053,iron,32,
             rotation=(math.pi/2,0,0))
    for y in (635,663):
        torus("Inferred steel bearing guard",340,y,.165,.065,.009,steel,
              rotation=(math.pi/2,0,0))
    helix=[]
    for i in range(100):
        t=i/99
        theta=t*5*math.pi
        helix.append((340+math.cos(theta)*34,
                      653+t*110,
                      .165+math.sin(theta)*width(34)))
    curve("Inferred true continuous helical auger flight",helix,.0075,steel)
    cylinder("Inferred hardened auger point",340,764,.165,.022,.072,
             MATERIALS["brass"],20,rotation=(math.pi/2,0,0))
    # Real collection split: source matched view can be rendered without them.
    VISIBLE=saved


def rig_scene():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Industrial neutral workshop world")
    scene.world=world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.43,.44,.45,1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.65
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x=1000
    scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    scene.render.engine="CYCLES"
    scene.cycles.samples=28
    scene.cycles.use_denoising=True
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
    side=camera("CAMERA_PHYSICAL_ASSEMBLY",(1.0,-2.6,1.3),(0,-.18,.25),1.55)
    def area(name, pos, power, size):
        data=bpy.data.lights.new(name,"AREA")
        data.energy=power
        data.shape='DISK'
        data.size=size
        obj=bpy.data.objects.new(name,data)
        COLLECTION.objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(Vector((0,0,.26))-obj.location).to_track_quat("-Z","Y").to_euler()
    area("Warm studio keylight",(-2.2,-1.9,3.9),475,4.5)
    area("Cool workshop large fill",(1.8,1.5,3.0),320,3.5)
    area("Top lateral fill",(-1.3,2.4,2.6),130,2.8)
    return top,iso,side


def save_render(scene, camera, path, hide_inferred):
    INFERRED.hide_render=hide_inferred
    scene.camera=camera
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    if not path.is_file() or path.stat().st_size < 30000:
        raise RuntimeError("Blender failed to render real machine: "+str(path))


def create_materials():
    material("black_steel",(.055,.053,.052),.65,.64,.19)
    material("iron",(.165,.145,.124),.65,.63,.24)
    material("edge_steel",(.35,.32,.275),.80,.45,.16)
    material("worn_steel",(.245,.217,.185),.76,.56,.27)
    material("crevice",(.011,.016,.014),.18,.78,.06)
    material("brass",(.56,.34,.09),.83,.40,.11)
    material("old_gold",(.36,.22,.076),.84,.41,.13)
    material("copper",(.45,.21,.085),.73,.45,.12)
    material("black_wire",(.022,.023,.026),.2,.85,.09)
    material("red_wire",(.52,.047,.023),.15,.45,.08)
    material("green_wire",(.20,.36,.068),.13,.53,.09)
    material("screen_glass",(.012,.19,.036),.16,.25,0,.5)
    material("dim_green",(.032,.55,.04),.10,.34,0,.9)
    material("bright_green",(.18,.85,.08),.10,.28,0,1.6)
    material("red_light",(.82,.09,.03),.10,.29,0,.8)
    material("amber_light",(.85,.47,.03),.10,.30,0,.9)
    material("green_light",(.16,.67,.05),.10,.32,0,.8)
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
    INFERRED=bpy.data.collections.new("INFERRED_UNDERBODY_MINING_MECHANISM")
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
    save_render(scene,top,OUTPUT/"01_source_view_real_mesh.png",True)
    save_render(scene,iso,OUTPUT/"02_game_candidate_full_miner.png",False)
    save_render(scene,side,OUTPUT/"03_physical_drill_inspection.png",False)
    INFERRED.hide_render=False
    scene.camera=iso
    scene["asset"]="Tech Priests emergency miner"
    scene["source_sprite_sha256"]=SOURCE_SHA256
    scene["source_sprite_visual_acceptance"]="PENDING"
    scene["mining_head_source_status"]="INFERRED_NOT_VISIBLE_IN_SPRITE"
    blend=OUTPUT/"tech_priests_emergency_miner_v01.blend"
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
             bpy.data.collections["INFERRED_UNDERBODY_MINING_MECHANISM"].objects):
        if o.type=="CURVE":
            bpy.context.view_layer.objects.active=o
            o.select_set(True)
            bpy.ops.object.convert(target="MESH")
            o.select_set(False)
    for o in bpy.data.objects:
        o.select_set(o.type=="MESH")
    export=OUTPUT/"tech_priests_emergency_miner_v01.glb"
    bpy.ops.export_scene.gltf(filepath=str(export),export_format="GLB",
                              use_selection=True,export_apply=True)
    if not export.is_file() or export.stat().st_size<20000:
        raise RuntimeError("GLB real geometry export absent or invalid")
    report={
        "asset":"tech-priests-emergency-miner",
        "state":"3D CANDIDATE REQUIRES SOURCE VISUAL REVIEW",
        "original_source_sha256":SOURCE_SHA256,
        "source_sprite_replaced":False,
        "gameplay_changed":False,
        "source_visible_parts":len(real_objects),
        "source_unobserved_mining_parts":len(inferred),
        "source_visible_features":FEATURES,
        "transparent_render_frames":["01_source_view_real_mesh.png",
                                     "02_game_candidate_full_miner.png",
                                     "03_physical_drill_inspection.png"],
        "saved_master":blend.name,
        "saved_master_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
        "physical_glb_export":export.name,
        "physical_glb_sha256":hashlib.sha256(export.read_bytes()).hexdigest(),
        "input_sprite_reused_as_texture":False,
        "appearance_approved":False,
        "underbody_drill_source_observed":False,
        "model_must_be_visually_reviewed_before_game_integration":True,
    }
    (OUTPUT/"model_manifest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
    print("EMERGENCY_MINER_REAL_3D_CANDIDATE "+json.dumps(report,separators=(",",":")),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    main(args.out)
