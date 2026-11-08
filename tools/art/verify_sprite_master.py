"""Independently reopen the saved master and verify capture settings/state/materials."""
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_sprite_frames import camera_record, daylight_record, digest

out = Path(sys.argv[sys.argv.index('--') + 1])
capture = json.loads((out / 'capture.json').read_text())
assert digest(Path(bpy.data.filepath)) == capture['master_sha256'], 'Master checksum changed'
assert {'MODEL', 'RENDER'} <= set(bpy.data.scenes.keys()), 'Missing MODEL/RENDER scenes'
scene = bpy.data.scenes['RENDER']
bpy.context.window.scene = scene
assert camera_record(scene) == capture['camera'], 'Camera changed on reopen'
assert daylight_record(scene, capture['config'].get('animated_lights', [])) == capture['daylight']
assert sum(o.type == 'MESH' for o in scene.objects) == capture['mesh_count']
assert all(image.packed_file for image in bpy.data.images if image.source == 'FILE')
assert scene.render.film_transparent and scene.render.image_settings.color_mode == 'RGBA'
checks = ['saved master SHA256', 'MODEL/RENDER scenes', 'frozen camera and daylight',
          'mesh count', 'packed image maps', 'transparent RGBA']
if capture['config'].get('adapter') == 'campfire-matte-stones':
    stones = [o for o in scene.objects if o.name.startswith('stone_')]
    wood = list(bpy.data.collections['02 | Firewood'].objects)
    flames = [o for o in scene.objects if o.name.startswith('flame_tongue')]
    assert len(stones) == 15 and len(flames) == 6 and len(wood) == 42
    for ob in stones:
        for material in ob.data.materials:
            for node in material.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    assert not node.inputs['Roughness'].is_linked
                    assert abs(node.inputs['Roughness'].default_value - .98) < .0001
                    assert abs(node.inputs['Specular IOR Level'].default_value - .08) < .0001
                    assert node.inputs['Metallic'].default_value == 0
                    assert node.inputs['Coat Weight'].default_value == 0
    switch = next(n for n in wood[0].data.materials[0].node_tree.nodes
                  if n.label == 'FIRE ACTIVE control, 0 cold / 1 burning')
    for frame, active in [(0,False), (13,True)]:
        scene.frame_set(frame)
        assert all(o.hide_render != active for o in flames)
        assert abs(switch.outputs[0].default_value - int(active)) < .001
    checks += ['15 matte stone materials', '42 editable wood objects', '6 keyed flames',
               'frame 0 natural wood / frame 13 charred wood', 'cold/fire visibility']
(out / 'reopen-qa.json').write_text(json.dumps({'passed': True, 'blender': bpy.app.version_string,
                                             'checks': checks}, indent=2)+'\n')
print('REOPEN_VERIFIED', checks)

