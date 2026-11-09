#!/usr/bin/env python3
"""Extract Blender greeble scene meshes into independent geometry-first .blend files.

Run from the pinned original scene with Blender 5.x. No source scene writes.
Each bounded batch checkpoints separately; output stays in a private runner cache.
"""
from __future__ import annotations
import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from deatlas_core import SCHEMA, atomic_json, candidate_id, select_batch, sha256_file, verified_checkpoint


def script_args():
    return sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def object_record(obj, evaluated) -> dict:
    corners = [evaluated.matrix_world @ Vector(vertex) for vertex in obj.bound_box]
    if not corners:
        raise ValueError('Empty bounding box')
    return {
        'source_object': obj.name,
        'source_mesh': obj.data.name,
        'source_mesh_vertices': len(obj.data.vertices),
        'source_mesh_faces': len(obj.data.polygons),
        'source_materials_reference_only': [s.material.name if s.material else None for s in obj.material_slots],
        'source_object_bounds': {
            'min': [min(float(v[i]) for v in corners) for i in range(3)],
            'max': [max(float(v[i]) for v in corners) for i in range(3)],
        },
        'source_matrix_world': [[float(v) for v in row] for row in evaluated.matrix_world],
        'source_parent': obj.parent.name if obj.parent else None,
        'source_constraints': [c.type for c in obj.constraints],
        'source_modifiers': [m.type for m in obj.modifiers],
        'source_animation': bool(obj.animation_data),
        'placeholder_materials_stripped': True,
        'geometry_mode': 'evaluated-mesh-independent-no-rig',
        'semantic_class': None,
        'design_family': None,
        'style_tags': [],
        'verified_functional_interfaces': False,
        'visual_review': 'pending',
        'fit_review': 'pending',
        'license_review': 'private donor; derived redistribution not approved',
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', required=True)
    p.add_argument('--offset', type=int, default=0)
    p.add_argument('--limit', type=int, default=8)
    p.add_argument('--resume', action='store_true')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--max-batch-mib', type=int, default=256)
    p.add_argument('--max-part-mib', type=int, default=64)
    a = p.parse_args(script_args())
    if a.max_part_mib < 1 or a.max_batch_mib < 1:
        p.error('Disk budgets must be positive')
    source = Path(bpy.data.filepath).resolve()
    meta = json.loads((HERE / 'source.json').read_text(encoding='utf-8'))
    if not source.is_file() or source.stat().st_size != meta['payload_bytes'] or sha256_file(source) != meta['sha256']:
        raise RuntimeError('Blender input is not the pinned original Drive scene')
    out = Path(a.out).expanduser().resolve()
    if out == source or out == source.parent or out in source.parents or source in out.parents:
        raise ValueError('Extraction path must be separate from source directory')
    names = select_batch([o.name for o in bpy.data.objects if o.type == 'MESH'], offset=a.offset, limit=a.limit)
    plan = {'source_sha256': meta['sha256'], 'total_source_meshes': sum(o.type == 'MESH' for o in bpy.data.objects),
            'offset': a.offset, 'names': names, 'dry_run': a.dry_run,
            'geometry_mode': 'evaluated_mesh_materials_stripped', 'max_batch_mib': a.max_batch_mib}
    print('FMPL_DEATLAS_PLAN', json.dumps(plan, sort_keys=True), flush=True)
    if a.dry_run or not names:
        return
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    output_bytes = 0
    extracted = 0
    skipped = 0
    for ordinal, name in enumerate(names, start=a.offset):
        obj = bpy.data.objects[name]
        part_id = candidate_id(meta['sha256'], name)
        dest = out / 'parts' / part_id
        part = dest / (part_id + '.blend')
        receipt = dest / 'receipt.json'
        if part.exists() or receipt.exists():
            if a.resume and verified_checkpoint(part, receipt, meta['sha256'], name):
                print('FMPL_DEATLAS_RESUME_VERIFIED', part_id, flush=True)
                skipped += 1
                continue
            raise RuntimeError('Existing part or orphaned receipt needs review: ' + str(dest))
        evaluated = obj.evaluated_get(depsgraph)
        source_record = object_record(obj, evaluated)
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
        if mesh is None or len(mesh.vertices) == 0:
            print('FMPL_DEATLAS_SKIP_EMPTY', part_id, flush=True)
            if mesh is not None:
                bpy.data.meshes.remove(mesh, do_unlink=True)
            continue
        export_obj = None
        try:
            mesh.name = part_id + '_geometry'
            # Source materials are generic placeholders, so do NOT replicate them
            # into hundreds of independent scenes. Preserve their names in receipts.
            mesh.materials.clear()
            for polygon in mesh.polygons:
                polygon.material_index = 0
            export_obj = bpy.data.objects.new(name, mesh)
            export_obj.matrix_world = evaluated.matrix_world.copy()
            export_obj['fmpl_source_id'] = meta['id']
            export_obj['fmpl_source_object'] = name
            export_obj['fmpl_part_id'] = part_id
            export_obj['fmpl_state'] = 'unreviewed_geometry_only'
            export_obj['fmpl_native_port_verified'] = False
            dest.mkdir(parents=True, exist_ok=True)
            staged = dest / (part_id + '.staged.blend')
            if staged.exists():
                raise RuntimeError('Stale staged output requires review: ' + str(staged))
            try:
                bpy.data.libraries.write(str(staged), {export_obj}, fake_user=True, compress=True)
                with bpy.data.libraries.load(str(staged), link=False) as (available, unused):
                    available_names = list(available.objects)
                if name not in available_names:
                    raise RuntimeError('Staged Blender file does not contain target object')
                size = staged.stat().st_size
                if size > a.max_part_mib * 1024**2 or output_bytes + size > a.max_batch_mib * 1024**2:
                    raise RuntimeError('Disk budget exceeded; stop and inspect before increasing batch')
                digest = sha256_file(staged)
                # Two-phase checkpoint: if interrupted after part rename, resume rejects
                # the orphan rather than pretending it was successfully extracted.
                os.replace(staged, part)
                source_record.update({
                    'schema': SCHEMA, 'id': part_id, 'ordinal': ordinal,
                    'source_sha256': meta['sha256'], 'status': 'extracted-candidate',
                    'part_sha256': digest, 'part_bytes': size,
                    'local_file': str(part.relative_to(out)),
                    'evaluated_vertices': len(mesh.vertices), 'evaluated_faces': len(mesh.polygons),
                    'original_source_unchanged': True,
                    'blender_library_list_readback': True,
                    'native_reopen_verified': False,
                })
                atomic_json(receipt, source_record)
                output_bytes += size
                extracted += 1
                print('FMPL_DEATLAS_CHECKPOINT', part_id, size, digest, flush=True)
            finally:
                if staged.exists():
                    staged.unlink()
        finally:
            if export_obj is not None:
                bpy.data.objects.remove(export_obj, do_unlink=True)
            if mesh.name in bpy.data.meshes:
                bpy.data.meshes.remove(mesh, do_unlink=True)
    print('FMPL_DEATLAS_BATCH_DONE', json.dumps({'selected': len(names), 'extracted': extracted,
          'resumed': skipped, 'bytes': output_bytes}), flush=True)


if __name__ == '__main__':
    main()
