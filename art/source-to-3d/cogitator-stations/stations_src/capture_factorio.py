"""Capture approved cogitators into directional Factorio color and shadow atlases.

python capture_factorio.py --repo <Tech-Priests> --work <scratch> --blender <blender>
Blender 5.0.1 with Cycles CPU denoising, plus Python with Pillow and NumPy.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

RANKS = ('junior', 'intermediate', 'senior', 'planetary-magos', 'void')
# The consoles face Blender -Y (south) at the authored orientation.
HEADINGS = {'north': 180, 'east': 90, 'south': 0, 'west': 270}
SOURCE_PIXELS = 512
SPAN = 5.0
HIGHEST_QUALITY = 48
TARGET = (0.0, 0.0, math.sqrt(2.0))
ASSET = Path('art/source-to-3d/cogitator-stations')
GAME = Path('tech-priests_src/graphics/entity/cogitator-station/fmpl')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def capture_geometry(scene, dest):
    import bpy
    import numpy as np
    from mathutils import Vector

    graph = bpy.context.evaluated_depsgraph_get()
    vertices, triangles, offset = [], [], 0
    for original in sorted(scene.objects, key=lambda ob: ob.name):
        if original.type != 'MESH' or original.hide_render:
            continue
        obj = original.evaluated_get(graph)
        mesh = obj.data
        coords = np.empty(len(mesh.vertices) * 3, np.float32)
        mesh.vertices.foreach_get('co', coords)
        transform = np.asarray(obj.matrix_world)
        vertices.append(coords.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3])
        mesh.calc_loop_triangles()
        indices = np.empty(len(mesh.loop_triangles) * 3, np.int32)
        mesh.loop_triangles.foreach_get('vertices', indices)
        triangles.append(indices.reshape(-1, 3) + offset)
        offset += len(mesh.vertices)
    # Ground projection follows the optical axis of the accepted scene's key light.
    key = scene.objects['Broad warm window']
    ray = key.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    if ray.z >= 0:
        raise ValueError('Key light must be aimed toward the ground')
    np.savez_compressed(dest, verts=np.concatenate(vertices), tris=np.concatenate(triangles),
                        slope=[ray.x / -ray.z, ray.y / -ray.z])


def blender_worker(repo, folder):
    import bpy
    sys.path.insert(0, str(repo / 'tools/art'))
    import render_sprite_frames as worker
    scene = bpy.context.scene
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    scene.render.use_persistent_data = True
    capture_geometry(scene, folder / 'geometry.npz')
    sys.argv = ['blender', '--', '--config', str(folder / 'profile.json'), '--out', str(folder)]
    worker.main()


def shadow_from_geometry(geometry, angle):
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    x, y, z = geometry['verts'].T
    xx, yy = ((x, y), (-y, x), (-x, -y), (y, -x))[angle // 90]
    kx, ky = geometry['slope']
    # The shadow is registered to the same ground origin as the color plate.
    # Its center is one tile right and one quarter tile up (body center is one tile up).
    size = SOURCE_PIXELS * 2
    scale = size / SPAN
    px = size * .5 + (xx + kx * z - 1.0) * scale
    py = size * .5 - ((yy + ky * z) * math.sqrt(.5) - .25) * scale
    if min(px.min(), py.min()) < 3 or max(px.max(), py.max()) >= size - 3:
        raise ValueError('Projected geometry exceeds shadow canvas')
    pixels = np.rint(np.column_stack([px, py])).astype(np.int32)
    mask = Image.new('L', (size, size))
    drawing = ImageDraw.Draw(mask)
    for poly in pixels[geometry['tris']].reshape(-1, 6).tolist():
        drawing.polygon(poly, fill=110)
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    img.putalpha(mask.filter(ImageFilter.GaussianBlur(size / 350)))
    return img


def pack(folder, rank, target):
    import numpy as np
    from PIL import Image
    capture = json.loads((folder / 'capture.json').read_text())
    if capture['material_changes'] or len(capture['daylight']) != 4:
        raise ValueError('Unexpected changes to approved materials or lighting rig')
    if capture['persistent_camera_count'] != 1 or capture['camera_policy'] != 'fmpl.factorio45.v1':
        raise ValueError('Missing FMPL camera audit')
    frames = {frame['angle']: frame for frame in capture['frames']}
    if len(frames) != 4 or len({frame['sha256'] for frame in frames.values()}) != 4:
        raise ValueError('Expected four distinct rendered rotations')
    layers = {'body': [], 'shadow': []}
    with np.load(folder / 'geometry.npz') as geometry:
        slope = list(geometry['slope'])
        for heading, angle in HEADINGS.items():
            info = frames[angle]
            path = folder / info['path']
            if sha(path) != info['sha256']:
                raise ValueError('Capture hash mismatch for ' + heading)
            with Image.open(path) as img:
                body = img.copy()
            if body.mode != 'RGBA' or body.size != (SOURCE_PIXELS, SOURCE_PIXELS):
                raise ValueError('Unexpected source size or mode')
            box = body.getchannel('A').point(lambda a: 255 if a > 2 else 0).getbbox()
            if not box or min(box[:2]) < 1 or max(box[2:]) >= SOURCE_PIXELS:
                raise ValueError('Color plate clipped or empty')
            layers['body'].append(body)
            layers['shadow'].append(shadow_from_geometry(geometry, angle))

    outputs = {}
    target.mkdir(exist_ok=True, parents=True)
    for quality, size in [('hr', 320), ('sd', 160)]:
        for name, images in layers.items():
            sprite = Image.new('RGBA', (size, size * 4))
            for row, img in enumerate(images):
                cell = img.resize((size, size), Image.Resampling.LANCZOS)
                sprite.paste(cell, (0, row * size))
            suffix = '' if name == 'body' else '-shadow'
            path = target / f'{rank}{suffix}-{quality}.png'
            sprite.save(path, compress_level=9)
            with Image.open(path) as actual:
                if actual.tobytes() != sprite.tobytes():
                    raise ValueError('Packed atlas readback differs')
            outputs[path.name] = sha(path)
    return {'rank': rank, 'source_sha256': capture['source_sha256'], 'renders': {
        heading: frames[angle]['sha256'] for heading, angle in HEADINGS.items()},
        'color_management': capture['world']['color_management'], 'key_shadow_slope_xy': slope,
        'camera': capture['camera'], 'lights': capture['daylight'], 'outputs': outputs}


def run(opts):
    folder = opts.work.resolve() / opts.rank
    folder.mkdir(exist_ok=True, parents=True)
    repo = opts.repo.resolve()
    src = (opts.models or repo / ASSET / 'models').resolve() / (opts.rank + '.blend')
    if not opts.pack_only:
        cfg = {'schema': 1, 'asset': opts.rank, 'camera_policy': 'fmpl.factorio45.v1',
               'capture_kind': 'entity', 'orientation_policy': 'rotatable', 'source_size': SOURCE_PIXELS,
               'directions': [0, 90, 180, 270], 'states': {'idle': [1]}, 'sizes': [160, 320],
               'samples': HIGHEST_QUALITY, 'seed': 754, 'columns': 1, 'fps': 1, 'pivot': [0, 0, 0],
               'camera_override': {'type': 'ORTHO', 'target': TARGET, 'distance': 8,
                   'ortho_scale': SPAN, 'elevation_deg': 45, 'azimuth_deg': 0, 'shift_x': 0, 'shift_y': 0}}
        (folder / 'profile.json').write_text(json.dumps(cfg, indent=2))
        subprocess.run([opts.blender, '-b', '--factory-startup', '-t', str(opts.threads), str(src),
                        '--python-exit-code', '1', '-P', str(Path(__file__).resolve()), '--',
                        '--worker', str(repo), str(folder)], check=True)
    receipt = pack(folder, opts.rank, (opts.output_root or repo) / GAME)
    if receipt['source_sha256'] != sha(src):
        raise ValueError('Approved source differs from capture')
    (folder / 'verified.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    if '--worker' in sys.argv:
        repo_path, folder_path = sys.argv[-2:]
        blender_worker(Path(repo_path), Path(folder_path))
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('--repo', type=Path, required=True)
        parser.add_argument('--work', type=Path, required=True)
        parser.add_argument('--rank', choices=RANKS)
        parser.add_argument('--models', type=Path)
        parser.add_argument('--output-root', type=Path)
        parser.add_argument('--blender', default='blender')
        parser.add_argument('--threads', type=int, default=4)
        parser.add_argument('--pack-only', action='store_true')
        opts = parser.parse_args()
        for rank in ([opts.rank] if opts.rank else RANKS):
            opts.rank = rank
            run(opts)
