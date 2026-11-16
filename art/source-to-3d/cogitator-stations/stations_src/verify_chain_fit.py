"""Check captured chain geometry on saved native models. Run with Blender -P:
verify_chain_fit.py -- <scene-folder> <report.json>
"""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np


def world_vertices(obj):
    coords = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", coords)
    transform = np.array(obj.matrix_world)
    return coords.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3]


def linked_through(oval, path):
    """Algebraic count of oriented crossings inside the oval's planar disk."""
    center = oval.mean(axis=0)
    _, _, basis = np.linalg.svd(oval - center, full_matrices=False)
    normal = basis[2]
    polygon = (oval - center) @ basis[:2].T
    edges = np.roll(polygon, -1, axis=0) - polygon
    count = 0
    for start, end in zip(path, path[1:]):
        a, b = (start - center) @ normal, (end - center) @ normal
        if (a > 0) == (b > 0):
            continue
        hit = start + (end - start) * (a / (a - b))
        rays = (hit - center) @ basis[:2].T - polygon
        signs = edges[:, 0] * rays[:, 1] - edges[:, 1] * rays[:, 0]
        if np.all(signs >= -1e-9) or np.all(signs <= 1e-9):
            count += 1 if b > a else -1
    return abs(count) == 1


def segment_clearance(a, b):
    """Exact closest distance between two sets of finite centerline segments."""
    a0, a1 = a[:-1, None], a[1:, None]
    b0, b1 = b[None, :-1], b[None, 1:]
    u, v, w = a1 - a0, b1 - b0, a0 - b0
    dot = lambda x, y: np.sum(x * y, axis=-1)
    aa, ab, bb, aw, bw = dot(u, u), dot(u, v), dot(v, v), dot(u, w), dot(v, w)
    det = aa * bb - ab * ab
    s = np.divide(ab * bw - bb * aw, det, out=np.zeros_like(det), where=det > 1e-16)
    t = np.divide(aa * bw - ab * aw, det, out=np.zeros_like(det), where=det > 1e-16)
    def distance(s, t):
        return np.linalg.norm(w + s[..., None] * u - t[..., None] * v, axis=-1)
    inside = (det > 1e-16) & (s >= 0) & (s <= 1) & (t >= 0) & (t <= 1)
    minima = [np.where(inside, distance(s, t), np.inf).min()]
    for end in (np.zeros_like(det), np.ones_like(det)):
        minima.append(distance(end, np.clip((bw + ab * end) / bb, 0, 1)).min())
        minima.append(distance(np.clip((ab * end - aw) / aa, 0, 1), end).min())
    return float(min(minima))


class ContactCheck:
    def __init__(self, objects):
        self.objects = objects
        self.bounds = {}
        self.trees = {}
        for name, obj in objects.items():
            corners = np.array([obj.matrix_world @ Vector(p) for p in obj.bound_box])
            self.bounds[name] = (corners.min(0), corners.max(0))

    def tree(self, name):
        if name not in self.trees:
            obj = self.objects[name]
            self.trees[name] = BVHTree.FromPolygons(
                world_vertices(obj), [tuple(face.vertices) for face in obj.data.polygons])
        return self.trees[name]

    def overlaps(self, first, second):
        lo, hi = self.bounds[first]
        other_lo, other_hi = self.bounds[second]
        if np.any(lo > other_hi) or np.any(other_lo > hi):
            return False
        return bool(self.tree(first).overlap(self.tree(second)))


def check_station(file):
    bpy.ops.wm.open_mainfile(filepath=str(file))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = {o.name: o.evaluated_get(depsgraph) for o in bpy.context.scene.objects if o.type == "MESH"}
    contact = ContactCheck(meshes)
    links = sorted(n for n in meshes if " | tie chain | forged link " in n)
    clashes = sorted({tuple(sorted((n, m))) for n in links for m in meshes
                      if m != n and contact.overlaps(n, m)})
    sides = {}
    ok = not clashes
    for side in ("Port", "Starboard"):
        names = [n for n in links if n.startswith(side + " |")]
        stock = float(meshes[names[0]]["stock_radius"])
        # The native swept bar has ten vertices around each cross-section.
        lines = [world_vertices(meshes[n]).reshape(-1, 10, 3).mean(axis=1) for n in names]
        closed = [np.vstack((line, line[0])) for line in lines]
        captures = [linked_through(a, b) for a, b in zip(lines, closed[1:])]
        gaps = [segment_clearance(a, b) - 2 * stock for a, b in zip(closed, closed[1:])]
        pins = []
        for i, mount, seat in ((0, "upper knee", "tapered engine casting"),
                               (-1, "anchor shoe", "split foundation shoes")):
            name = side + " | tie chain | " + mount
            pin = meshes[name + " | hardened cross pin"]
            verts = world_vertices(pin)
            axis = np.asarray(pin.matrix_world.translation)
            ends = np.array([[x, axis[1], axis[2]] for x in (verts[:, 0].min(), verts[:, 0].max())])
            radius = np.linalg.norm(verts[:, 1:] - axis[1:], axis=1).max()
            gap = segment_clearance(closed[i], ends) - stock - radius
            plate = name + " | bolted backplate"
            touched = sorted(n for n in meshes if " | tie chain | " not in n and contact.overlaps(plate, n))
            # These three are joined meshes containing the landings, straps and their mounting studs.
            allowable = ("tapered engine casting", "split foundation shoes", "service door and buttresses",
                         "studs and instrumentation")
            seated = any(n.endswith(" | " + seat) for n in touched)
            hardware_clashes = [n for n in touched if not n.endswith(allowable)]
            captured = bool(linked_through(lines[i], ends))
            ok = ok and captured and gap > 0 and seated and not hardware_clashes
            pins.append({"mount": mount, "passes_through_link": captured,
                         "pin_diameter_bu": round(float(2 * radius), 6),
                         "stock_clearance_bu": round(float(gap), 7),
                         "plate_seated_on": seat if seated else None,
                         "plate_hardware_intersections": hardware_clashes})
        ok = ok and len(names) == 11 and all(captures) and min(gaps) > 0
        sides[side] = {
            "link_count": len(lines), "interlocked_neighbour_pairs": sum(captures),
            "stock_diameter_bu": round(2 * stock, 6),
            "inside_width_bu": round(float(meshes[names[0]]["link_inner_width"]), 6),
            "outside_length_bu": round(float(np.linalg.norm(lines[0][:,None] - lines[0][None,:], axis=2).max() + 2 * stock), 6),
            "minimum_neighbour_clearance_bu": round(min(gaps), 7), "pins": pins}
    with open(file, "rb") as handle:
        sha = hashlib.file_digest(handle, "sha256").hexdigest()
    return {"native_sha256": sha, "passed": bool(ok), "link_mesh_intersections": clashes, "chains": sides}


if __name__ == "__main__":
    folder, report = map(Path, sys.argv[sys.argv.index("--") + 1:])
    ranks = ("junior", "intermediate", "senior", "planetary-magos", "void")
    results = {r: check_station((folder / (r + ".blend")).resolve()) for r in ranks}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(results, indent=2) + "\n")
    failed = [r for r in ranks if not results[r]["passed"]]
    if failed:
        raise RuntimeError("Chain fit failures for " + ", ".join(failed))
