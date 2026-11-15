"""Measure actual casting continuity, recoil travel and sensor sight lines."""
import bpy,bmesh,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector
source=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(source))
S=bpy.context.scene;S.frame_set(1);bpy.context.view_layer.update()
hull=bpy.data.objects['Unified turret casting with integrated mantlet sockets']
bm=bmesh.new();bm.from_mesh(hull.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
unseen=set(bm.verts);components=[]
while unseen:
    todo=[unseen.pop()];size=0
    while todo:
        vertex=todo.pop();size+=1
        for edge in vertex.link_edges:
            other=edge.other_vert(vertex)
            if other in unseen:unseen.remove(other);todo.append(other)
    components.append(size)
bm.free();assert len(components)==1,('Casting is disconnected',components)
original=[list(row) for row in hull.matrix_world]
guns=[bpy.data.objects['INDEPENDENT_RECOIL_'+str(i)] for i in (0,1)]
S.frame_set(226);rest=[obj.location.y for obj in guns]
max_kick=[0.,0.];max_radial=0.;fire_poses=[]
for tick in range(226):
    S.frame_set(tick+1);bpy.context.view_layer.update()
    for bank,gun in enumerate(guns):max_kick[bank]=max(max_kick[bank],gun.location.y-rest[bank])
    for bank,x in enumerate((-.58,.58)):
        seat=bpy.data.objects['Recessed moving mantlet seat'+('' if bank==0 else '.001')]
        for vertex in seat.data.vertices:
            p=seat.matrix_world@vertex.co
            if -.77<=p.y<=.04:max_radial=max(max_radial,math.hypot(p.x-x,p.z-2.61))
    if tick in (0,45,90,135):
        bank=(tick//45)%2;assert abs(guns[bank].location.y-rest[bank])<.00001,'Gun fires before reaching battery'
        fire_poses.append({'tick':tick,'bank':bank,'battery_error':guns[bank].location.y-rest[bank]})
    assert [list(row) for row in hull.matrix_world]==original,'Fixed casting recoils'
assert all(abs(value-.9)<.00001 for value in max_kick),max_kick
assert max_radial<.422-.005,('Mantlet socket clearance',max_radial)
S.frame_set(1);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
sight_lines=[]
for obj in S.objects:
    if obj.name.startswith(('Optical and thermal sensor glass','Flank tracking camera glass')):
        points=[obj.matrix_world@Vector(corner) for corner in obj.bound_box]
        centre=obj.matrix_world.translation.copy();centre.y=min(p.y for p in points)-.003
        hit,point,normal,index,blocker,matrix=S.ray_cast(deps,centre,Vector((0,-1,0)),distance=8)
        assert not hit,('Blocked sensor centreline',obj.name,blocker.name if blocker else '')
        sight_lines.append(obj.name)
assert len(sight_lines)==5,sight_lines
report={'status':'PASS','native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'casting_connected_components':len(components),'casting_component_vertices':components,
    'max_recoil':max_kick,'max_mantlet_seat_radial_extent':max_radial,'socket_radius':.422,
    'minimum_radial_clearance':.422-max_radial,'fire_poses':fire_poses,
    'unobstructed_forward_optical_centre_lines':sight_lines,'fixed_casting_remains_stationary':True}
(source.parent/'structure-and-motion-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('STRUCTURE_AND_MOTION_PASS',json.dumps(report),flush=True)
