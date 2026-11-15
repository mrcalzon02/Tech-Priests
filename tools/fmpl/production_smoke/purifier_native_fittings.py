"""Rigid V16 mouths and real axial extensions for native foreshortening."""
import math
import bpy
from mathutils import Matrix,Vector
try:
    from .mechanical_routes import hollow_sleeve
except ImportError:
    from mechanical_routes import hollow_sleeve


class PurifierNativeFittings:
    def __init__(self,scene):
        self.scene=scene;self.groups={};self.basis={};self.extensions={}
        for role,sign in [('raw-water-in',-1),('purified-water-out',1)]:
            prefix='FMPL_PROCESS | '+role+' / '
            # V16 preserves the original donor collars hidden beside the visible
            # UV-surfaced replacements. Only the rendered assembly may be moved.
            group=[scene.objects['TP_MH7_V14 | UV surfaced / '+prefix+part] for part in ('reusable machine collar','reusable machine throat')]
            group.extend(scene.objects[prefix+'actual flange bolt '+str(i).zfill(2)] for i in range(8))
            if any(o.type!='MESH' or o.hide_render for o in group):raise RuntimeError('Expected the exact ten visible V16 mouth meshes '+role)
            self.groups[role]=group
            for obj in group:
                key='purifier_native_original_basis'
                if key not in obj:obj[key]=[float(v) for row in obj.matrix_basis for v in row]
                raw=list(obj[key]);self.basis[obj]=Matrix([raw[i:i+4] for i in range(0,16,4)])
            throat=next(o for o in group if 'reusable machine throat' in o.name);base=Vector((sign*1.21,0,.36));axis=Vector((sign,0,0));name='TP_NATIVE_FITTING | purifier '+role+' full-bore axial extension'
            ext=scene.objects.get(name)
            if ext is None:
                ext=hollow_sleeve(throat.users_collection[0],name,base,axis,.01,.285,.245,throat.data.materials[0])
                ext.parent=throat.parent;ext.matrix_parent_inverse=throat.matrix_parent_inverse;ext.matrix_basis=Matrix.Identity(4)
                ext['purifier_native_radial']=[float(c) for vertex in ext.data.vertices for c in (vertex.co-base-axis*(vertex.co-base).dot(axis))]
            raw=list(ext['purifier_native_radial']);self.extensions[role]=(ext,base,axis,[Vector(raw[i:i+3]) for i in range(0,len(raw),3)])

    def apply(self,angle):
        rotation=Matrix.Rotation(math.radians(angle),3,'Z');inverse=rotation.inverted();rows=[]
        for role,sign in [('raw-water-in',-1),('purified-water-out',1)]:
            original=rotation@Vector((sign*1.5,0,.36));world_delta=Vector((0,(math.sqrt(2)-1)*original.y,0));delta=inverse@world_delta
            for obj in self.groups[role]:obj.matrix_basis=Matrix.Translation(delta)@self.basis[obj]
            ext,base,axis,radial=self.extensions[role];active=delta.length>.001;ext.hide_render=not active
            for index,(vertex,r) in enumerate(zip(ext.data.vertices,radial)):
                vertex.co=base+r+(delta+axis*.002 if index%48>=24 else -axis*.002)
            ext.data.update();ext['flow_path_samples']=[list(base-axis*.002),list(base+delta+axis*.002)]
            rows.append(dict(role=role,source_yaw=angle,rigid_world_offset=list(world_delta),mouth_center=list(original+world_delta),method='Original ten-mesh mouth moved rigidly; original receiving throat remains connected by an actual constant-bore axial sleeve. Accepted body/camera unchanged.'))
        self.scene['purifier_native_fitting_yaw']=angle;return rows
