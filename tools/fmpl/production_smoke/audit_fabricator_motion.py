"""Triangle-intersection diagnostic across every authored fabricator frame.

Reports contacts rather than assuming that every intersection is a defect.
Only moving assemblies versus other assemblies are compared; declared assembly
contacts are identified explicitly and are never silently discarded.
"""
import argparse
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from electrolyzer_state_clips import activate_imported_clip


def geometry(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        vertices = [obj.matrix_world @ v.co for v in mesh.vertices]
        faces = [tuple(p.vertices) for p in mesh.polygons]
        bounds = [(min(v[i] for v in vertices), max(v[i] for v in vertices)) for i in range(3)]
        return BVHTree.FromPolygons(vertices, faces), bounds
    finally:
        evaluated.to_mesh_clear()


def assembly(obj):
    if obj.parent and 'upper die hinge control' in obj.parent.name:
        return 'hinged frame'
    if obj.parent and 'welding travel control' in obj.parent.name:
        return 'welding trolley'
    if 'upper die lift cylinder' in obj.name or 'upper die lift piston' in obj.name:
        return 'lift actuator'
    if obj.data.shape_keys or any(k in obj.name for k in ('welded sheet flange', 'longitudinal weld seam', 'welded closed blind end')):
        return 'workpiece'
    return 'static'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--glb')
    ap.add_argument('--substeps', type=int, default=4)
    args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
    source, out = Path(args.source).resolve(), Path(args.out).resolve()
    if out.exists():
        raise FileExistsError('Preserve motion diagnostics')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    if args.glb:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(Path(args.glb).resolve()))
    scene = bpy.context.scene
    scene.render.fps = 24
    if args.glb:
        activate_imported_clip(scene, 'idle')
    scene.frame_set(0)
    objects = [o for o in scene.objects if o.type == 'MESH']
    groups = {o: assembly(o) for o in objects}
    fixed = {o: geometry(o) for o in objects if groups[o] == 'static'}
    receipt = json.loads((source.parent / 'construction-receipt.json').read_text())
    declared = {frozenset((r['a'], r['b'])): r['label'] for r in receipt['contacts']}
    moving = [o for o in objects if groups[o] != 'static']
    pairs = [(a, b) for i, a in enumerate(objects) for b in objects[i+1:]
             if groups[a] != groups[b] and (a in moving or b in moving)]
    hits = {}
    samples = [0]+[1+i/args.substeps for i in range(288*args.substeps+1)]
    for index, frame in enumerate(samples):
        if args.glb:
            activate_imported_clip(scene, 'idle' if frame == 0 else 'working')
        time = max(0, frame-1) if args.glb else frame
        scene.frame_set(int(time), subframe=time-int(time))
        bpy.context.view_layer.update()
        trees = {**fixed, **{o: geometry(o) for o in moving if max(o.scale) > .001}}
        for a, b in pairs:
            if a not in trees or b not in trees:
                continue
            ta, ba = trees[a]
            tb, bb = trees[b]
            if any(min(ba[i][1], bb[i][1])-max(ba[i][0], bb[i][0]) < .0001 for i in range(3)):
                continue
            overlap = ta.overlap(tb)
            if overlap:
                key = (a.name, b.name)
                if key not in hits:
                    hits[key] = dict(a=a.name, b=b.name, groups=[groups[a], groups[b]],
                                     declared_contact=declared.get(frozenset(key)), frames=[], maximum_triangle_pairs=0)
                row = hits[key]
                row['frames'].append(frame)
                row['maximum_triangle_pairs'] = max(row['maximum_triangle_pairs'], len(overlap))
        if index % (48*args.substeps) == 0:
            print('MOTION_FRAME', frame, 'CONTACT_PAIRS', len(hits), flush=True)
    for row in hits.values():
        names = [name.split(' | ')[-1] for name in (row['a'], row['b'])]
        welding = 'actual welding contact tip' in names and any(n in names for n in (
            'welded two-plate pressure blank', 'welded sheet flange -0.535', 'actual longitudinal weld seam -0.535'))
        row['review'] = row['declared_contact'] or ('Intentional contact tip at the authored welded edge during seam traversal' if welding else None)
    unexpected = [row for row in hits.values() if not row['review']]
    report = dict(source_sha256=sha(source), glb_sha256=sha(args.glb) if args.glb else None,
                  samples=len(samples), sample_interval_frames=1/args.substeps,
                  reviewed_contacts_passed=not unexpected, unexpected_pairs=len(unexpected), intersection_pairs=list(hits.values()),
                  scope='Evaluated world-space triangle intersections at quarter-frame intervals across distinct moving/static assemblies. Declared guide/seal/piston joints and welding-tip edge contacts are explicit. Does not certify containment, continuous unsampled intervals or hydraulic flow.')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2)+'\n')
    for row in hits.values():
        print('CONTACT', row['a'].split(' | ')[-1], '/', row['b'].split(' | ')[-1],
              'FRAMES', min(row['frames']), max(row['frames']), 'COUNT', len(row['frames']),
              'DECLARED', row['declared_contact'], flush=True)


if __name__ == '__main__':
    main()
