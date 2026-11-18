"""Independent, non-mutating geometry and timing inspection of the supplied V07."""
import bpy, hashlib, json, math, struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

R=Path(__file__).resolve().parents[3]
O=R/'art/source-to-3d/emergency-assembler/v07'
ORIGINAL=O/'tech_priests_emergency_assembler_v07_animated.blend'
EXPECTED_SOURCE_SHA256='00d047b9aa80e13bd148b1dcbd2e5440b4a5e0414d744b446f273b0fc741845d'
assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest()==EXPECTED_SOURCE_SHA256, 'Owner-supplied V07 bytes changed'
def stable_digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def geometry_digest(obj):
    h=hashlib.sha256()
    if obj.type=='MESH':
        for vertex in obj.data.vertices:h.update(struct.pack('<3f',*vertex.co))
        for polygon in obj.data.polygons:h.update(struct.pack('<'+str(len(polygon.vertices))+'I',*polygon.vertices))
        for layer in obj.data.uv_layers:
            for loop in layer.data:h.update(struct.pack('<2f',*loop.uv))
    elif obj.type=='CURVE':
        for spline in obj.data.splines:
            for p in spline.bezier_points if spline.type=='BEZIER' else spline.points:h.update(struct.pack('<'+str(len(p.co))+'f',*p.co))
    return h.hexdigest()
def action_signature(action):
    curves=[]
    if hasattr(action,'fcurves'):curves.extend(action.fcurves)
    for layer in getattr(action,'layers',[]):
        for strip in layer.strips:
            for bag in getattr(strip,'channelbags',[]):curves.extend(bag.fcurves)
    return stable_digest([{'path':c.data_path,'index':c.array_index,'keys':[[list(k.co),k.interpolation,list(k.handle_left),list(k.handle_right),k.handle_left_type,k.handle_right_type] for k in c.keyframe_points]} for c in curves])
def snapshot():
    scene=bpy.context.scene;scene.frame_set(0);bpy.context.view_layer.update()
    return {
      'objects':{o.name:dict(type=o.type,parent=o.parent.name if o.parent else None,
                  matrix=[list(row) for row in o.matrix_world],geometry=geometry_digest(o),
                  materials=[m.name for m in o.data.materials if m] if o.type in {'MESH','CURVE'} else [],
                  action=o.animation_data.action.name if o.animation_data and o.animation_data.action else None)
                 for o in scene.objects},
      'actions':{a.name:action_signature(a) for a in bpy.data.actions},
      'packed_images':{i.name:hashlib.sha256(bytes(i.packed_file.data)).hexdigest() for i in bpy.data.images if i.packed_file},
    }
