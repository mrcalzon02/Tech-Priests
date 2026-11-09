#!/usr/bin/env python3
"""Deterministic zero-dependency validator for the TP-MH7 refinery handoff.

No Blender or model inference is invoked. This is only an input-integrity check.
"""
import hashlib
import json
import sys
from pathlib import Path

EXPECTED = [
    ('water-purifier', [3, 3]),
    ('electrolyzer', [3, 4]),
    ('hydrogen-compressor', [3, 4]),
    ('metallization-crucible', [5, 5]),
    ('pelletization-forge', [3, 3]),
    ('pressure-vessel-fabricator', [4, 4]),
    ('canister-assembler', [4, 4]),
]

def main():
    here = Path(__file__).resolve().parent
    j = json.loads((here / 'JOB_SPEC.json').read_text(encoding='utf-8'))
    assert j['schema'] == 'tech-priests.metallic-hydrogen-precursor-work-order.v1'
    assert j['repo'] == 'mrcalzon02/Tech-Priests' and j['branch'] == 'main'
    assert len(j['tasks']) == 7
    for i, ((name, footprint), task) in enumerate(zip(EXPECTED, j['tasks']), 1):
        assert task['stage'] == i and task['id'] == name
        assert task['planned_footprint_tiles'] == footprint
        assert task['target_native_prototype'] is None
        assert task['prototype_footprint_verified'] is False
        assert task['deliverable_status'] == 'not_started'
        for port in task['symbolic_fluid_ports']:
            assert port['native_position'] is None and port['model_mouth_center'] is None
            assert not port['verified']
    board = here / 'references' / Path(j['reference']['path']).name
    assert board.is_file(), f'Missing exact reference image: {board}'
    actual = hashlib.sha256(board.read_bytes()).hexdigest()
    assert actual == j['reference']['sha256'], f'Reference image altered: {actual}'
    assert j['operating_constraints']['workflow_dispatch_authorized_by_this_packet'] is False
    assert j['operating_constraints']['prototype_modifications_authorized'] is False
    assert j['operating_constraints']['render_process_concurrency'] == 1
    print('PACKET_VALID: seven distinct planning footprints, no fake native port positions, reference SHA256=' + actual)
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (AssertionError, KeyError, OSError, json.JSONDecodeError) as exc:
        print('PACKET_INVALID: ' + str(exc), file=sys.stderr)
        sys.exit(1)
