import bpy,bmesh,pathlib,sys
from mathutils import Vector
p=pathlib.Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(p));o=bpy.data.objects['V09 V07 tier01 flared cast radial web07 root lug | Connected formed ring lug'];m=o.data;m.calc_loop_triangles();print('MATRIX',list(o.matrix_world))
for t in m.loop_triangles:
    a,b,c=[o.matrix_world@m.vertices[i].co for i in t.vertices];area=(b-a).cross(c-a).length/2
    if area<1e-11:print('MESH_TRI',list(t.vertices),area,[list(v) for v in (a,b,c)])
bm=bmesh.new();bm.from_mesh(m)
for f in bm.faces:
    if f.calc_area()<1e-10:print('BM_FACE',f.calc_area(),[list(v.co) for v in f.verts])
