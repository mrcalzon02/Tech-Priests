"""Bounded actual USD animation-import review; no source capture regeneration."""
exec(compile((__import__('pathlib').Path(__file__).parent/'render_a02_usd_reimport.py').read_text().split('camera=s.camera;')[0].replace("O/'idle.usdc'", "O/'cycle.usdc'"), 'usd_import_setup', 'exec'))
records=[]
for frame in [1,25,49,73,97,121,145,169]:
 s.frame_set(frame);bpy.context.view_layer.update()
 path=O/f'imported-cycle-{frame:03}.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 records.append({'frame':frame,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'vertices':sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices) for o in meshes)})
clay=bpy.data.materials.new('INTERCHANGE_REVIEW_CLAY');clay.diffuse_color=(.35,.35,.35,1);s.view_layers[0].material_override=clay;s.frame_set(1);s.render.filepath=str(O/'imported-usd-clay.png');bpy.ops.render.render(write_still=True)
(O/'motion-import-render-receipt.json').write_text(json.dumps({'status':'ACTUAL_CYCLE_USD_IMPORTED_AND_EIGHT_POSES_RENDERED','usd_sha256':hashlib.sha256((O/'cycle.usdc').read_bytes()).hexdigest(),'frames':records,'clay_sha256':hashlib.sha256((O/'imported-usd-clay.png').read_bytes()).hexdigest(),'scope':'Eight bounded review samples, not a full animation raster recapture; no native game integration claimed.'},indent=2)+'\n',encoding='utf-8',newline='\n')
