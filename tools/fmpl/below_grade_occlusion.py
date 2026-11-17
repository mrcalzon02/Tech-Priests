"""FMPL below-grade aperture occlusion v1.

Render-only grade holdouts admit underground geometry only through declared
rectangular viewport apertures. Model geometry and above-grade details are not
flattened or destructively clipped. Export callers exclude fmpl_render_only
objects and ship the manifest; independent GLB inspection reconstructs this same
render environment. Factorio receives the baked, bounded RGBA sprite.
"""
SCHEMA='fmpl.below-grade-aperture.v1'

def add_grade_holdouts(scene,bpy,manifest,parent=None):
 assert manifest['schema']==SCHEMA
 apertures=manifest['apertures'];extent=manifest.get('environment_half_extent',40.0);z=manifest.get('grade_z',0)+.0005
 xs=sorted(set([-extent,extent]+[p[k] for p in apertures for k in ('xmin','xmax')]));ys=sorted(set([-extent,extent]+[p[k] for p in apertures for k in ('ymin','ymax')]))
 col=bpy.data.collections.new('FMPL OCCLUSION | grade outside viewport apertures');scene.collection.children.link(col)
 mat=bpy.data.materials.new('FMPL | render-only grade holdout');mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');hold=nodes.new('ShaderNodeHoldout');mat.node_tree.links.new(hold.outputs[0],out.inputs['Surface'])
 verts=[];faces=[]
 for xa,xb in zip(xs,xs[1:]):
  for ya,yb in zip(ys,ys[1:]):
   x=(xa+xb)/2;y=(ya+yb)/2
   if any(p['xmin']<x<p['xmax'] and p['ymin']<y<p['ymax'] for p in apertures):continue
   i=len(verts);verts.extend([(xa,ya,z),(xb,ya,z),(xb,yb,z),(xa,yb,z)]);faces.append((i,i+1,i+2,i+3))
 mesh=bpy.data.meshes.new('Grade inverse aperture mask');mesh.from_pydata(verts,[],faces);mesh.update();ob=bpy.data.objects.new('FMPL | grade holdout, never export',mesh);col.objects.link(ob);ob.data.materials.append(mat);ob.parent=parent;ob['fmpl_render_only']=True;ob['fmpl_occlusion_schema']=SCHEMA;return ob

def add_aperture_mask(scene,bpy,manifest,parent=None):
 col=bpy.data.collections.new('FMPL QA | aperture positive mask');scene.collection.children.link(col);mat=bpy.data.materials.new('FMPL QA | white aperture');mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Emission Color'].default_value=(1,1,1,1);bs.inputs['Emission Strength'].default_value=1
 verts=[];faces=[];z=manifest.get('grade_z',0)+.0006
 for p in manifest['apertures']:
  i=len(verts);verts.extend([(p['xmin'],p['ymin'],z),(p['xmax'],p['ymin'],z),(p['xmax'],p['ymax'],z),(p['xmin'],p['ymax'],z)]);faces.append((i,i+1,i+2,i+3))
 me=bpy.data.meshes.new('Positive viewport mask');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('FMPL QA | positive viewport mask',me);col.objects.link(ob);ob.data.materials.append(mat);ob.parent=parent;ob['fmpl_render_only']=True;return ob
