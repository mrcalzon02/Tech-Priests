"""Check the evaluated flexible aerial geometry, anchors and attached tips."""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector

source=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;root=bpy.data.objects['TURRET_TRAVERSE'];anchors={};max_error=0;max_flex=[0,0]
for tick in range(481):
    scene.frame_set(tick+1);bpy.context.view_layer.update();inverse=root.matrix_world.inverted()
    for bank in (0,1):
        obj=bpy.data.objects['FLEXIBLE_RADIO_WHIP_'+str(bank)]
        cap=bpy.data.objects['Flexible whip protective tip'+('' if bank==0 else '.001')]
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
        base=sum((vertex.co for vertex in mesh.vertices[:12]),Vector())/12
        tip=sum((vertex.co for vertex in mesh.vertices[-12:]),Vector())/12
        anchor=inverse@(evaluated.matrix_world@base)
        if tick==0:anchors[bank]=anchor
        assert (anchor-anchors[bank]).length<1e-5,('Aerial mount moved',tick,bank)
        error=(evaluated.matrix_world@tip-cap.matrix_world.translation).length
        max_error=max(max_error,error);assert error<1e-5,('Detached tip',tick,bank,error,list(tip),list(cap.matrix_world.translation),[k.value for k in obj.data.shape_keys.key_blocks])
        keys=obj.data.shape_keys.key_blocks
        max_flex[bank]=max(max_flex[bank],Vector((keys[1].value*.24,keys[2].value*.24)).length)
        evaluated.to_mesh_clear()
assert max_flex[0]>.05 and max_flex[1]>.03
report={'status':'PASS','native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'evaluated_frames':481,'fixed_radio_sockets':True,'tip_attachment_max_error':max_error,'max_tip_deflection':max_flex}
(source.parent/'aerial-geometry-check.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
