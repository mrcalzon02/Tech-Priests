"""Blender worker for export_sprites.py; retains authored camera and lighting."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def matte_stones(scene):
    """ART-CF-005: dry stones; preserve color, normals and physical geometry."""
    stones = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('stone_')]
    if len(stones) != 15:
        raise ValueError(f'Campfire adapter expects 15 stones, found {len(stones)}')
    changes = []
    materials = {m for o in stones for m in o.data.materials if m}
    for material in sorted(materials, key=lambda m: m.name):
        for node in material.node_tree.nodes:
            if node.type != 'BSDF_PRINCIPLED':
                continue
            values = {'Roughness': 0.98, 'Metallic': 0.0,
                      'Specular IOR Level': 0.08, 'Coat Weight': 0.0}
            before = {}
            for name, value in values.items():
                socket = node.inputs.get(name)
                if socket is None:
                    raise ValueError(f'Unsupported Principled socket: {name}')
                before[name] = {'value': socket.default_value, 'linked': socket.is_linked}
                for link in list(socket.links):
                    material.node_tree.links.remove(link)
                socket.default_value = value
            changes.append({'material': material.name, 'before': before, 'after': values})
    return changes


def camera_record(scene):
    camera = scene.camera
    return {'name': camera.name, 'matrix_world': [list(row) for row in camera.matrix_world],
            'type': camera.data.type, 'ortho_scale': camera.data.ortho_scale,
            'shift_x': camera.data.shift_x, 'shift_y': camera.data.shift_y,
            'resolution': [scene.render.resolution_x, scene.render.resolution_y]}


def daylight_record(scene, animated):
    return [{'name': o.name, 'type': o.data.type, 'energy': o.data.energy,
             'color': list(o.data.color), 'matrix_world': [list(r) for r in o.matrix_world]}
            for o in sorted(scene.objects, key=lambda o: o.name)
            if o.type == 'LIGHT' and o.name not in animated]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--partition', type=int, default=0)
    parser.add_argument('--partition-count', type=int, default=1)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    cfg = json.loads(args.config.read_text())
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = Path(bpy.data.filepath)
    source_hash = digest(source)
    cached = {}
    resume = out / 'resume-index.json'
    if resume.exists():
        receipt = json.loads(resume.read_text())
        if receipt['source_sha256'] != source_hash or receipt['config'] != cfg:
            raise ValueError('Resume source/configuration differs')
        cached = {r['path']: r for r in receipt['frames']}
    model = bpy.context.scene
    if not model.camera or model.camera.data.type != 'ORTHO':
        raise ValueError('Source must provide an authored orthographic camera')
    if model.render.engine != 'CYCLES':
        raise ValueError('This adapter requires a Cycles source scene')
    for image in bpy.data.images:
        if image.source == 'FILE' and not image.packed_file:
            raise ValueError(f'Pack external texture before export: {image.name}')
    changes = []
    if cfg.get('adapter') == 'campfire-matte-stones':
        changes = matte_stones(model)
    elif cfg.get('adapter'):
        raise ValueError('Unknown adapter')
    model.name = 'MODEL'
    model.use_fake_user = True
    scene = model.copy()
    scene.name = 'RENDER'
    # Background Blender may save a different window scene; retain both datablocks.
    scene.use_fake_user = True
    bpy.context.window.scene = scene
    for name in cfg.get('hide_render', []):
        scene.objects[name].hide_render = True
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = cfg['source_size']
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.render.fps = cfg['fps']
    scene.cycles.samples = cfg['samples']
    scene.cycles.seed = cfg['seed']
    scene.cycles.use_animated_seed = False
    scene.cycles.device = 'CPU'
    # Rotate only model hierarchies, about the declared pivot. Camera/daylight stay fixed.
    pivot = bpy.data.objects.new('EXPORT | direction pivot', None)
    scene.collection.objects.link(pivot)
    pivot.location = cfg['pivot']
    excluded = set(cfg.get('exclude_rotation', []))
    roots = set()
    for ob in list(scene.objects):
        if ob.type not in {'MESH', 'ARMATURE', 'CURVE', 'SURFACE', 'META', 'FONT'} or ob.name in excluded:
            continue
        root = ob
        while root.parent:
            root = root.parent
        if root.type in {'CAMERA', 'LIGHT'}:
            raise ValueError('Model hierarchy includes a lighting/camera parent')
        roots.add(root)
    for root in roots:
        root.parent = pivot
        root.matrix_parent_inverse = Matrix.Translation(cfg['pivot']).inverted()
    # A named export profile can override the source camera without modifying its
    # authoring file. Camera and daylight remain stationary across all directions.
    override = cfg.get('camera_override')
    if override:
        if scene.camera.data.type != 'ORTHO':
            raise ValueError('Structure camera must be orthographic')
        elev = math.radians(float(override['elevation_deg']))
        azim = math.radians(float(override['azimuth_deg']))
        distance = float(override['distance'])
        if not (0 < elev < math.pi/2 and distance > 0):
            raise ValueError('Invalid structure camera elevation/distance')
        target = Vector(tuple(float(v) for v in override['target']))
        if len(target) != 3:
            raise ValueError('Camera target must contain three coordinates')
        offset = Vector((math.sin(azim)*math.cos(elev),
                         -math.cos(azim)*math.cos(elev), math.sin(elev))) * distance
        scene.camera.location = target + offset
        scene.camera.rotation_euler = (target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        scene.camera.data.ortho_scale = float(override['ortho_scale'])
        if scene.camera.data.ortho_scale <= 0:
            raise ValueError('Invalid ortho scale')
    scene.frame_set(next(iter(cfg['states'].values()))[0])
    bpy.context.view_layer.update()
    if override:
        actual = math.degrees(math.asin((scene.camera.location-target).normalized().z))
        if abs(actual-float(override['elevation_deg'])) > 0.01:
            raise ValueError(f'Camera pitch mismatch: {actual}')
    camera = camera_record(scene)
    daylight = daylight_record(scene, cfg.get('animated_lights', []))
    world = {'name': scene.world.name if scene.world else None,
             'color_management': {'view_transform': scene.view_settings.view_transform,
                                  'look': scene.view_settings.look,
                                  'exposure': scene.view_settings.exposure,
                                  'gamma': scene.view_settings.gamma}}
    records = []
    ordinal = -1
    first_render = True
    for state, frames in cfg['states'].items():
        for direction, angle in enumerate(cfg['directions']):
            pivot.rotation_euler.z = math.radians(angle)
            for index, frame in enumerate(frames):
                ordinal += 1
                if ordinal % args.partition_count != args.partition:
                    continue
                scene.frame_set(frame)
                bpy.context.view_layer.update()
                # The first Cycles render may finish evaluating an edited camera's
                # depsgraph matrix. Compare against the actual rendered camera thereafter.
                if not first_render and (camera_record(scene) != camera or
                                daylight_record(scene, cfg.get('animated_lights', [])) != daylight):
                    print('CAMERA_REFERENCE', json.dumps(camera), flush=True)
                    print('CAMERA_CHANGED', json.dumps(camera_record(scene)), flush=True)
                    raise ValueError('Camera or daylight changed during capture')
                relative = f'frames/{state}/d{direction:02d}/f{index:03d}.png'
                target = out / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if relative in cached:
                    record = cached[relative]
                    if (record['state'],record['direction'],record['index'],record['timeline_frame']) != (state,direction,index,frame) or digest(target) != record['sha256']:
                        raise ValueError('Resume frame/hash differs: '+relative)
                    records.append(record)
                    print('REUSED '+relative, flush=True)
                    continue
                scene.render.filepath = str(target)
                print(f'CAPTURE {state} direction={angle} frame={frame}', flush=True)
                bpy.ops.render.render(write_still=True)
                if first_render:
                    camera = camera_record(scene)
                    daylight = daylight_record(scene, cfg.get('animated_lights', []))
                    first_render = False
                records.append({'state': state, 'direction': direction, 'angle': angle,
                                'index': index, 'timeline_frame': frame, 'path': relative,
                                'sha256': digest(target)})
                partial = out / f'checkpoint-{args.partition}.json'
                temporary = partial.with_suffix('.tmp')
                temporary.write_text(json.dumps({'source_sha256':source_hash,'config':cfg,'frames':records}))
                temporary.replace(partial)
    pivot.rotation_euler.z = 0
    scene.frame_set(next(iter(cfg['states'].values()))[0])
    model.frame_set(scene.frame_current)
    bpy.context.view_layer.update()
    scene.render.filepath = '//frames/'
    if args.partition == 0:
        bpy.ops.wm.save_as_mainfile(filepath=str(out / 'master.blend'), check_existing=False)
    manifest = {'schema': 1, 'source_sha256': source_hash, 'source_file': source.name,
                'blender': bpy.app.version_string, 'config': cfg, 'camera': camera,
                'daylight': daylight, 'world': world, 'material_changes': changes,
                'mesh_count': sum(o.type == 'MESH' for o in scene.objects),
                'master_sha256': digest(out / 'master.blend') if args.partition == 0 else None, 'frames': records,
                'art_accepted': False, 'engine_integration': 'outside Blender-only scope'}
    name = 'capture.json' if args.partition_count == 1 else f'capture-partition-{args.partition}.json'
    (out / name).write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()

