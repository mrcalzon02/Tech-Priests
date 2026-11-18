"""Capture-only broken energy tracks on actual narrow dished projector surfaces.

No source vertices, UVs, matrices or cold materials change. This is newly
authored working FX, not recovered GLB emission or floating ring geometry.
"""
import math

def build_emitter_energy(body_objects,*,family,axis):
 import bpy
 from mathutils import Vector
 if family!='void-fusion-thruster':return {},{'status':'PRESERVE_EXISTING_WIDE_EXPORTED_EMISSION','new_working_materials':[]}
 direction=Vector(axis).normalized();reference=Vector((1,0,0));u=direction.cross(reference).normalized();v=direction.cross(u).normalized();materials={};parts=[]
 targets=[o for o in body_objects if o.name.startswith('V05 tier')and'thick concave annular dish'in o.name]
 assert len(targets)==3,('Actual narrow dished projector surfaces missing',len(targets))
 for index,o in enumerate(sorted(targets,key=lambda q:q.name)):
  points=[o.matrix_world@p.co for p in o.data.vertices];center=Vector([(min(p[i]for p in points)+max(p[i]for p in points))/2 for i in range(3)]);axial=[p.dot(direction)for p in points];lo,hi=min(axial),max(axial);radii=[((p-center)-direction*(p-center).dot(direction)).length for p in points];radius=max(radii);mask=[]
  for p,r,s in zip(points,radii,axial):
   q=p-center;theta=math.atan2(q.dot(v),q.dot(u));sector=((theta/math.tau+1)*24+index*.31)%1
   angular=max(0,min(1,sector/.10,(.76-sector)/.10))
   radial=max(0,min(1,(r/radius-.80)/.10));front=max(0,min(1,(s-(lo+.50*(hi-lo)))/max(1e-6,.20*(hi-lo))))
   mask.append(angular*radial*front)
  assert max(mask)>.1,('No actual rim vertices selected',o.name)
  attr=o.data.color_attributes.new(name='CAPTURE_ACTUAL_RIM_ENERGY',type='FLOAT_COLOR',domain='POINT')
  for datum,value in zip(attr.data,mask):datum.color=(value,value,value,1)
  m=bpy.data.materials.new('CAPTURE_NEW_EMITTER_ENERGY | '+o.name);m.use_nodes=True;nt=m.node_tree;nt.nodes.clear();source=nt.nodes.new('ShaderNodeVertexColor');source.layer_name=attr.name;mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=2.0;nt.links.new(source.outputs['Color'],mul.inputs[0]);e=nt.nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(.035,1,.001,1);nt.links.new(mul.outputs[0],e.inputs['Strength']);out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(e.outputs[0],out.inputs['Surface']);m.use_fake_user=True;materials[o.name]=m.name
  parts.append({'actual_mesh':o.name,'attribute':attr.name,'working_material':m.name,'actual_vertex_count':len(points),'energized_vertex_count':sum(x>0 for x in mask),'outer_radius':radius,'actual_axial_bounds':[lo,hi],'segments':24,'gap_fraction':.24,'meaning':'Broken material mask seated on actual dish rim/front surfaces. No added tube/ring mesh and no cold/source material change.'})
 return materials,{'status':'NEW_CAPTURE_ONLY_ACTUAL_SURFACE_ENERGIZATION','new_working_materials':parts,'global_baked_brightness_sine':False,'brightness_owner':'Actual native electrical draw factor/1.5 applied to normalized whole-engine energy layer.'}
