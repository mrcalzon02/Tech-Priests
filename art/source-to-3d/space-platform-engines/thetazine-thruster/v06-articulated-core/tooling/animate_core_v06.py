"""Author axial stroke and periodic torsion on the central assembly only.

The derivative requires side-actuator solving and cross-boundary flex rebaking
before it is a valid assembled animation. The platform frame is protected.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

p=argparse.ArgumentParser()
p.add_argument("--source",type=Path,required=True)
p.add_argument("--manifest",type=Path,required=True)
p.add_argument("--out",type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
a.source=a.source.resolve();a.manifest=a.manifest.resolve();a.out=a.out.resolve()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
base=json.loads(a.manifest.read_text(encoding="utf-8"))
assert sha(a.source)==base["native"]["sha256"]
a.out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.source))
s=bpy.context.scene
core=bpy.data.objects["V04 independently suspended engine core"]
frame=bpy.data.objects["V04 engine structural recoil frame"]
chamber=bpy.data.objects["Main pressure chamber"]
old_core={};old_frame={}
for f in range(66):
    s.frame_set(f);bpy.context.view_layer.update()
    old_core[f]=core.matrix_world.copy();old_frame[f]=frame.matrix_world.copy()
assert core.parent is None,"Expected independent world-space assembly root"
s.frame_set(0);bpy.context.view_layer.update()
pivot_world=sum((chamber.matrix_world@Vector(c)for c in chamber.bound_box),Vector())/8
pivot_core=old_core[0].inverted()@pivot_world
axis0=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))))
seed=6841
rng=random.Random(seed)
phase_sets=[[rng.uniform(-math.pi,math.pi)for _ in range(4)]for _ in range(2)]


def smooth_noise(phi,phases):
    weights=(1,.60,.35,.22)
    raw=sum(w*math.sin(k*phi+off)for k,w,off in zip((5,7,9,11),weights,phases))/sum(weights)
    return raw*math.sin(phi/2)**2


core.animation_data_clear()
core.rotation_mode="QUATERNION"
rows=[]
for f in range(66):
    s.frame_set(f)
    phi=math.tau*((f-1)%64)/64
    running=f!=0
    axial=(.135*math.sin(phi)+.025*math.sin(2*phi)+.018*smooth_noise(phi,phase_sets[0]))if running else 0
    torsion_deg=(.90*math.sin(phi+.80)+.25*math.sin(2*phi-.40)+.10*smooth_noise(phi,phase_sets[1]))if running else 0
    old=old_core[f]
    rotation_delta=old.to_3x3()@old_core[0].to_3x3().inverted()
    axis=(rotation_delta@axis0).normalized()
    pivot=old@pivot_core
    delta=(Matrix.Translation(axis*axial)@Matrix.Translation(pivot)@
           Quaternion(axis,math.radians(torsion_deg)).to_matrix().to_4x4()@Matrix.Translation(-pivot))
    core.matrix_world=delta@old
    for data_path in("location","rotation_quaternion","scale"):core.keyframe_insert(data_path,frame=f)
    bpy.context.view_layer.update()
    assert max(abs(frame.matrix_world[i][j]-old_frame[f][i][j])for i in range(4)for j in range(4))<1e-8
    rows.append({"frame":f,"phase":phi,"axial_stroke_bu":axial,"torsion_deg":torsion_deg,
                 "axis_world":list(axis),"pivot_world":list(pivot),"baseline_core_world":[list(r)for r in old],
                 "authored_core_world":[list(r)for r in core.matrix_world]})
action=core.animation_data.action
action.name="V06 central axial stroke and sinusoidal torsion"
try:
    curves=action.fcurves
except AttributeError:
    curves=[]
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:curves.extend(bag.fcurves)
for fc in curves:
    for key in fc.keyframe_points:key.interpolation="LINEAR"
assert max(abs(rows[1]["authored_core_world"][i][j]-rows[65]["authored_core_world"][i][j])for i in range(4)for j in range(4))<1e-6
s.frame_set(1);bpy.context.view_layer.update()
target=a.out/"thetazine-v06-core-motion.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
record={"status":"CORE_STROKE_AND_TORSION_AUTHORED_REQUIRES_SIDE_ACTUATORS_AND_FLEX_RETARGET",
        "input_source":{"path":str(a.source),"sha256":sha(a.source)},"input_manifest_sha256":sha(a.manifest),
        "native":{"path":str(target),"sha256":sha(target)},"script_sha256":sha(Path(__file__)),
        "moving_root":core.name,"protected_fixed_root":frame.name,"physical_pivot_core_local":list(pivot_core),
        "nominal_thrust_axis":list(axis0),"noise_seed":seed,"noise_phases":phase_sets,"cycle_fps":30,"working_frames":[1,64],"wrap":65,
        "axial_range_bu":[min(r["axial_stroke_bu"]for r in rows[1:65]),max(r["axial_stroke_bu"]for r in rows[1:65])],
        "added_torsion_range_deg":[min(r["torsion_deg"]for r in rows[1:65]),max(r["torsion_deg"]for r in rows[1:65])],
        "poses":rows,"ownership":"Existing occasional lateral/roll knocks are retained in the sampled baseline. New axial stroke and small periodic torque act about the physical chamber axis. Fixed frame, decks, tanks and external interfaces remain on their original roots.",
        "next_required":"Solve the two large side actuators from actual fixed/moving attachment pivots; retarget all fixed-to-core hoses/bellows and check all66 poses before accepting assembly."}
(a.out/"core-motion.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
print("V06_CORE_MOTION_AUTHORED",record["axial_range_bu"],record["added_torsion_range_deg"],flush=True)
