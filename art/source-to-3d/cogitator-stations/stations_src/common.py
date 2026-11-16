"""Editable hardware primitives and FMPL-based packed PBR finishes."""
import bpy, bmesh, json, math, sys
from pathlib import Path
from mathutils import Vector
from finishes import FINISHES
from surfaces.build_library import shader_material
TAU=math.tau
CACHE={}
ROOT=Path(__file__).resolve().parent
RECIPES=json.loads((Path(sys.modules['surfaces.build_library'].__file__).parent/'catalog.json').read_text())
BY_ID={r['id']:r for r in RECIPES['presets']}

def mat(key):
    if isinstance(key,bpy.types.Material): return key
    if key in CACHE: return CACHE[key]
    profile,label,rgb,metal,rough=FINISHES[key]
    recipe=dict(BY_ID[profile])
    recipe.update(roughness=rough,metallic=metal,noise_scale=37.0,bump_distance=.002)
    m=shader_material(bpy,recipe,RECIPES['version'])
    m.name=label
    m['station_finish']=key
    m.diffuse_color=tuple((v/255.0)**2.2 for v in rgb)+(1,)
    n=m.node_tree.nodes
    bsdf=next(k for k in n if k.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=m.diffuse_color
    im=bpy.data.images.load(str(ROOT/'plates'/(key+'.png')),check_existing=True)
    im.pack()
    tex=n.new('ShaderNodeTexImage')
    tex.image=im
    tex.name='Packed field-aged finish'
    m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    link=m.node_tree.links.new
    def packed_data(filename):
        data=n.new('ShaderNodeTexImage')
        data.image=bpy.data.images.load(str(ROOT/'plates'/filename),check_existing=True)
        data.image.colorspace_settings.name='Non-Color'
        if not data.image.packed_file:data.image.pack()
        return data
    properties=packed_data(key+'-orm.png')
    channels=n.new('ShaderNodeSeparateColor')
    link(properties.outputs['Color'],channels.inputs['Color'])
    link(channels.outputs['Green'],bsdf.inputs['Roughness'])
    link(channels.outputs['Blue'],bsdf.inputs['Metallic'])
    relief='ceramic' if key=='ceramic' else 'rubber' if metal<.3 else 'iron'
    grain=packed_data(relief+'-normal.png')
    normal=n.new('ShaderNodeNormalMap')
    link(grain.outputs['Color'],normal.inputs['Color'])
    link(normal.outputs['Normal'],bsdf.inputs['Normal'])
    CACHE[key]=m
    return m

def mesh(name, verts, faces, material, bevel=0):
    me=bpy.data.meshes.new(name)
    me.from_pydata(verts,[],faces)
    me.update()
    ob=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    if material is not None: me.materials.append(mat(material))
    if bevel>0:
        mod=ob.modifiers.new('Cast edge radii','BEVEL')
        mod.width=bevel; mod.segments=2; mod.limit_method='ANGLE'
        mod.harden_normals=True
        norm=ob.modifiers.new('Face weighted normals','WEIGHTED_NORMAL')
        norm.keep_sharp=True
    return ob

def box(name,center,size,material,bevel=.02):
    a,b,c=(v*.5 for v in size)
    vs=[(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]
    fs=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    ob=mesh(name,vs,fs,material,min(bevel,min(size)*.23))
    ob.location=center
    return ob

def rod(name,start,end,radius,material,vertices=16,radius2=None):
    a,b=Vector(start),Vector(end); delta=b-a; h=delta.length/2
    r2=radius if radius2 is None else radius2
    vs=[(r*math.cos(TAU*i/vertices),r*math.sin(TAU*i/vertices),z) for r,z in ((radius,-h),(r2,h)) for i in range(vertices)]
    fs=[tuple(range(vertices-1,-1,-1)),tuple(range(vertices,vertices*2))]
    fs.extend((i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices))
    ob=mesh(name,vs,fs,material)
    if vertices>=12:
        for poly in list(ob.data.polygons)[2:]:poly.use_smooth=True
        for edge in ob.data.edges:
            if edge.vertices[0]//vertices==edge.vertices[1]//vertices:edge.use_edge_sharp=True
    ob.location=(a+b)*.5
    ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return ob

def ball(name,center,scale,material):
    bm=bmesh.new()
    bmesh.ops.create_uvsphere(bm,u_segments=20,v_segments=12,radius=1)
    me=bpy.data.meshes.new(name);bm.to_mesh(me);bm.free()
    for v in me.vertices:
        for k in range(3):v.co[k]*=scale[k]
    for f in me.polygons:f.use_smooth=True
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    me.materials.append(mat(material));ob.location=center
    return ob

def swept(name,points,radius,material,closed=False,sides=10):
    pts=[Vector(p) for p in points]
    vs=[];fs=[]
    prev=None
    for i,p in enumerate(pts):
        last=pts[(i-1)%len(pts)] if closed or i>0 else p
        following=pts[(i+1)%len(pts)] if closed or i+1<len(pts) else p
        tangent=((p-last).normalized()+(following-p).normalized()).normalized()
        if prev is None:
            seed=Vector((0,0,1)) if abs(tangent.z)<.83 else Vector((0,1,0))
            u=tangent.cross(seed).normalized()
        else:
            u=(prev-tangent*prev.dot(tangent)).normalized()
            if u.length<.01:u=tangent.orthogonal().normalized()
        v=tangent.cross(u).normalized();prev=u
        for j in range(sides):
            a=TAU*j/sides;vs.append(tuple(p+radius*(u*math.cos(a)+v*math.sin(a))))
    for i in range(len(pts) if closed else len(pts)-1):
        k=(i+1)%len(pts)
        for j in range(sides):
            m=(j+1)%sides
            fs.append((i*sides+j,i*sides+m,k*sides+m,k*sides+j))
    if not closed:
        fs.extend((tuple(range(sides-1,-1,-1)),tuple(range((len(pts)-1)*sides,len(pts)*sides))))
    ob=mesh(name,vs,fs,material)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def path(name,points,radius,material):
    pts=[Vector(p) for p in points]
    if len(pts)<2:raise ValueError('A path needs two points')
    route=[pts[0]]
    for i in range(1,len(pts)-1):
        a,b,c=pts[i-1:i+2]
        length=min((b-a).length*.28,(c-b).length*.28,max(radius*2.3,.035))
        l=b+(a-b).normalized()*length;r=b+(c-b).normalized()*length
        for k in range(5):
            t=k/4;route.append((1-t)**2*l+2*t*(1-t)*b+t*t*r)
    route.append(pts[-1])
    clean=[route[0]]
    for p in route[1:]:
        if (p-clean[-1]).length>1e-6:clean.append(p)
    return swept(name,clean,radius,material)

def torus(name,center,major,minor,normal,material):
    n=Vector(normal).normalized();u=n.orthogonal().normalized();v=n.cross(u)
    pts=[Vector(center)+major*(u*math.cos(TAU*k/32)+v*math.sin(TAU*k/32)) for k in range(32)]
    return swept(name,pts,minor,material,True,10)


def part_snapshot():
    return set(bpy.context.collection.objects)

def preserve_round_parts(before,center_z):
    for ob in set(bpy.context.collection.objects)-before:
        ob['station_rigid_center_z']=center_z
