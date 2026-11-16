"""Check evaluated breech/shroud clearance, live rounds, recoil and floor.

Only the named tested interfaces are claimed; intended axle and hinge joints
are excluded. Source and exported-model inspection remain separate evidence.
"""
import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

source=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
drum=bpy.data.objects['THREE_CHAMBER_BREECH'];carriage=bpy.data.objects['DEEP_RECOIL_CARRIAGE']
rounds=[bpy.data.objects['LOADED_ARTILLERY_SHELL_'+str(i)] for i in range(3)]
rotating=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Pressure chamber','Chamber locking ring'))]
guards=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Curved rear breech crown','Revolver outer support ring','Revolver support saddle','Rear reload gate ring','Lower inspection guard','Inspection guard curved','Guard mounting band','Guard clamp fastener'))]
sliding=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Sliding carriage guide bushing','Ring to recoil-bed structural strut'))]
supports=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Longitudinal recoil-bed casting','Bearing pedestal on recoil bed','Load-bearing fork cheek','Inset sloped cheek armour','Elevation trunnion','Trunnion bearing retaining ring','Forward cradle load strut','Rear cradle load strut'))]
assert len(rotating)==9 and guards

def tree(obj,deps):
    evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
    result=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons],all_triangles=False,epsilon=0)
    evaluated.to_mesh_clear();return result

gate_parts=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Rear reload gate ring','Reload gate cross brace','Gate hinge structural lug','Gate lower hinge knuckle'))]
gate_obstacles=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Pressure chamber','Chamber locking ring','Revolver outer support ring','Curved rear breech crown','Fixed gate hinge clevis'))]
def descendant(obj,parent):
    while obj.parent:
        obj=obj.parent
        if obj==parent:return True
    return False
