"""Small actual-GLB cold rock/wiring/bay reviews, no full sprite capture."""
import bpy,json,pathlib,sys,hashlib,math
from mathutils import Vector
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());BLEND=next(O.glob('void-fusion-v*.blend'));GLB=BLEND.with_suffix('.glb');bpy.ops.wm.open_mainfile(filepath=str(BLEND));s=bpy.context.scene
for o in list(s.objects):
    if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
for m in list(bpy.data.materials):bpy.data.materials.remove(m)
for i in list(bpy.data.images):bpy.data.images.remove(i)
bpy.ops.import_scene.gltf(filepath=str(GLB))
strengths=[]
for m in bpy.data.materials:
    if m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED':strengths.append((n,n.inputs['Emission Strength'].default_value));n.inputs['Emission Strength'].default_value=0
s.render.threads_mode='FIXED';s.render.threads=2;s.cycles.samples=16;receipt=[]
views=[('cold-rock-reference-pilot',(1.25,-.70,1.10),(0,.19,.05),1.18,800,800),('cold-canonical-gameview',(0,-8,8),(0,0,0),10.4,1024,1024)]
if '--appearance-witness-only' in sys.argv:views=[('export-clay',(4,7,9),(0,0,0),10.7,760,1100),('export-working-green',(0,-8,8),(0,0,0),10.4,1024,1024)]
if '--detail-review-only' in sys.argv:
    detail=c['functional_detail_v10'];bus=next(g for g in detail['guide_inventory']if'axialbus'in g['clip']and' 1 'in g['clip']);field=next(g for g in detail['guide_inventory']if'fieldguide'in g['clip']);bp=Vector(bus['axis_point']);fp=Vector(field['axis_point']);yc=c['interstone_housings'][3]['center_y']
    views=[('actual-new-cover-guide-detail',(1.55,yc+.85,1.05),(0,yc,.04),1.40,850,850),('actual-axial-guide-detail',tuple(bp+Vector((.65,-.6,.55))),tuple(bp+Vector((-.02,0,-.045))),.65,850,850),('actual-field-guide-detail',tuple(fp+Vector((.50,-.65,.50))),tuple(fp),.34,850,850),('actual-new-whole-body',(0,-8,8),(0,0,0),10.4,1024,1024)]
if '--full-review' in sys.argv:
    views += [('lowered-housing-wire-detail',(1.5,1.7,1.0),(0,c['interstone_housings'][3]['center_y'],.04),1.22,850,850),('export-rear',(-4,7,9),(0,0,0),10.7,760,1100),('export-emitter-detail',(1.1,-5.5,1.0),(0,-4.01,.06),1.48,850,850)]
    dm=bpy.data.materials.new('Review U-bay surrounding platform');dm.use_nodes=True;dm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.09,.12,.14,1)
    for name,lo,hi in [('west',(-1.3,0,-.2),(-.5,4.8,0)),('east',(.5,0,-.2),(1.3,4.8,0)),('fore',(-.5,4.2,-.2),(.5,4.8,0))]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=[(a+b)/2 for a,b in zip(lo,hi)]);o=bpy.context.object;o.name='REVIEW_U_BAY_'+name;o.dimensions=[b-a for a,b in zip(lo,hi)];bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(dm);o.hide_render=True
    views += [('deck-edge-side',(7,-.3,.5),(0,0,0),10,1100,640),('deck-edge-underside',(5,-2,-3),(0,.2,-.05),10,1100,640)]
for name,loc,target,scale,rx,ry in views:
    if name=='export-clay':
        clay=bpy.data.materials.new('Current construction neutral clay');clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.40,.40,.40,1);clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.7;s.view_layers[0].material_override=clay
    else:s.view_layers[0].material_override=None
    for node,value in strengths:node.inputs['Emission Strength'].default_value=value if name=='export-working-green' else 0
    for o in s.objects:
        if o.name.startswith('REVIEW_U_BAY_'):o.hide_render=not name.startswith('deck-edge-')
    s.camera.location=loc;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale;s.render.resolution_x=rx;s.render.resolution_y=ry;s.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True)
    p=O/(name+'.png');receipt.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':('Actual imported GLB native material emission enabled, static working appearance; no distortion/trails/animation claimed.' if name=='export-working-green' else 'Actual imported GLB, emission disabled cold or neutral-clay construction review; U-bay deck only where explicitly named.')})
(O/('detail-review-render-receipt.json'if '--detail-review-only'in sys.argv else'appearance-witness-render-receipt.json' if '--appearance-witness-only' in sys.argv else 'handoff-review-render-receipt.json')).write_text(json.dumps({'glb_sha256':c['glb_sha256'],'renders':receipt},indent=2)+'\n')
print('COLD_HANDOFF_REVIEW_SAVED',len(receipt))

