"""Rigid crucible mouths with straight axial extensions for native projection.

The input is a native fluid connection; the opposite assembly is a sealed
pellet-transfer mouth, not a second fluid box. Neither reducer is twisted.
"""
from mathutils import Matrix,Vector
try:
    from .electrolyzer_native_fittings import NativeFittings
    from .mechanical_routes import hollow_sleeve
except ImportError:
    from electrolyzer_native_fittings import NativeFittings
    from mechanical_routes import hollow_sleeve


class CrucibleNativeFittings(NativeFittings):
    PORTS={
        'conditioned_hydrogen_input':((-2.5,0,.36),'conditioned_hydrogen_input straight coaxial cast reducer','conditioned_hydrogen_input full-size receiving barrel'),
        'metallicized_intermediate_output':((2.5,0,.36),'metallicized_intermediate_output straight coaxial cast reducer','metallicized_intermediate_output full-size receiving barrel'),
    }

    def __init__(self,scene):
        self.scene=scene;self.groups={};self.basis={};self.vertices={};self.reducers={};self.barrels={};self.shoes=[];self.extensions={}
        prefix='TP Metallization Crucible V01 | '
        for role,(center,reducer,barrel) in self.PORTS.items():
            group=[o for o in scene.objects if o.type=='MESH' and o.get('library_instance')==role]
            if len(group)!=10:raise RuntimeError('Expected exact original ten-mesh mouth '+role)
            self.groups[role]=group;self.reducers[role]=scene.objects[prefix+reducer];self.barrels[role]=scene.objects[prefix+barrel]
            for ob in group+[self.barrels[role]]:
                key='native_fitting_original_basis'
                if key not in ob:ob[key]=[float(v) for row in ob.matrix_basis for v in row]
                raw=list(ob[key]);self.basis[ob]=Matrix([raw[i:i+4] for i in range(0,16,4)])
            ob=self.reducers[role];key='native_fitting_original_vertices'
            if key not in ob:
                if len(ob.data.vertices)!=256:raise RuntimeError('Expected real 64-section straight reducer')
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
