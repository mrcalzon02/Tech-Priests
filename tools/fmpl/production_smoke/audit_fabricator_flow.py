"""Probe real source/export bores, reservoir cavity and forming-pressure core."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from electrolyzer_state_clips import activate_imported_clip


def scene_tree():
    verts, faces, names = [], [], []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        offset = len(verts)
        verts.extend(obj.matrix_world @ v.co for v in mesh.vertices)
        mesh.calc_loop_triangles()
        for triangle in mesh.loop_triangles:
            faces.append(tuple(offset+i for i in triangle.vertices))
            names.append(obj.name)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(verts, faces, all_triangles=True), names


def probe(tree, names, paths):
    rows = []
    for label, path, radius in paths:
        rays, failures = 0, []
        for a, b in zip(path, path[1:]):
            a, b = Vector(a), Vector(b)
            direction = (b-a).normalized()
            side = direction.cross(Vector((0, 0, 1)))
            if side.length < .01:
                side = direction.cross(Vector((0, 1, 0)))
            side.normalize()
            up = direction.cross(side).normalized()
            offsets = [Vector((0, 0, 0))]+[radius*(side*math.cos(i*math.tau/8)+up*math.sin(i*math.tau/8)) for i in range(8)]
            for offset in offsets:
                rays += 1
                hit, normal, index, distance = tree.ray_cast(a+offset, direction, (b-a).length)
                if hit is not None:
                    failures.append(dict(segment=[list(a), list(b)], offset=list(offset), obstruction=names[index], at=list(hit)))
        rows.append(dict(path=label, rays=rays, probe_radius=radius, passed=not failures, failures=failures))
    # A genuine closed blind end must stop pressure along the workpiece axis.
    hit, normal, index, distance = tree.ray_cast(Vector((-1.10, 0, .95)), Vector((-1, 0, 0)), .20)
    blind = dict(passed=hit is not None and 'welded closed blind end' in names[index], object=names[index] if hit is not None else None)
    return dict(passed=all(r['passed'] for r in rows) and blind['passed'], paths=rows, blind_end=blind)


def main():
    ap = argparse.ArgumentParser()
    for key in ('source', 'glb', 'out'):
        ap.add_argument('--'+key, required=True)
    args = ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    source, glb, out = (Path(getattr(args, k)).resolve() for k in ('source', 'glb', 'out'))
    if out.exists():
        raise FileExistsError('Preserve flow evidence')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    paths = [('external mouth', [(-2.05, .5, .36), (-1.56, .5, .36)], .12),
             ('coaxial reducer', [(-1.54, .5, .3615), (-1.28, .5, .40)], .015)]
    for label in ('local forming-fluid feed', 'reservoir suction standpipe', 'supported high-pressure forming line'):
        obj = next(o for o in bpy.context.scene.objects if o.name.endswith(label))
        paths.append((label, [list(point) for point in obj['flow_path_samples']], .02 if label != 'local forming-fluid feed' else .015))
    paths.extend([
        ('reservoir interior', [(-1.10, .96, .40), (-1.10, 1.10, .40), (-.98, 1.49, .48), (-.98, 1.49, .53)], .015),
        ('cap to mandrel into blank', [(1.61, 0, .95), (.98, 0, .95)], .02),
        ('exposed workpiece pressure volume', [(.98, 0, .95), (-1.10, 0, .95)], .04)])
    report = dict(source_sha256=sha(source), glb_sha256=sha(glb),
                  scope='Center plus eight offset rays along authored bores and reservoir interior, plus actual blind-end obstruction. Geometry continuity evidence only; does not simulate hydraulic performance or certify every seal.')
    report['source'] = probe(*scene_tree(), paths)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    bpy.context.scene.render.fps = 24
    activate_imported_clip(bpy.context.scene, 'idle')
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    report['runtime'] = probe(*scene_tree(), paths)
    report['passed'] = report['source']['passed'] and report['runtime']['passed']
    out.write_text(json.dumps(report, indent=2)+'\n')
    print('FABRICATOR_FLOW', report['passed'], flush=True)
    for stage in ('source', 'runtime'):
        for row in report[stage]['paths']:
            print(stage, row['path'], row['passed'], len(row['failures']), flush=True)
            for failure in row['failures'][:2]:
                print('BLOCKED', failure['obstruction'], failure['at'], flush=True)


if __name__ == '__main__':
    main()