moving_cap=[o for o in s.objects if o.type in ('MESH','CURVE') and descendant(o,carriage)]
mount=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Central load-bearing pedestal','Thick pedestal distribution plate','Machined distribution plate edge','Radial pedestal gusset','Bolted full-contact yoke foot','Yoke foot anchor bolt','Visible yoke foot anchor nut','Traverse bearing socket','Exposed azimuth bearing','Traverse bearing retainer','Traverse bearing anchor nut'))]
collisions=[];slide_collisions=[];gate_collisions=[];mount_collisions=[];floor=100;max_recoil=0;alignment=[];loaded_samples=[];reload_angles=[]
rest=carriage.location.y
for tick in range(601):
    s.frame_set(tick+1);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    fixed=[(o,tree(o,deps)) for o in guards]
    for moving in rotating:
        moving_tree=tree(moving,deps)
        for guard,guard_tree in fixed:
            if moving_tree.overlap(guard_tree):
                if len(collisions)<30:collisions.append({'tick':tick,'moving':moving.name,'guard':guard.name})
    bed_trees=[(o,tree(o,deps)) for o in supports]
    for moving in sliding:
        moving_tree=tree(moving,deps)
        for support,support_tree in bed_trees:
            if moving_tree.overlap(support_tree) and len(slide_collisions)<30:
                slide_collisions.append({'tick':tick,'moving':moving.name,'support':support.name})
    obstacle_trees=[(o,tree(o,deps)) for o in gate_obstacles]
    for moving in gate_parts:
        moving_tree=tree(moving,deps)
        for obstacle,obstacle_tree in obstacle_trees:
            if moving_tree.overlap(obstacle_tree) and len(gate_collisions)<30:
                gate_collisions.append({'tick':tick,'moving':moving.name,'obstacle':obstacle.name})
    mount_trees=[(o,tree(o,deps)) for o in mount]
    for moving in moving_cap:
        moving_tree=tree(moving,deps)
        for support,support_tree in mount_trees:
            if moving_tree.overlap(support_tree) and len(mount_collisions)<30:
                mount_collisions.append({'tick':tick,'moving':moving.name,'support':support.name})
    max_recoil=max(max_recoil,carriage.location.y-rest)
    for obj in s.objects:
        if obj.type=='MESH':floor=min(floor,min((obj.matrix_world@Vector(p)).z for p in obj.bound_box))
    if tick in (0,90,180):
        active=rounds[tick//90].matrix_world.translation
        local=carriage.matrix_world.inverted()@active
        angle=abs(math.degrees(bpy.data.objects['ELEVATION_CRADLE'].rotation_euler.x))
        alignment.append({'tick':tick,'active_shell':tick//90,'x_error':abs(local.x),'height_error':abs(local.z),'recoil_error':abs(carriage.location.y-rest),'firing_angle_degrees':angle})
    if tick in (0,1,90,91,180,181,499,500,600):
        loaded_samples.append({'tick':tick,'loaded':sum(o.scale.x>.5 for o in rounds)})
    if tick in (315,420,545):reload_angles.append(abs(math.degrees(bpy.data.objects['ELEVATION_CRADLE'].rotation_euler.x)))
failures=[]
s.frame_set(1);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
attachment_checks=[]
for obj in s.objects:
    if 'attachment_targets' not in obj:continue
    for name in json.loads(obj['attachment_targets']):
        target=bpy.data.objects[name]
        attached=bool(tree(obj,deps).overlap(tree(target,deps)))
        attachment_checks.append({'part':obj.name,'support':name,'material_intersection':attached})
        if not attached:failures.append('Unsupported hardware: '+obj.name+' -> '+name)
obsolete_bars=[o.name for o in s.objects if o.name.startswith('Revolver support saddle')]
if obsolete_bars:failures.append('Redundant cage crossbar remains')
if collisions:failures.append('Rotating chamber intersects protective structure')
if slide_collisions:failures.append('Sliding carriage intersects stationary support')
if gate_collisions:failures.append('Reload gate intersects breech or protective structure')
if mount_collisions:failures.append('Recoiling assembly intersects the pedestal or mounting plate')
if floor<1.699:failures.append('Moving cap dips below the fixed bunker socket')
if abs(max_recoil-.76)>.0001:failures.append('Deep recoil travel differs from source contract')
if any(max(a['x_error'],a['height_error'],a['recoil_error'])>.0001 for a in alignment):failures.append('Next shell does not align with the bore in battery')
if any(abs(a['firing_angle_degrees']-35)>.0001 for a in alignment):failures.append('Artillery does not fire at 35 degrees')
if any(a>.0001 for a in reload_angles):failures.append('Artillery does not lower level for reload')
if [x['loaded'] for x in loaded_samples]!=[3,2,2,1,1,0,0,3,3]:failures.append('Visible round state differs from three-shot demonstration')
pivot=bpy.data.objects['ELEVATION_CRADLE'].matrix_world.translation
if math.hypot(pivot.x,pivot.y)>.0001:failures.append('Trunnion is not centered over the mounting plate')
feet=[o for o in s.objects if o.name.startswith('Bolted full-contact yoke foot')]
foot_contact=[]
for foot in feet:
    corners=[foot.matrix_world@Vector(p) for p in foot.bound_box]
    radius=max(math.hypot(p.x,p.y) for p in corners);height=min(p.z for p in corners)
    foot_contact.append({'name':foot.name,'maximum_corner_radius':radius,'bottom_height':height})
    if radius>1.50 or abs(height-2.36)>.015:failures.append('Yoke foot does not fully seat on the distribution plate')
if len(feet)!=2:failures.append('Two full-contact yoke feet required')
report={'status':'FAIL' if failures else 'PASS_SOURCE_INTERFACES','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'frames_checked':601,'tested_rotating_meshes':len(rotating),'tested_guard_meshes':len(guards),
 'failures':failures,'collision_examples':collisions,'slide_collision_examples':slide_collisions,'gate_collision_examples':gate_collisions,'mount_collision_examples':mount_collisions,'minimum_height':floor,'maximum_recoil':max_recoil,
 'trunnion_xy':[pivot.x,pivot.y],'foot_contacts':foot_contact,'tested_moving_cap_meshes':len(moving_cap),'tested_mount_meshes':len(mount),
 'redundant_cage_crossbars':obsolete_bars,
 'hardware_attachments':attachment_checks,
 'bore_alignment':alignment,'visible_round_samples':loaded_samples,'reload_angles_degrees':reload_angles,
 'scope':'Full-frame chamber/guard, reload-gate, sliding-bushing/support and recoiling-assembly/mount intersections; centered trunnion, full-foot contact, elevated bore alignment, level reload, floor and recoil. Not continuous collision proof, exported-model validity or native gameplay acceptance'}
(source.parent/'source-motion-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARTILLERY_SOURCE_INTERFACES',report['status'],failures,flush=True)
