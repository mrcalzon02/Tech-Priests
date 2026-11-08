"""Blender-side independent reopen gate for the reconstructed boiler source."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import bpy

p = argparse.ArgumentParser()
p.add_argument('--record', type=Path, required=True)
p.add_argument('--rebuilt-record', type=Path, required=True)
p.add_argument('--report', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
expected = json.loads(a.record.read_text(encoding='utf-8'))
rebuilt = json.loads(a.rebuilt_record.read_text(encoding='utf-8'))
fields = ['source_sha256', 'source_mesh_count', 'source_mesh_vertex_hashes',
          'emissive_animations', 'rattle_rigs', 'steam_nozzle_object', 'steam_exit_world', 'steam_puffs']
for field in fields:
    assert expected[field] == rebuilt[field], field
for name, digest in expected['source_mesh_vertex_hashes'].items():
    obj = bpy.data.objects[name]
    assert hashlib.sha256(b''.join(struct.pack('3f', *v.co) for v in obj.data.vertices)).hexdigest() == digest, name
s = bpy.context.scene
assert len([o for o in bpy.data.objects if o.type == 'CAMERA']) == 1
puffs = list(bpy.data.collections['V08 ANIMATED STEAM'].objects)
assert len(puffs) == 16
s.frame_set(0)
assert all(o.hide_render for o in puffs)
s.frame_set(25)
assert any(not o.hide_render for o in puffs)
def sample(frame):
    s.frame_set(frame)
    bpy.context.view_layer.update()
    values = []
    for rig in expected['rattle_rigs']:
        values.extend(v for row in bpy.data.objects[rig['rig']].matrix_world for v in row)
    for target in expected['emissive_animations']:
        nodes = bpy.data.materials[target['material']].node_tree.nodes
        node = next((n for n in nodes if n.type == 'EMISSION'), None)
        values.append(float(node.inputs['Strength'].default_value if node else
            next(n for n in nodes if n.type == 'BSDF_PRINCIPLED').inputs['Emission Strength'].default_value))
    for puff in puffs:
        values.extend(puff.location)
        values.extend(puff.scale)
        values.append(puff.data.materials[0].node_tree.nodes['Animated steam density'].outputs[0].default_value)
    return values
first, last = sample(1), sample(97)
loop_error = max(abs(x-y) for x, y in zip(first, last))
assert loop_error < 1e-5, loop_error
samples = [sample(f) for f in (1,13,25,37,49,61,73,85)]
for i in range(48, 48+len(expected['emissive_animations'])):
    assert max(x[i] for x in samples)-min(x[i] for x in samples) > .01
for offset in (0,16,32):
    assert max(abs(x[offset+row*4+3]-first[offset+row*4+3]) for x in samples for row in range(3)) > .001
images = [{'name': i.name, 'packed': bool(i.packed_file), 'size': list(i.size)}
          for i in bpy.data.images if i.source == 'FILE']
assert all(i['packed'] and min(i['size']) > 0 for i in images), images
source = Path(bpy.data.filepath)
report = {'status': 'REBUILT_SOURCE_REOPENED_AND_VERIFIED_NOT_HISTORICAL_BINARY_IDENTITY',
          'approved_v07b_sha256': expected['source_sha256'],
          'source_meshes_exact': len(expected['source_mesh_vertex_hashes']),
          'historical_authoring_record_fields_exact': fields, 'packed_images': images,
          'cold_frame_zero_puffs_hidden': True, 'working_frame_25_has_visible_puffs': True,
          'camera_count': 1, 'native_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'prepared_animation_endpoint_error': loop_error,
          'prepared_rig_and_emission_sample_ranges_pass': True,
          'native_bytes': source.stat().st_size,
          'installed_atlas_equivalence': 'Unproven; source reconstruction does not authorize production atlas replacement.'}
a.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('PREPARED_BOILER_SOURCE_REOPEN_PASS', report['native_sha256'])
