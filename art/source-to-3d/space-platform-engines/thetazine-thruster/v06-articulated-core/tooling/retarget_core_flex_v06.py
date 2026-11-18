"""Move the24 world-baked leaf flexes into the owning core's local space."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import bpy
from mathutils import Matrix
import numpy as np

p=argparse.ArgumentParser()
p.add_argument("--source",type=Path,required=True)
p.add_argument("--motion",type=Path,required=True)
p.add_argument("--base-manifest",type=Path,required=True)
p.add_argument("--out",type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
for k in("source","motion","base_manifest","out"):setattr(a,k,getattr(a,k).resolve())
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
motion=json.loads(a.motion.read_text(encoding="utf-8"))
assert sha(a.source)==motion["native"]["sha256"]
base=json.loads(a.base_manifest.read_text(encoding="utf-8"))
names=[r["mesh"]for r in base["leaf_regenerative_cooling"]["flex_links"]]
assert len(names)==len(set(names))==24
a.out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.source))
s=bpy.context.scene;core=bpy.data.objects[motion["moving_root"]]
objects=[bpy.data.objects[n]for n in names]
for o in objects:
    assert o.type=="MESH" and o.parent is None,("Unexpected pre-existing flex ownership",o.name)
    assert not o.animation_data or not o.animation_data.action,("Unexpected object-space flex animation",o.name)
    assert o.data.shape_keys and len(o.data.shape_keys.key_blocks)==65,o.name
old_world={n:{}for n in names}
for f in range(66):
    s.frame_set(f);bpy.context.view_layer.update()
    for o in objects:old_world[o.name][f]=o.matrix_world.copy()
old_core={r["frame"]:Matrix(r["baseline_core_world"])for r in motion["poses"]}
records=[]
for o in objects:
    key_rows=[];targets={}
    uv_before=np.array([loop.uv[:]for loop in o.data.uv_layers.active.data],dtype=np.float32)
    for index,key in enumerate(o.data.shape_keys.key_blocks):
        f=0 if index==0 else int(re.search(r"(\d+)$",key.name).group(1))
        assert 0<=f<=64,(o.name,key.name)
        coords=np.empty(len(key.data)*3,dtype=np.float32);key.data.foreach_get("co",coords);coords=coords.reshape(-1,3)
        transform=np.asarray(old_core[f].inverted()@old_world[o.name][f],dtype=np.float64)
        local=(coords.astype(np.float64)@transform[:3,:3].T+transform[:3,3]).astype(np.float32)
        targets[key.name]=local
        key_rows.append({"key":key.name,"source_pose":f,"vertices":len(local)})
    for key in o.data.shape_keys.key_blocks:key.data.foreach_set("co",targets[key.name].reshape(-1))
    basis=targets[o.data.shape_keys.key_blocks[0].name]
    o.data.vertices.foreach_set("co",basis.reshape(-1))
    o.parent=core;o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
    o["v06_motion_ownership"]="Core-local leaf-flex shape poses; previous global core motion factored out before reparenting"
    o.data.update()
    uv_after=np.array([loop.uv[:]for loop in o.data.uv_layers.active.data],dtype=np.float32)
    assert np.array_equal(uv_before,uv_after)
    records.append({"mesh":o.name,"new_parent":core.name,"keys":key_rows,"uv_unchanged":True,
                    "method":"Each original world-baked pose converted by inverse(original_core_world_at_that_pose), then evaluated under new core world matrix. Original relative leaf articulation retained; no double application of prior core knock."})
s.frame_set(1);bpy.context.view_layer.update()
target=a.out/"thetazine-v06-core-and-leaf-flex.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
receipt={"status":"CORE_OWNED_LEAF_FLEX_RETARGETED_REQUIRES_REMAINING_ACTUATOR_AND_INTERFACE_SOLVE",
         "input_source":{"path":str(a.source),"sha256":sha(a.source)},"core_motion":{"path":str(a.motion),"sha256":sha(a.motion)},
         "base_manifest_sha256":sha(a.base_manifest),"script_sha256":sha(Path(__file__)),
         "native":{"path":str(target),"sha256":sha(target)},"retargeted":records,
         "scope":"Only24 originally world-baked leaf flex meshes/shape poses/ownership changed. Other hose classes and side actuators remain for their actual attachment-based solve."}
(a.out/"core-flex-retarget.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print("V06_CORE_LOCAL_LEAF_FLEXES",len(records),flush=True)
