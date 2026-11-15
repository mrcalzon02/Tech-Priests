"""Model-space hollow service routes and fittings, +Z-up tile units.

No closed spheres at elbows: inner and outer swept surfaces remain connected
through every bend. End fittings remain separate, seated physical assemblies.
"""
import math
import bpy
from mathutils import Vector

def mesh_object(collection,name,verts,faces,material):
    mesh=bpy.data.meshes.new(name+' mesh'); mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new(name,mesh); collection.objects.link(ob)
    if material: mesh.materials.append(material)
    return ob

def rounded_path(points, radius):
    points=[Vector(p) for p in points]
    if len(points)<2: raise ValueError('Route needs two endpoints')
    result=[points[0]]
    for a,b,c in zip(points,points[1:],points[2:]):
        before=(b-a); after=(c-b)
        if before.length<1e-5 or after.length<1e-5: raise ValueError('Coincident route nodes')
        cut=min(max(2.5*radius,.045),before.length*.30,after.length*.30)
        p=b-before.normalized()*cut; q=b+after.normalized()*cut
        result.append(p)
        for i in range(1,9):
            t=i/8; result.append((1-t)**2*p+2*t*(1-t)*b+t*t*q)
    result.append(points[-1])
    return [v for i,v in enumerate(result) if i==0 or (v-result[i-1]).length>1e-6]

def hollow_route(collection,name,points,outer,inner,material,segments=24,rounded=True):
    if not 0<inner<outer: raise ValueError('Invalid physical annulus')
    centers=rounded_path(points,outer) if rounded else [Vector(p) for p in points]
    tangents=[]
    for i,p in enumerate(centers):
        d=(centers[min(i+1,len(centers)-1)]-centers[max(i-1,0)]).normalized()
        tangents.append(d)
    across=tangents[0].cross(Vector((0,0,1)))
    if across.length<.001: across=tangents[0].cross(Vector((0,1,0)))
    across.normalize(); frames=[]
    for i,tangent in enumerate(tangents):
        if i: across=tangents[i-1].rotation_difference(tangent) @ across
        across=(across-tangent*across.dot(tangent)).normalized()
        frames.append((across,tangent.cross(across).normalized()))
    verts=[]
    for radius in (outer,inner):
        for p,(u,v) in zip(centers,frames):
            verts.extend(tuple(p+radius*(u*math.cos(math.tau*i/segments)+v*math.sin(math.tau*i/segments))) for i in range(segments))
    m=len(centers); n=segments; offset=m*n; faces=[]
    for k in range(m-1):
        for i in range(n):
            j=(i+1)%n; a=k*n; b=(k+1)*n
            faces.extend(((a+i,a+j,b+j,b+i),(offset+a+i,offset+b+i,offset+b+j,offset+a+j)))
    for i in range(n):
        j=(i+1)%n; end=(m-1)*n
        faces.extend(((i,offset+i,offset+j,j),(end+i,end+j,offset+end+j,offset+end+i)))
    ob=mesh_object(collection,name,verts,faces,material)
    layer=ob.data.uv_layers.new(name='Physical axial tube UV')
    distances=[0.]
    for a,b in zip(centers,centers[1:]): distances.append(distances[-1]+(b-a).length)
    for face in ob.data.polygons:
        ids=[ob.data.loops[k].vertex_index for k in face.loop_indices]
        seam=any(i%n==0 for i in ids) and any(i%n==n-1 for i in ids)
        for k,i in zip(face.loop_indices,ids):
            angle=(n if seam and i%n==0 else i%n)/n
            layer.data[k].uv=(angle*math.tau*outer*1.25,distances[(i%offset)//n]*1.25)
    ob['route_points']=[list(p) for p in points]
    ob['flow_path_samples']=[list(p) for p in centers]
    ob['bore_diameter']=inner*2; ob['outer_diameter']=outer*2
    ob['open_flow_path']='authored hollow wall; independent bore test pending'
    ob['source_or_guess']='source-backed process role; new physically supported route'
    return ob

def hollow_sleeve(collection,name,point,axis,length,outer,inner,material,segments=24):
    p=Vector(point); d=Vector(axis).normalized()
    return hollow_route(collection,name,[p-d*length/2,p+d*length/2],outer,inner,material,segments,False)

def compression_joint(collection,name,point,into_line,radius,metal,brass,electrical=False):
    p=Vector(point); d=Vector(into_line).normalized()
    # The receiving socket straddles the exact route endpoint. A hollow hex
    # gland and retaining collar are coaxial with the line and preserve bore.
    objects=[hollow_sleeve(collection,name+' receiving socket',p,d,.10,radius*1.55,radius*.72,metal),
             hollow_sleeve(collection,name+' hex compression nut',p+d*.036,d,.048,radius*1.85,radius*.72,brass,6),
             hollow_sleeve(collection,name+' seated ferrule',p+d*.068,d,.025,radius*1.34,radius*.72,metal)]
    for ob in objects:
        ob['joint_family']='electrical cable gland' if electrical else 'compression pressure fitting'
        ob['joint_endpoint']=list(p); ob['joint_axis']=list(d)
    return objects
