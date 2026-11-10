"""V21 Emergency Miner: two source-bound, one-view motion candidates.

A: persistent rumble with one scanning cycle.
B: intermittent high-energy scan, stronger transient pressure release.

Never replace gameplay art, invent laser hardware or create extra viewpoints.
Use the existing V21 builder, FMPL camera guard, and FMPL feathered vapor.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FMPL = ROOT / "tools" / "fmpl"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(FMPL))
sys.path.insert(0, str(FMPL / "effects"))

import build_model as miner
from blender_camera_guard import install_canonical_camera, assert_clean, camera_record
from capture_policy import POLICY_ID
from fluid_steam_fx import _feathered_steam_material

FRAMES = [1 + 6 * i for i in range(16)]
KEYS = FRAMES + [97]
FPS = 8
RES = 384
FIXED = ("LAYER_1 ", "SOURCE FOUNDATION ", "Foundation source anchor bolt ")
SCENE_NAME = "EMERGENCY_MINER_V21_MOTION_CANDIDATE"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def center(name):
    ob = bpy.data.objects.get(name)
    if ob is None or ob.type != "MESH":
        raise RuntimeError("Missing actual V21 geometry: " + name)
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return sum(pts, Vector((0, 0, 0))) / len(pts)


def ztop(name):
    ob = bpy.data.objects[name]
    bpy.context.view_layer.update()
    return max((ob.matrix_world @ v.co).z for v in ob.data.vertices)


def build_v21():
    if sha(miner.SOURCE) != miner.SOURCE_SHA256:
        raise RuntimeError("Canonical sprite hash changed: refuse guessed machine")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    miner.MATERIALS.clear()
    miner.FEATURES.clear()
    miner.CABLE_ROUTES.clear()
    miner.COLLECTION = bpy.data.collections.new("Emergency Miner V21 derivative")
    bpy.context.scene.collection.children.link(miner.COLLECTION)
    miner.VISIBLE = bpy.data.collections.new("SOURCE_VISIBLE_CONTROL_ENCLOSURE")
    miner.COLLECTION.children.link(miner.VISIBLE)
    miner.create_materials()
    miner.build_enclosure()
    miner.rig_scene()
    # Identical V21 postprocessing order. Do NOT alter the canonical builder.
    miner.shorten_middle_chassis_preserving_connections()
    miner.retract_front_fascia(20)
    miner.carve_real_chassis_front_recess()
    miner.cut_three_true_maintenance_vents()
    miner.carve_source_corner_foot_faces()
    miner.seat_original_front_face_screws()
    if len(miner.CABLE_ROUTES) != 6:
        raise RuntimeError("V21 cable count changed")
    scene = bpy.context.scene
    profile = {
        "camera_policy": POLICY_ID, "capture_kind": "entity",
        "directions": [0, 90, 180, 270],
        "states": {"motion_candidate": FRAMES},
        "source_size": RES,
        "camera_override": {
            "type": "ORTHO", "elevation_deg": 45, "azimuth_deg": 0,
            "distance": 3.0, "target": [0.0, 0.0, 0.29],
            "ortho_scale": 1.42, "shift_x": 0, "shift_y": 0,
        },
    }
    receipt = install_canonical_camera(scene, profile, bpy)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.frame_start, scene.frame_end, scene.render.fps = 1, 96, FPS
    scene[SCENE_NAME] = True
    scene["source_sha256"] = miner.SOURCE_SHA256
    scene["visual_approval"] = "PENDING"
    scene["original_sprite_replaced"] = False
    scene["camera_receipt_json"] = json.dumps(receipt)
    assert_clean(scene, profile, bpy)
    return profile


def empty(name, location, collection):
    ob = bpy.data.objects.new(name, None)
    collection.objects.link(ob)
    ob.location = location
    ob.empty_display_size = .03
    return ob


def preserve_parent(ob, parent):
    """Flush scale to the world matrix BEFORE reparenting.

    The first native Cycles proof exposed a recurrence of FMPL v1.0.2's
    unit-sized steam-lobe bug: changing ob.scale without depsgraph update
    left an old unscaled matrix_world for preserve_parent to capture.
    """
    bpy.context.view_layer.update()
    world = ob.matrix_world.copy()
    ob.parent = parent
    ob.matrix_world = world
    bpy.context.view_layer.update()


def assert_steam_bounds(lobes, tag):
    """Measured world-space envelope; never render giant hidden FX spheres."""
    bpy.context.view_layer.update()
    for ob, _, _, _ in lobes:
        corners=[ob.matrix_world @ Vector(corner) for corner in ob.bound_box]
        extents=[max(p[i] for p in corners)-min(p[i] for p in corners)
                 for i in range(3)]
        if max(extents) > .15 or min(extents) <= 0:
            raise RuntimeError("Nonphysical steam envelope "+tag+" "+
                               ob.name+" measured="+str(extents))


def rig():
    collection = bpy.data.collections.new("ANIMATION_ONLY__NON_GAMEPLAY")
    bpy.context.scene.collection.children.link(collection)
    body = empty("RIG | armor oscillation", (0, 0, .26), collection)
    upper = empty("RIG | upper photocopier cassette", (0, 0, .39), collection)
    preserve_parent(upper, body)
    still, upper_count, body_count = [], 0, 0
    for ob in list(bpy.data.collections["SOURCE_VISIBLE_CONTROL_ENCLOSURE"].objects):
        if ob.name.startswith(FIXED):
            still.append(ob.name)
            continue
        if ob.name.startswith(("LAYER_2 ", "Middle front source screw ")):
            preserve_parent(ob, body)
            body_count += 1
        else:
            preserve_parent(ob, upper)
            upper_count += 1
    cover = empty("RIG | service cover rattle", center("Mid-level split service cover"), collection)
    preserve_parent(cover, upper)
    preserve_parent(bpy.data.objects["Mid-level split service cover"], cover)
    bpy.context.view_layer.update()
    return collection, body, upper, cover, still, body_count, upper_count


def lamp_material(idx):
    palette = [(.95, .045, .012), (1.0, .47, .018),
               (.12, .86, .045), (.28, .69, .93)]
    mat = bpy.data.materials.new("FX ONLY | diagnostic lamp %d" % idx)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*palette[idx], 1)
    bsdf.inputs["Roughness"].default_value = .28
    bsdf.inputs["Metallic"].default_value = .08
    bsdf.inputs["Emission Color"].default_value = (*palette[idx], 1)
    bsdf.inputs["Emission Strength"].default_value = 0
    for suffix in ("glass and light", "internal lens edge"):
        ob = bpy.data.objects["Status lamp %d %s" % (idx, suffix)]
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    return bsdf.inputs["Emission Strength"]


def make_flicker_surface(name, pos, size, upper, collection):
    mesh = bpy.data.meshes.new(name)
    x, y, z = size
    verts = [(-x/2,-y/2,-z/2),(x/2,-y/2,-z/2),
             (x/2,y/2,-z/2),(-x/2,y/2,-z/2),
             (-x/2,-y/2,z/2),(x/2,-y/2,z/2),
             (x/2,y/2,z/2),(-x/2,y/2,z/2)]
    mesh.from_pydata(verts, [], [(0,1,2,3),(4,7,6,5),(0,4,5,1),
                                 (1,5,6,2),(2,6,7,3),(3,7,4,0)])
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    collection.objects.link(ob)
    ob.location = pos
    mat = bpy.data.materials.new(name + " material")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    trans = nodes.new("ShaderNodeBsdfTransparent")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (.68, .86, 1.0, 1.0)
    emit.inputs["Strength"].default_value = 4.0
    mix = nodes.new("ShaderNodeMixShader")
    links.new(trans.outputs["BSDF"], mix.inputs[1])
    links.new(emit.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    ob.data.materials.append(mat)
    preserve_parent(ob, upper)
    return ob, mix.inputs[0]


def make_scan_effects(upper, collection):
    # Geometry-derived levels; two source-observed seams, not painted stripes.
    svc = center("Mid-level split service cover")
    ctrl = center("Upper controller shared sloped mount")
    svc_top = ztop("Mid-level split service cover")
    ctrl_top = ztop("Upper controller shared sloped mount")
    beam, beam_alpha = make_flicker_surface(
        "FX ONLY | movable light leak in upper service seam",
        (svc.x, svc.y - .047, svc_top - .001),
        (.058, .0028, .0015), upper, collection)
    edge, edge_alpha = make_flicker_surface(
        "FX ONLY | small front chassis light leak",
        (ctrl.x, ctrl.y - .082, ctrl_top - .021),
        (.039, .0023, .0015), upper, collection)
    lamps = []
    for idx, pos in enumerate((beam.matrix_world.translation, edge.matrix_world.translation)):
        data = bpy.data.lights.new("FX ONLY | indirect scan leak %d" % idx, "POINT")
        data.color = (.61, .84, 1.0)
        data.energy = 0
        data.shadow_soft_size = .036
        lamp = bpy.data.objects.new(data.name, data)
        collection.objects.link(lamp)
        lamp.location = pos + Vector((0, -.018, .012))
        preserve_parent(lamp, upper)
        lamps.append(lamp)
    return beam, beam_alpha, edge, edge_alpha, lamps


def make_steam(upper, collection):
    # Reuse the existing FMPL feathered TRUE volume, never a cone or card.
    steam = _feathered_steam_material()
    emissions = [
        ("Physical vent cavity dark well 0", Vector((0, 0, .012))),
        ("Physical vent cavity dark well 2", Vector((0, 0, .012))),
        ("Right lower inspection door", Vector((.07, -.007, .012))),
    ]
    lobes = []
    for vent, adjustment in emissions:
        point = center(vent) + adjustment
        for j in range(3):
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=12, ring_count=8, radius=1.0,
                location=point + Vector((.004 * (j - 1), 0, .008 * j)))
            ob = bpy.context.object
            ob.name = "FX ONLY | steam %s lobe %d" % (vent, j)
            for coll in list(ob.users_collection):
                coll.objects.unlink(ob)
            collection.objects.link(ob)
            ob.data.materials.append(steam)
            ob.scale = (.014, .012, .014)
            preserve_parent(ob, upper)
            lobes.append((ob, ob.location.copy(), j, vent))
    assert_steam_bounds(lobes, "prekey")
    return lobes


def key_value(target, frame, amount):
    target.default_value = float(amount)
    target.keyframe_insert(data_path="default_value", frame=frame)


def wrap_bell(t, at, width):
    d = abs(t - at)
    d = min(d, abs(d - 1))
    return math.exp(-.5 * (d / width) ** 2)


def apply_motion(label, body, upper, cover, light_parts, steam, enabled=None):
    beam, beam_alpha, seam, seam_alpha, lights = light_parts
    body0, upper0, cover0 = body.location.copy(), upper.location.copy(), cover.location.copy()
    beam0, seam0 = beam.location.copy(), seam.location.copy()
    enabled = set(enabled or ("mechanics", "scan", "lamps", "steam"))
    colors = []
    screen_power = None
    if "lamps" in enabled:
        colors = [lamp_material(i) for i in range(4)]
        glass = bpy.data.objects["Recessed luminous green computer glass"]
        screen_mat = glass.data.materials[0].copy()
        screen_mat.name = "FX ONLY | independently flickering LCD"
        glass.data.materials.clear()
        glass.data.materials.append(screen_mat)
        screen_power = screen_mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"]
    for frame in KEYS:
        phase = ((frame - 1) % 96) / 96.0
        wave = 2 * math.pi * phase
        if label == "A":
            force = 1.0
            shock = 0.0
            scan = wrap_bell(phase, .44, .12)
            scan_x = -.15 + .31 * max(0.0, min(1.0, (phase - .20) / .52))
            steam_power = wrap_bell(phase, .29, .08) + .7 * wrap_bell(phase, .73, .07)
        else:
            shock = wrap_bell(phase, .27, .035) + wrap_bell(phase, .71, .033)
            force = .68 + .58 * shock
            scan = max(wrap_bell(phase, .26, .055), wrap_bell(phase, .69, .07))
            scan_x = -.15 + .31 * (((phase * 2.0) + .15) % 1.0)
            steam_power = 1.2 * wrap_bell(phase, .31, .055) + .9 * wrap_bell(phase, .75, .055)
        if "mechanics" in enabled:
            bx = force * (.0010 * math.sin(7*wave) + .00035 * math.sin(13*wave))
            by = force * .0006 * math.sin(9*wave + .35)
            bz = force * .00038 * math.sin(11*wave)
            body.location = body0 + Vector((bx, by, bz))
            body.rotation_euler = (math.radians(.11) * math.sin(6*wave),
                                   math.radians(.14) * math.sin(5*wave),
                                   math.radians(.13) * math.sin(8*wave))
            upper.location = upper0 + Vector((
                force * .0012 * math.sin(9*wave + .8),
                force * .0006 * math.sin(7*wave - .4),
                force * .0005 * math.sin(11*wave + .5)))
            upper.rotation_euler = (math.radians(.16) * force * math.sin(8*wave + .5),
                                    math.radians(.19) * force * math.sin(6*wave - .4),
                                    math.radians(.21) * force * math.sin(7*wave + .25))
            cover.location = cover0 + Vector((0, 0, .00065 * math.sin(13*wave + .3)))
            cover.rotation_euler.z = math.radians(.055) * math.sin(11*wave)
            for obj in (body, upper, cover):
                obj.keyframe_insert(data_path="location", frame=frame)
                obj.keyframe_insert(data_path="rotation_euler", frame=frame)
        if "scan" in enabled:
            beam.location = beam0 + Vector((scan_x, 0, 0))
            beam.keyframe_insert(data_path="location", frame=frame)
            seam.location = seam0 + Vector((.023 * math.sin(2*wave), 0, 0))
            seam.keyframe_insert(data_path="location", frame=frame)
            key_value(beam_alpha, frame, min(.96, .76 * scan))
            key_value(seam_alpha, frame, min(.77, .37 * scan * (.55 + shock)))
            lights[0].location = beam.location + Vector((0, -.018, .016))
            lights[0].keyframe_insert(data_path="location", frame=frame)
            lights[0].data.energy = 5.7 * scan
            lights[1].data.energy = 2.4 * scan
            for light in lights:
                light.data.keyframe_insert(data_path="energy", frame=frame)
        if "lamps" in enabled:
            for i, socket in enumerate(colors):
                trigger = ((frame - 1)//12 + i) % 4 == 0
                key_value(socket, frame, (.2 + (2.2 if trigger else .0)) * (1.0 + .30 * shock))
            key_value(screen_power, frame, .12 + .22 * abs(math.sin(5*wave)) + .35 * scan)
        if "steam" in enabled:
            for obj, rest, index, vent in steam:
                offset = index * .13 + (0 if "vent" in vent else .27)
                p = (phase - offset) % 1.0
                envelope = (wrap_bell(p, .31, .06) + .7 * wrap_bell(p, .75, .06))
                active = min(1.0, envelope * (1.0 if label == "A" else 1.25))
                obj.location = rest + Vector((.006 * index * math.sin(wave),
                                              -.002 * active, .032 * active))
                s = .00015 + .018 * active * (1 + index * .12)
                obj.scale = (s, s * .78, s * 1.5)
                obj.keyframe_insert(data_path="location", frame=frame)
                obj.keyframe_insert(data_path="scale", frame=frame)
    for inspect_frame in (1,25,49,73,97):
        bpy.context.scene.frame_set(inspect_frame)
        assert_steam_bounds(steam, "keyframe-"+str(inspect_frame))
    bpy.context.scene.frame_set(1)


def pack_apng(frames, dest):
    """Pure-stdlib APNG. A real sequence of rendered PNGs, no 2D fabrication."""
    signature = b"\x89PNG\r\n\x1a\n"
    def parse(p):
        data = p.read_bytes()
        if not data.startswith(signature):
            raise RuntimeError("Non-PNG render in animation: " + str(p))
        chunks = []
        pos = 8
        while pos < len(data):
            n = struct.unpack(">I", data[pos:pos+4])[0]
            tag = data[pos+4:pos+8]
            payload = data[pos+8:pos+8+n]
            chunks.append((tag, payload))
            pos += 12+n
        return chunks
    def chunk(tag, payload):
        return struct.pack(">I", len(payload))+tag+payload+struct.pack(
            ">I", zlib.crc32(tag+payload)&0xffffffff)
    all_chunks = [parse(Path(f)) for f in frames]
    first = all_chunks[0]
    ihdr = next(p for t,p in first if t==b"IHDR")
    w,h = struct.unpack(">II", ihdr[:8])
    if any(next(p for t,p in parts if t==b"IHDR") != ihdr for parts in all_chunks):
        raise RuntimeError("Render PNG sizes/color type mismatch across frames")
    out = bytearray(signature)
    out += chunk(b"IHDR", ihdr)
    for tag,payload in first:
        if tag not in (b"IHDR",b"IDAT",b"IEND",b"acTL",b"fcTL",b"fdAT"):
            out += chunk(tag,payload)
    out += chunk(b"acTL", struct.pack(">II", len(frames),0))
    seq = 0
    for idx,parts in enumerate(all_chunks):
        out += chunk(b"fcTL", struct.pack(">IIIIIHHBB", seq,w,h,0,0,1,FPS,0,0))
        seq += 1
        ids = [payload for tag,payload in parts if tag==b"IDAT"]
        if not ids:
            raise RuntimeError("Rendered PNG lacks image data")
        for payload in ids:
            if idx==0:
                out += chunk(b"IDAT", payload)
            else:
                out += chunk(b"fdAT", struct.pack(">I",seq)+payload)
                seq += 1
    out += chunk(b"IEND", b"")
    dest.write_bytes(out)
    return (w,h,len(frames))




def diagnostic_render(scene, out, name):
    """Bounded Cycles stage-isolation render, never claimed as production proof."""
    old_size=(scene.render.resolution_x, scene.render.resolution_y)
    old_samples=scene.cycles.samples
    old_path=scene.render.filepath
    scene.render.resolution_x=scene.render.resolution_y=128
    scene.cycles.samples=8
    scene.frame_set(1)
    target=out/("diag_"+name+".png")
    scene.render.filepath=str(target)
    print("MINER_DIAG_RENDER_BEGIN "+name,flush=True)
    bpy.ops.render.render(write_still=True)
    print("MINER_DIAG_RENDER_END "+name,flush=True)
    if not target.is_file() or target.stat().st_size < 3000:
        raise RuntimeError("No Blender Cycles stage proof: "+name)
    scene.render.resolution_x,scene.render.resolution_y=old_size
    scene.cycles.samples=old_samples
    scene.render.filepath=old_path
    return target


def main(out,diagnostic=False):
    out.mkdir(parents=True,exist_ok=True)
    print('MINER_TRACE 01 begin source V21 build',flush=True)
    profile = build_v21()
    print('MINER_TRACE 02 V21 source built',flush=True)
    base = out/"v21_study_static_master.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(base))
    print('MINER_TRACE 03 base saved',flush=True)
    if diagnostic:
        diagnostic_render(bpy.context.scene,out,'00_base_before_rig')
    result = {"source":"tech-priests-emergency-miner", "source_sha256":miner.SOURCE_SHA256,
              "builder_sha256":sha(HERE/"build_model.py"), "preview_script_sha256":sha(__file__),
              "camera_policy":POLICY_ID, "directions_rendered":[0], "fps":FPS,
              "source_model_unchanged":True,"in_game_art_unchanged":True,
              "owner_visual_approved":False,"frames":FRAMES,"variants":{}}
    for label in ("A","B"):
        print('MINER_TRACE 10 reopen base '+label,flush=True)
        bpy.ops.wm.open_mainfile(filepath=str(base))
        print('MINER_TRACE 11 base reopened '+label,flush=True)
        scene=bpy.context.scene
        print('MINER_TRACE 12 begin camera audit '+label,flush=True)
        assert_clean(scene,profile,bpy)
        print('MINER_TRACE 13 camera audited '+label,flush=True)
        print('MINER_TRACE 14 begin physical rig '+label,flush=True)
        collection, body, upper, cover, still, nb, nu = rig()
        print('MINER_TRACE 15 physical rig ready '+label,flush=True)
        if diagnostic:
            diagnostic_render(scene,out,label+'_01_rig_no_fx')
        print('MINER_TRACE 16 begin scan FX '+label,flush=True)
        parts = make_scan_effects(upper,collection)
        print('MINER_TRACE 17 scan FX ready '+label,flush=True)
        if diagnostic:
            diagnostic_render(scene,out,label+'_02_scan_no_steam')
        print('MINER_TRACE 18 begin FMPL steam '+label,flush=True)
        steam = make_steam(upper,collection)
        print('MINER_TRACE 19 FMPL steam ready '+label,flush=True)
        if diagnostic:
            diagnostic_render(scene,out,label+'_03_steam_unkeyed')
        print('MINER_TRACE 20 begin keyed motion '+label,flush=True)
        if diagnostic:
            for channel in ("mechanics","scan","lamps","steam"):
                print("MINER_CHANNEL_BEGIN "+label+" "+channel,flush=True)
                apply_motion(label,body,upper,cover,parts,steam,enabled={channel})
                print("MINER_CHANNEL_KEYED "+label+" "+channel,flush=True)
                diagnostic_render(scene,out,label+"_04_"+channel)
        else:
            apply_motion(label,body,upper,cover,parts,steam)
        print('MINER_TRACE 21 keyed motion ready '+label,flush=True)
        blend=out/("miner_motion_%s.blend"%label)
        scene["study_variant"]=label
        scene["game_integration_status"]="NOT_INTEGRATED_REVIEW_ONLY"
        # Keep this Blender process's native depsgraph alive after saving.
        # Blender 5.2.3 crashed with C0000409 at inline open_mainfile(A).
        # A and B reopen independently in fresh Blender processes via
        # verify_animation.py; no output is accepted without that gate.
        print('MINER_TRACE 22 begin saving animated source '+label,flush=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        print('MINER_TRACE 23 saved animated source '+label,flush=True)
        assert_clean(scene,profile,bpy)
        print('MINER_TRACE 24 begin foundation stationary check '+label,flush=True)
        fixed_bone=bpy.data.objects["LAYER_1 Foundation perimeter steel slab"]
        scene.frame_set(1)
        fixed_start=tuple(tuple(row) for row in fixed_bone.matrix_world)
        scene.frame_set(49)
        fixed_mid=tuple(tuple(row) for row in fixed_bone.matrix_world)
        scene.frame_set(97)
        fixed_end=tuple(tuple(row) for row in fixed_bone.matrix_world)
        if not (fixed_start==fixed_mid==fixed_end):
            raise RuntimeError("Foundation moved in preview variant "+label)
        print('MINER_TRACE 25 foundation stationary check passed '+label,flush=True)
        folder=out/label
        folder.mkdir(exist_ok=True)
        rendered=[]
        for f in FRAMES:
            print('MINER_TRACE 30 frame '+str(f)+' '+label,flush=True)
            scene.frame_set(f)
            dest=folder/("frame_%03d.png"%f)
            scene.render.filepath=str(dest)
            bpy.ops.render.render(write_still=True)
            print('MINER_TRACE 31 frame rendered '+str(f)+' '+label,flush=True)
            if not dest.exists() or dest.stat().st_size < 3000:
                raise RuntimeError("Missing native render: "+str(dest))
            rendered.append(dest)
        animation=out/("miner_motion_%s.png"%label)
        dims=pack_apng(rendered,animation)
        scene.render.resolution_x=scene.render.resolution_y=43
        scene.frame_set(25)
        native=out/("miner_motion_%s_native43.png"%label)
        scene.render.filepath=str(native)
        bpy.ops.render.render(write_still=True)
        scene.render.resolution_x=scene.render.resolution_y=RES
        result["variants"][label]={"apng":animation.name,"apng_sha256":sha(animation),
           "blend":blend.name,"blend_sha256":sha(blend),"native43":native.name,
           "first_frame":str(rendered[0].relative_to(out)),
           "middle_frame":str(rendered[8].relative_to(out)),
           "sample_count":dims[2],"image_pixels":dims[:2],
           "foundation_static":True,"visible_body_parts":nb,
           "visible_upper_parts":nu,"foundation_parts_fixed":len(still),
           "steam_lobes":9,"scan_emission_sites":2,"actual_camera":camera_record(scene)}
    result["status"]="RENDERED_FOR_OWNER_REVIEW_NOT_GAME_READY"
    (out/"motion_manifest.json").write_text(json.dumps(result,indent=2)+"\n")
    print("EMERGENCY_MINER_MOTION_REVIEW "+json.dumps(result,separators=(",",":")),flush=True)


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--diagnostic",action='store_true')
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:]
    args=parser.parse_args(argv)
    main(args.out.resolve(),diagnostic=args.diagnostic)
