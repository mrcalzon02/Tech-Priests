"""Model-specific image surfaces and physical per-part UV placement."""
import math
import bpy
import numpy as np

def field(rng,shape,band):
    fy=np.fft.fftfreq(shape[0]);fx=np.fft.fftfreq(shape[1])
    x,y=np.meshgrid(fx,fy)
    raw=rng.normal(0,1,shape)
    value=np.fft.ifft2(np.fft.fft2(raw)*np.exp(-(x*x+y*y)/(2*band*band))).real
    return value/max(value.std(),1e-7)

def image(name,array,out,noncolor=False):
    h,w=array.shape[:2]
    obj=bpy.data.images.new(name,width=w,height=h,alpha=True)
    if noncolor:obj.colorspace_settings.name='Non-Color'
    pixels=np.ones((h,w,4),dtype=np.float32)
    pixels[:,:,:3]=array[:,:,None] if array.ndim==2 else array
    obj.pixels.foreach_set(pixels.ravel())
    obj.filepath_raw=str(out/(name+'.png'))
    obj.file_format='PNG'
    obj.save();obj.pack()
    return obj

def material(name,color,roughness,height,metallic,out):
    dy,dx=np.gradient(height)
    normal=np.stack([-dx*3,-dy*3,np.ones_like(dx)],axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[:,:,None]
    maps={
        'albedo':image(name+'-albedo',np.clip(color,.006,.85),out),
        'roughness':image(name+'-roughness',np.clip(roughness,.15,.98),out,True),
        'normal':image(name+'-normal',normal*.5+.5,out,True)}
    mat=bpy.data.materials.new('PUMP V3 | '+name)
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Metallic'].default_value=metallic
    for kind,im in maps.items():
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
        if kind=='normal':
            bump=mat.node_tree.nodes.new('ShaderNodeNormalMap')
            bump.inputs['Strength'].default_value=.45
            mat.node_tree.links.new(node.outputs['Color'],bump.inputs['Color'])
            mat.node_tree.links.new(bump.outputs['Normal'],shader.inputs['Normal'])
        else:mat.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color' if kind=='albedo' else 'Roughness'])
    mat['surface_authorship']='Pipe pump V3 specific image maps; physical role and per-part UV placement'
    return mat

def create(out):
    rng=np.random.default_rng(151126)
    shape=(512,512)
    u,v=np.meshgrid(np.linspace(0,1,512),np.linspace(0,1,512))
    broad=field(rng,shape,.012)
    medium=field(rng,shape,.07)
    fine=field(rng,shape,.30)
    # Long fibers follow U on each individual plank; only actual cut faces use rings.
    grain=np.sin(v*330+1.2*np.sin(u*7)+.30*broad)+.22*np.sin(v*910+np.sin(u*23))
    wood=np.stack([.30+.027*grain+.018*broad,.205+.021*grain+.013*broad,.113+.013*grain+.008*broad],axis=-1)
    mats={'wood':material('long-grain-oak',wood,.78+.035*medium,.5+.10*grain+.025*broad,0,out)}
    radius=np.sqrt(((u-.47)*1.1)**2+((v-.52)*.88)**2)
    rings=np.sin(radius*190+1.4*broad)
    end=np.stack([.285+.025*rings,.19+.02*rings,.105+.012*rings],axis=-1)
    mats['endgrain']=material('cut-oak-growth-rings',end,.84+.02*medium,.5+.08*rings,0,out)
    # Separate metal identities. Oxidation is sparse and soft; no repeated stripes.
    patina=np.clip((broad-.85)*.65,0,.65)
    copper=np.stack([.35+.035*medium,.155+.018*medium,.065+.012*medium],axis=-1)
    patina_color=np.stack([.065+.008*medium,.18+.012*medium,.14+.009*medium],axis=-1)
    copper=copper*(1-patina[:,:,None])+patina_color*patina[:,:,None]
    mats['copper']=material('aged-copper-jacket',copper,.43+.08*patina+.035*medium,.5+.027*medium+.007*fine,.79,out)
    iron=np.stack([.077+.008*medium,.091+.009*medium,.092+.009*medium],axis=-1)
    mats['iron']=material('cast-iron-housing',iron,.61+.055*medium,.5+.018*medium+.009*fine,.76,out)
    bronze=np.stack([.36+.022*medium,.245+.018*medium,.085+.009*medium],axis=-1)
    mats['bronze']=material('worn-bronze-fittings',bronze,.38+.03*medium,.5+.012*fine,.81,out)
    brick=np.stack([.245+.022*broad+.011*medium,.105+.013*broad+.009*medium,.053+.009*broad+.007*medium],axis=-1)
    mats['brick']=material('fired-clay-lining',brick,.88+.02*medium,.5+.027*medium+.012*fine,0,out)
    return mats

def physical_box_uv(obj,wood=False):
    mesh=obj.data
    uv=mesh.uv_layers.active or mesh.uv_layers.new(name='Physical authored placement')
    sizes=[max(v.co[i] for v in mesh.vertices)-min(v.co[i] for v in mesh.vertices) for i in range(3)]
    long_axis=max(range(3),key=lambda k:sizes[k])
    for face in mesh.polygons:
        axes=sorted(range(3),key=lambda k:abs(face.normal[k]))[:2]
        end=wood and abs(face.normal[long_axis])>.9
        if end:
            face.material_index=1
            au,av=axes
        else:
            if wood and long_axis in axes:axes.remove(long_axis);axes.insert(0,long_axis)
            au,av=axes
        for idx in face.loop_indices:
            co=mesh.vertices[mesh.loops[idx].vertex_index].co
            if end:
                lo=[min(v.co[i] for v in mesh.vertices) for i in (au,av)]
                uv.data[idx].uv=(.05+.9*(co[au]-lo[0])/max(sizes[au],1e-6),.05+.9*(co[av]-lo[1])/max(sizes[av],1e-6))
            else:uv.data[idx].uv=(co[au]/.5,co[av]/.20)

def apply(obj,mat,endgrain=None):
    obj.data.materials.clear();obj.data.materials.append(mat)
    if endgrain:obj.data.materials.append(endgrain)
    if obj.type=='MESH' and obj.data.vertices:
        physical_box_uv(obj,wood=endgrain is not None)
