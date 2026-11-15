"""Pack explicit authored image channels; placement/anatomy is caller-owned."""
from pathlib import Path
import bpy
import numpy as np


def material_from_maps(name,directory,color,rough,metal,height,plan):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True);size=color.shape[0]
    records=[]
    def image(channel,rgb,noncolor=False):
        im=bpy.data.images.new(name+' '+channel,width=size,height=size,alpha=True)
        if noncolor:im.colorspace_settings.name='Non-Color'
        rgba=np.ones((size,size,4),dtype=np.float32);rgba[:,:,:3]=np.clip(rgb,0,1)
        im.pixels.foreach_set(rgba.reshape(-1));im.file_format='PNG';im.filepath_raw=str(directory/(channel+'.png'));im.save();im.pack()
        records.append(dict(channel=channel,file=im.filepath_raw,color_space=im.colorspace_settings.name))
        return im
    dy,dx=np.gradient(height);normal=np.stack((-dx*16,-dy*16,np.ones_like(dx)),axis=2)
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    albedo=image('albedo',color);orm=image('orm',np.stack((np.ones_like(rough),rough,metal),axis=2),True)
    tangent=image('normal',normal*.5+.5,True)
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat['surface_plan']=plan
    nd=mat.node_tree.nodes;lk=mat.node_tree.links;bs=nd.get('Principled BSDF')
    tex=nd.new('ShaderNodeTexImage');tex.image=albedo;lk.new(tex.outputs['Color'],bs.inputs['Base Color'])
    packed=nd.new('ShaderNodeTexImage');packed.image=orm;channels=nd.new('ShaderNodeSeparateColor')
    lk.new(packed.outputs['Color'],channels.inputs[0]);lk.new(channels.outputs['Green'],bs.inputs['Roughness']);lk.new(channels.outputs['Blue'],bs.inputs['Metallic'])
    tex=nd.new('ShaderNodeTexImage');tex.image=tangent;nmap=nd.new('ShaderNodeNormalMap');nmap.inputs['Strength'].default_value=.35
    lk.new(tex.outputs['Color'],nmap.inputs['Color']);lk.new(nmap.outputs['Normal'],bs.inputs['Normal'])
    return mat,records