bpy.ops.wm.open_mainfile(filepath=str(ORIGINAL));original_signature=snapshot()
SRC=ORIGINAL
bpy.ops.wm.open_mainfile(filepath=str(SRC));production_signature=snapshot()
s=bpy.context.scene
def mesh_data(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    try:
        vertices=[evaluated.matrix_world@v.co for v in mesh.vertices]
        polygons=[tuple(p.vertices) for p in mesh.polygons]
        return vertices,polygons
    finally:evaluated.to_mesh_clear()
def bvh(obj):
    vertices,polygons=mesh_data(obj)
    return BVHTree.FromPolygons(vertices,polygons,all_triangles=False,epsilon=0)
def point(obj):return obj.matrix_world.translation.copy()
def arc_points(obj):
    obj=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    spline=obj.data.splines[0]
    pts=spline.bezier_points if spline.type=='BEZIER' else spline.points
    return [obj.matrix_world@Vector(tuple(p.co)[:3]) for p in pts]
def line_distance(point,points):
    nearest=math.inf
    for first,second in zip(points,points[1:]):
        delta=second-first
        factor=max(0,min(1,(point-first).dot(delta)/delta.length_squared)) if delta.length_squared else 0
        nearest=min(nearest,(point-(first+factor*delta)).length)
    return nearest
def animated_values(material):
    if not material.use_nodes:return []
    values=[]
    for node in material.node_tree.nodes:
        for inp in node.inputs:
            if not hasattr(inp,'default_value'):continue
            try:v=inp.default_value;v=list(v) if hasattr(v,'__len__') else float(v)
            except (TypeError,ValueError):continue
            if inp.name in {'Emission Color','Emission Strength','Alpha','Color','Strength'}:
                values.append([node.name,inp.name,v])
    return values
report={'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),
 'original_source_sha256':hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(),
 'production_source':SRC.name,
 'preservation':{'objects_geometry_transform_parent_material_slots_match':original_signature['objects']==production_signature['objects'],
                 'all_actions_and_keyframe_handles_match':original_signature['actions']==production_signature['actions'],
                 'all_packed_image_bytes_match':original_signature['packed_images']==production_signature['packed_images'],
                 'original_objects':len(original_signature['objects']), 'production_objects':len(production_signature['objects']),
                 'original_actions':len(original_signature['actions']),'production_actions':len(production_signature['actions']),
                 'original_packed_images':len(original_signature['packed_images']),'production_packed_images':len(production_signature['packed_images'])},
 'scope':'Every integer source frame; evaluated capsule/hatch and capsule/deck surface intersections, arc terminal anchoring, animated heat/steam timing, source topology sanity. This is not a proof of all possible mechanical clearances.',
 'fps':s.render.fps/s.render.fps_base,'frame_range':[s.frame_start,s.frame_end],
 'source_unchanged':True,'failures':[], 'warnings':[]}
if not all(report['preservation'][key] for key in ['objects_geometry_transform_parent_material_slots_match','all_actions_and_keyframe_handles_match','all_packed_image_bytes_match']):report['failures'].append('Production source differs from original geometry/transform/action/image contract')
names=['Central upper service cover','Central lower service cover','Hatch rear moving seam lip','Hatch front moving seam lip']
hatches=[bpy.data.objects[n] for n in names]
capsule=[o for o in s.objects if o.type=='MESH' and o.parent and o.parent.name=='Lift_Z']
walls=[o for o in s.objects if o.type=='MESH' and o.name.startswith('Hatch well')]
moving=[o for o in s.objects if o.animation_data or (o.parent and o.parent.name in {'Lift_Z','Hatch_Rear_Pivot','Hatch_Front_Pivot','Arm_Link_1','Arm_Link_2','Arm_Link_3'})]
heat_materials=[m for m in bpy.data.materials if m.use_nodes and m.node_tree.animation_data]
report['heat_materials']=[{'name':m.name,'users':[o.name for o in s.objects if o.type=='MESH' and m.name in [x.name for x in o.data.materials if x]]} for m in heat_materials]
report['knobbly_capsule']=[{'object':o.name,'vertices':len(o.data.vertices),'modifiers':[m.type for m in o.modifiers]} for o in capsule]
report['arm_beams']=[o.name for o in s.objects if 'rigid beam' in o.name]
report['packed_images']=[{'name':i.name,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images if i.type!='RENDER_RESULT']
if any(not i['packed'] for i in report['packed_images']):report['failures'].append('External unpacked image dependency')
s.frame_set(0)
geometry=[]
for obj in [o for o in s.objects if o.type=='MESH' and not o.name.startswith('Cooling steam')]:
    vertices,polygons=mesh_data(obj)
    finite=all(math.isfinite(x) for p in vertices for x in p)
    if not finite:report['failures'].append('Non-finite vertices: '+obj.name)
    geometry.append({'name':obj.name,'vertices':len(vertices),'polygons':len(polygons),'finite':finite})
report['mesh_sanity']={'objects':len(geometry),'vertices':sum(o['vertices'] for o in geometry),'polygons':sum(o['polygons'] for o in geometry),'finite':all(o['finite'] for o in geometry)}
records=[];intersections=[];max_anchor=0;max_branch=0;active_arcs=[];active_steam=[];snapshots={}
mechanical=[o for o in moving if not o.name.startswith(('Cooling steam','Arc_'))]
mechanical_start={o.name:[list(row) for row in o.matrix_world] for o in mechanical}
for frame in range(288):
    s.frame_set(frame);bpy.context.view_layer.update()
    hatch_bvhs=[(o.name,bvh(o)) for o in hatches]
    wall_bvhs=[(o.name,bvh(o)) for o in walls]
    for cap in capsule:
        tree=bvh(cap)
        for name,other in hatch_bvhs+wall_bvhs:
            count=len(tree.overlap(other))
            if count:intersections.append({'frame':frame,'capsule':cap.name,'surface':name,'triangle_pairs':count})
    arc_on=[];anchors=[]
    for side in ['Left','Right']:
        arc=bpy.data.objects['Arc_'+side+'_Main']
        scale=max(abs(x) for x in arc.scale)
        if scale>1e-5 and not arc.hide_render:
            points=arc_points(arc)
            tower=point(bpy.data.objects['Tower_'+side+'_Tip'])
            terminal=point(bpy.data.objects['Capsule_'+side+'_Terminal'])
            # Allow either curve direction; endpoints must coincide with intended anchors.
            residual=min(max((points[0]-tower).length,(points[-1]-terminal).length),max((points[-1]-tower).length,(points[0]-terminal).length))
            anchors.append(residual);max_anchor=max(max_anchor,residual);arc_on.append(side)
            for index in range(3):
                branch=arc_points(bpy.data.objects[f'Arc_{side}_Branch_{index}'])
                max_branch=max(max_branch,min(line_distance(branch[0],points),line_distance(branch[-1],points)))
    steam=[o for o in s.objects if o.name.startswith('Cooling steam puff') and max(abs(x) for x in o.scale)>1e-5 and not o.hide_render]
    if arc_on:active_arcs.append(frame)
    if steam:active_steam.append(frame)
    if frame in [0,36,48,66,84,132,150,180,222,240,264,286,287]:
        snapshots[str(frame)]={'hatch_rotations':{o.name:list(o.rotation_euler) for o in [bpy.data.objects['Hatch_Rear_Pivot'],bpy.data.objects['Hatch_Front_Pivot']]},'lift':list(point(bpy.data.objects['Lift_Z'])),'arc_on':arc_on,'anchor_residuals':anchors,'steam_count':len(steam),'heat':{m.name:animated_values(m) for m in heat_materials}}
    if frame%24==0:print('AUDIT_FRAME',frame,flush=True)
s.frame_set(288);bpy.context.view_layer.update()
report.update(snapshots=snapshots,arc_frames=active_arcs,steam_frames=active_steam,simultaneous_steam_and_arc_frames=sorted(set(active_arcs)&set(active_steam)),max_active_arc_anchor_residual=max_anchor,max_active_branch_root_residual=max_branch,surface_intersections=intersections)
report['loop_matrix_max_residual']=max(abs(x-y) for obj in mechanical for row0,row1 in zip(mechanical_start[obj.name],obj.matrix_world) for x,y in zip(row0,row1))
report['loop_comparison']='Compare source frame0 to keyed cycle boundary288 (12.0 seconds). Frames0..287 are 288 unique time samples; last sample precedes closure boundary. Inactive transparent steam billboards are excluded from physical pose comparison.'
if not report['simultaneous_steam_and_arc_frames']:report['failures'].append('Steam does not overlap active discharge')
if max_anchor>1e-4:report['failures'].append('Arc endpoint does not match intended tower/capsule anchor')
if intersections:report['failures'].append('Evaluated capsule surfaces intersect hatch/well surfaces')
if report['loop_matrix_max_residual']>1e-4:report['failures'].append('Mechanical loop boundary transforms differ')
report['status']='PASS' if not report['failures'] else 'FAIL'
(O/'motion-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('V07_MOTION_AUDIT',json.dumps({k:report[k] for k in ['status','failures','warnings','max_active_arc_anchor_residual','loop_matrix_max_residual']}),flush=True)
