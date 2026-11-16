"""Independently import both GLBs, inspect their actual geometry and render it."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
args=sys.argv[sys.argv.index('--')+1:]
root=Path(args[0]);reports=[]
for name in (args[1:] or ('chicago-piano','twin-minigun')):
    O=root/name;source=O/(name+'.blend');export=O/(name+'.glb')
    bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene;S.frame_set(1)
    source_points=[o.matrix_world@Vector(p) for o in S.objects if o.type in ('MESH','CURVE') and not o.hide_render for p in o.bound_box]
    source_bounds=[[min(p[j] for p in source_points) for j in range(3)],[max(p[j] for p in source_points) for j in range(3)]]
    keep=[o for o in S.objects if o.type in ('CAMERA','LIGHT')]
    for o in list(S.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(export))
    imported=[o for o in S.objects if o.type=='MESH']
    points=[];triangles=0;degenerate=0;uv_meshes=0;degenerate_objects=[]
    for o in imported:
        prior_degenerate=degenerate
        o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles);uv_meshes+=bool(o.data.uv_layers)
        for v in o.data.vertices:
            p=o.matrix_world@v.co;assert all(math.isfinite(x) for x in p);points.append(p)
        for t in o.data.loop_triangles:
            a,b,c=[o.matrix_world@o.data.vertices[i].co for i in t.vertices]
            if (b-a).cross(c-a).length<1e-10:degenerate+=1
        if degenerate>prior_degenerate:degenerate_objects.append((o.name,degenerate-prior_degenerate))
    bounds=[[min(p[j] for p in points) for j in range(3)],[max(p[j] for p in points) for j in range(3)]]
    assert abs(bounds[0][2]-1.70)<.002,'Groundless/floating cap bearing'
    assert degenerate/max(triangles,1)<.001,(name,degenerate,triangles,degenerate_objects)
    assert all(abs(bounds[i][j]-source_bounds[i][j])<.08 for i in range(2) for j in range(3)),(source_bounds,bounds)
    images=[{'name':im.name,'size':list(im.size),'packed':bool(im.packed_file)} for im in bpy.data.images if im.users and im.source=='FILE']
    assert images and all(min(im['size'])>=128 for im in images)
    S.render.resolution_x=S.render.resolution_y=512;S.render.resolution_percentage=100;S.cycles.samples=8
    turn=next(o for o in S.objects if o.type=='EMPTY' and o.name.startswith('TURRET_TRAVERSE'))
    base_transform=turn.matrix_world.copy()
    review_scale=S.camera.data.ortho_scale
    for view,yaw in [('import-front',0),('import-rear',math.pi),('import-quarter',math.pi/4)]:
        turn.matrix_world=Matrix.Rotation(yaw,4,'Z')@base_transform
        S.camera.data.ortho_scale=review_scale
        for attempt in range(12):
            bpy.context.view_layer.update()
            projected=[world_to_camera_view(S,S.camera,o.matrix_world@Vector(corner)) for o in imported for corner in o.bound_box]
            if all(.025<p.x<.975 and .025<p.y<.975 for p in projected):break
            S.camera.data.ortho_scale*=1.12
        else:raise AssertionError('Runtime-model review does not fit camera')
        S.render.filepath=str(O/(view+'.png'));bpy.ops.render.render(write_still=True)
    clay=bpy.data.materials.new('Independent clay');clay.use_nodes=True
    shader=clay.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(.22,.22,.22,1)
    shader.inputs['Roughness'].default_value=.8
    for o in imported:o.data.materials.clear();o.data.materials.append(clay)
    S.render.filepath=str(O/'import-clay.png');bpy.ops.render.render(write_still=True)
    report={'status':'PASS','name':name,'triangles':triangles,'degenerate_triangles':degenerate,'meshes':len(imported),
      'meshes_with_uv':uv_meshes,'transformed_bounds':bounds,'source_bounds':source_bounds,'images':images,
      'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(export.read_bytes()).hexdigest(),
      'base_included':False}
    (O/'independent-export-inspection.json').write_text(json.dumps(report,indent=2)+'\n');reports.append(report)
(root/'independent-export-inspection.json').write_text(json.dumps({'status':'PASS','models':reports},indent=2)+'\n')
