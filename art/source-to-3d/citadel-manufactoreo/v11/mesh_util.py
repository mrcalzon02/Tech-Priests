"""Small authored geometry helpers for this pump; all meshes remain editable."""
import math
import bpy
from mathutils import Vector

def mesh(name,verts,faces,material,collection,parent=None,bevel=0):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    obj.parent=parent
    data.materials.append(material)
    if bevel:
        mod=obj.modifiers.new('Authored softened arris','BEVEL')
        mod.width,mod.segments=bevel,3
        obj.modifiers.new('Stable weighted normals','WEIGHTED_NORMAL')
    return obj

def box(name,pos,dims,material,collection,parent=None,bevel=.006):
    x,y,z=(v/2 for v in dims)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    obj=mesh(name,verts,faces,material,collection,parent,min(bevel,min(dims)*.22) if bevel else 0)
    obj.location=pos
    return obj


def cylinder(name,pos,radius,depth,material,collection,parent=None,axis='Z',segments=48):
    # Direct editable mesh construction preserves dimensions while avoiding
    # thousands of global primitive/transform operator dependency updates.
    verts=[]
    for i in range(segments):
        a=i*math.tau/segments
        verts.extend([(radius*math.sin(a),radius*math.cos(a),-depth/2),(radius*math.sin(a),radius*math.cos(a),depth/2)])
    faces=[(2*i,2*((i+1)%segments),2*((i+1)%segments)+1,2*i+1) for i in range(segments)]
    faces.extend([tuple(2*i for i in range(segments)),tuple(2*i+1 for i in reversed(range(segments)))])
    obj=mesh(name,verts,faces,material,collection,parent)
    obj.location=pos
    if axis=='X':obj.rotation_euler.y=math.pi/2
    elif axis=='Y':obj.rotation_euler.x=math.pi/2
    for face in obj.data.polygons:face.use_smooth=len(face.vertices)==4
    return obj


def lathe(name,profile,center,material,collection,parent=None,segments=64):
    # Profile is a closed, consistently ordered section in radius/Z. An axis
    # point is one vertex, rather than a ring of coincident degenerate faces.
    verts=[]
    rings=[]
    for radius,z in profile:
        start=len(verts)
        if radius<1e-9:
            verts.append((center[0],center[1],z))
            rings.append([start])
        else:
            verts.extend((center[0]+radius*math.cos(i*math.tau/segments),center[1]+radius*math.sin(i*math.tau/segments),z) for i in range(segments))
            rings.append(list(range(start,start+segments)))
    faces=[]
    for ring,next_ring in zip(rings,rings[1:]+rings[:1]):
        if len(ring)==1 and len(next_ring)==1:continue
        for i in range(segments):
            j=(i+1)%segments
            if len(ring)==1:faces.append((ring[0],next_ring[i],next_ring[j]))
            elif len(next_ring)==1:faces.append((ring[i],next_ring[0],ring[j]))
            else:faces.append((ring[i],next_ring[i],next_ring[j],ring[j]))
    obj=mesh(name,verts,faces,material,collection,parent)
    import bmesh
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    for face in obj.data.polygons:face.use_smooth=True
    return obj

def tube(name,samples,material,collection,parent=None,segments=64):
    """Samples are (xyz, tangent, outside_radius, bore_radius)."""
    verts=[]
    sides=[]
    lengths=[0.]
    for a,b in zip(samples,samples[1:]):lengths.append(lengths[-1]+(Vector(b[0])-Vector(a[0])).length)
    for xyz,tangent,outer,inner in samples:
        tangent=Vector(tangent).normalized()
        trial=Vector((1,0,0)) if abs(tangent.x)<.9 else Vector((0,1,0))
        across=(trial-tangent*trial.dot(tangent)).normalized()
        side=tangent.cross(across).normalized()
        sides.append((across,side))
    for layer in (0,1):
        for (xyz,tangent,outer,inner),(across,side) in zip(samples,sides):
            radius=outer if layer==0 else inner
            verts.extend(tuple(Vector(xyz)+radius*(math.cos(i*math.tau/segments)*across+math.sin(i*math.tau/segments)*side)) for i in range(segments))
    n=segments;rings=len(samples);off=n*rings
    faces=[]
    for offset,reverse in ((0,False),(off,True)):
        for r in range(rings-1):
            for i in range(n):
                j=(i+1)%n
                face=(offset+r*n+i,offset+r*n+j,offset+(r+1)*n+j,offset+(r+1)*n+i)
                faces.append(tuple(reversed(face)) if reverse else face)
    for r in (0,rings-1):
        for i in range(n):
            j=(i+1)%n
            face=(r*n+i,r*n+j,off+r*n+j,off+r*n+i)
            faces.append(tuple(reversed(face)) if r==0 else face)
    obj=mesh(name,verts,faces,material,collection,parent)
    uv=obj.data.uv_layers.new(name='Physical arc length / circumference')
    for face in obj.data.polygons:
        values=[]
        for idx in face.loop_indices:
            ring,k=divmod(obj.data.loops[idx].vertex_index%off,n)
            values.append((idx,k/n,lengths[ring]/.5))
        seam=any(u>.9 for _,u,_ in values) and any(u<.1 for _,u,_ in values)
        for idx,u,v in values:uv.data[idx].uv=(1 if seam and u<.1 else u,v)
        face.use_smooth=True
    obj['full_hollow_wall']=True
    return obj

def line_samples(start,end,r0,r1=None,steps=8):
    start,end=Vector(start),Vector(end)
    tangent=(end-start).normalized()
    r1=r0 if r1 is None else r1
    return [(tuple(start.lerp(end,i/steps)),tuple(tangent),r0[0]+(r1[0]-r0[0])*i/steps,r0[1]+(r1[1]-r0[1])*i/steps) for i in range(steps+1)]

def arc_samples(yc,zc,radius,a0,a1,outer,inner,x=0,steps=24):
    result=[]
    sign=1 if a1>a0 else -1
    assert outer<radius, 'Elbow walls would cross the inside bend'
    for i in range(steps+1):
        a=a0+(a1-a0)*i/steps
        result.append(((x,yc+radius*math.cos(a),zc+radius*math.sin(a)),(0,-sign*math.sin(a),sign*math.cos(a)),outer,inner))
    return result

def join_samples(*sections):
    result=[]
    for section in sections:
        if result:
            assert (Vector(result[-1][0])-Vector(section[0][0])).length<1e-6
            result.extend(section[1:])
        else:result.extend(section)
    return result
