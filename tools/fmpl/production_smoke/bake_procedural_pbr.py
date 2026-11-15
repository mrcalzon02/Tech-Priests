"""Bake an actual single-surface procedural material to model-local glTF PBR.

Blender only. Caller works in a derivative scene; native source is never saved
by this module. Volume materials are explicitly unsupported by this adapter.
"""
from pathlib import Path
import array
import hashlib
import bpy

def bake_object(ob, directory, size=256):
    if ob.type!='MESH' or len(ob.data.materials)!=1:
        raise ValueError('One actual mesh/surface required: '+ob.name)
    original=ob.data.materials[0]
    if not original or not original.use_nodes: raise ValueError('Missing source surface')
    outputs=[n for n in original.node_tree.nodes if n.type=='OUTPUT_MATERIAL' and n.is_active_output]
    if len(outputs)!=1 or outputs[0].inputs['Volume'].is_linked:
        raise ValueError('Volume or ambiguous material requires a different exporter: '+original.name)
    surfaces=[n for n in original.node_tree.nodes if n.type=='BSDF_PRINCIPLED']
    if len(surfaces)!=1: raise ValueError('Expected one source Principled surface')
    directory=Path(directory); directory.mkdir(parents=True,exist_ok=True)
    slug=hashlib.sha256(ob.name.encode()).hexdigest()[:12]
    ob.data=ob.data.copy()
    source=original.copy(); source.name='Bake source | '+ob.name
    ob.data.materials[0]=source
    nodes=source.node_tree.nodes; links=source.node_tree.links
    surface=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL' and n.is_active_output)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.025)
    bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.device='CPU'
    scene.cycles.samples=8; scene.render.bake.margin=5
    emission=nodes.new('ShaderNodeEmission'); target=nodes.new('ShaderNodeTexImage')
    nodes.active=target
    def image(name, noncolor=False):
        im=bpy.data.images.new('TP MH7 | '+slug+' '+name,width=size,height=size,alpha=True)
        if noncolor: im.colorspace_settings.name='Non-Color'
        im.filepath_raw=str(directory/(slug+'-'+name+'.png')); im.file_format='PNG'
        return im
    def emit_channel(socket,name,noncolor=False):
        im=image(name,noncolor); target.image=im
        for link in list(emission.inputs['Color'].links): links.remove(link)
        if socket.is_linked: links.new(socket.links[0].from_socket,emission.inputs['Color'])
        else:
            value=socket.default_value
            emission.inputs['Color'].default_value=tuple(value) if hasattr(value,'__len__') else (value,value,value,1.)
        links.new(emission.outputs[0],output.inputs['Surface'])
        bpy.ops.object.bake(type='EMIT',use_clear=True)
        im.save(); im.pack(); return im
    albedo=emit_channel(surface.inputs['Base Color'],'albedo')
    rough=emit_channel(surface.inputs['Roughness'],'roughness',True)
    # Restore the actual source normal graph before baking tangent normals.
    links.new(surface.outputs['BSDF'],output.inputs['Surface'])
    normal=image('normal',True); target.image=normal
    bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',use_clear=True)
    normal.save(); normal.pack()
    mr=image('metallic-roughness',True)
    raw=array.array('f',[0.])*(size*size*4); rough.pixels.foreach_get(raw)
    for i in range(0,len(raw),4): raw[i:i+4]=array.array('f',(1.,raw[i],0.,1.))
    mr.pixels.foreach_set(raw); mr.save(); mr.pack()
    material=bpy.data.materials.new('TP Purifier baked | '+slug+' | '+original.name)
    material.use_nodes=True
    if hasattr(material,'surface_render_method'): material.surface_render_method='DITHERED'
    nd=material.node_tree.nodes; lk=material.node_tree.links
    bs=nd.get('Principled BSDF')
    for name in ('IOR','Transmission Weight','Alpha','Emission Color','Emission Strength','Coat Weight'):
        if surface.inputs.get(name) and not surface.inputs[name].is_linked:
            bs.inputs[name].default_value=surface.inputs[name].default_value
    color=nd.new('ShaderNodeTexImage'); color.image=albedo
    lk.new(color.outputs['Color'],bs.inputs['Base Color'])
    packed=nd.new('ShaderNodeTexImage'); packed.image=mr
    separate=nd.new('ShaderNodeSeparateColor'); separate.mode='RGB'
    lk.new(packed.outputs['Color'],separate.inputs['Color'])
    lk.new(separate.outputs['Green'],bs.inputs['Roughness'])
    lk.new(separate.outputs['Blue'],bs.inputs['Metallic'])
    tex=nd.new('ShaderNodeTexImage'); tex.image=normal
    normalnode=nd.new('ShaderNodeNormalMap'); lk.new(tex.outputs['Color'],normalnode.inputs['Color'])
    lk.new(normalnode.outputs['Normal'],bs.inputs['Normal'])
    material['source_material']=original.name
    material['surface_plan']='actual object-local color, roughness and tangent-normal bake; no volume conversion'
    ob.data.materials[0]=material
    return dict(object=ob.name,source_material=original.name,material=material.name,
        size=size,channels={key:dict(path=im.filepath_raw,sha256=hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest())
             for key,im in (('base_color',albedo),('metallic_roughness',mr),('normal',normal))})
