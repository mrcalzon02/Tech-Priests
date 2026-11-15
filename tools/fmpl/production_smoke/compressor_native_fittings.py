"""Compressor-local fitting poses; accepted electrolyzer source stays frozen."""
import bpy
import bmesh
from mathutils import Matrix,Vector

try:
    from .electrolyzer_native_fittings import NativeFittings
    from .mechanical_routes import hollow_sleeve
except ImportError:
    from electrolyzer_native_fittings import NativeFittings
    from mechanical_routes import hollow_sleeve


class CompressorNativeFittings(NativeFittings):
    PORTS={
        'hydrogen_suction':((-1.5,.5,.36),'suction cast mouth reducer','suction full size receiving barrel'),
        'hydrogen_discharge':((1.5,.5,.36),'discharge cast mouth reducer','discharge full size receiving barrel'),
    }

    def __init__(self,scene):
        self.scene=scene;self.groups={};self.basis={};self.vertices={};self.reducers={};self.barrels={};self.shoes=[];self.extensions={}
        prefix='TP Hydrogen Compressor V01 | '
        # Relieve the fixed bed at the actual posed pipe locations. This only
        # changes the capture derivative, not the engineering source on disk.
        for x in (-1.25,1.25):
            rail=scene.objects[prefix+'longitudinal bed rail '+str(x)]
            if rail.get('native_compressor_port_relief'):continue
            rail.data=rail.data.copy();bpy.context.view_layer.objects.active=rail
            bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.288,depth=.45,location=(x,.7071067812,.36))
            cutter=bpy.context.object;cutter.rotation_euler.y=1.5707963267948966
            bpy.context.view_layer.objects.active=rail;modifier=rail.modifiers.new('Native posed receiving-barrel clearance','BOOLEAN')
            modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
            bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
            bm=bmesh.new();bm.from_mesh(rail.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
            bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
            bm.to_mesh(rail.data);bm.free();rail['native_compressor_port_relief']=True
        for role,(center,reducer,barrel) in self.PORTS.items():
            group=[o for o in scene.objects if o.type=='MESH' and o.get('library_instance')==role]
            if len(group)!=10:raise RuntimeError('Expected exact frozen ten-mesh mouth '+role)
            self.groups[role]=group;self.reducers[role]=scene.objects[prefix+reducer];self.barrels[role]=scene.objects[prefix+barrel]
            for ob in group+[self.barrels[role]]:
                key='native_fitting_original_basis'
                if key not in ob:ob[key]=[float(v) for row in ob.matrix_basis for v in row]
                raw=list(ob[key]);self.basis[ob]=Matrix([raw[i:i+4] for i in range(0,16,4)])
            ob=self.reducers[role];key='native_fitting_original_vertices'
            if key not in ob:
                if len(ob.data.vertices)!=256:raise RuntimeError('Expected actual 64-section reducer')
                ob.data=ob.data.copy();ob[key]=[float(c) for v in ob.data.vertices for c in v.co]
            raw=list(ob[key]);self.vertices[ob]=[Vector(raw[i:i+3]) for i in range(0,len(raw),3)]
            normal=Vector((-1,0,0) if center[0]<0 else (1,0,0));base=sum(self.vertices[ob][:64],Vector())/64
            name='TP_NATIVE_FITTING | '+role+' full-bore straight extension';ext=scene.objects.get(name)
            if ext is None:
                ext=hollow_sleeve(ob.users_collection[0],name,base,normal,.01,.285,.245,ob.data.materials[0])
                ext.parent=ob.parent;ext.matrix_parent_inverse=ob.matrix_parent_inverse;ext.matrix_basis=Matrix.Identity(4)
                ext['native_extension_radial']=[float(c) for vertex in ext.data.vertices for c in (vertex.co-base-normal*(vertex.co-base).dot(normal))]
            raw=list(ext['native_extension_radial']);radial=[Vector(raw[i:i+3]) for i in range(0,len(raw),3)]
            self.extensions[role]=(ext,base,normal,radial)
