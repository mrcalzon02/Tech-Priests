"""View-pose pipe geometry for the fixed 45-degree native sprite projection.

The machine and frozen .49-ID mouths keep their geometry. Each mouth is moved
rigidly, its receiving barrel follows, and only its cast taper's outer/inner
receiving rings change. This is a real editable capture derivative, never a
pixel patch or a claim that model-space Y already equals native screen Y.
"""
import math
import bpy
from mathutils import Matrix,Vector
try:
    from .mechanical_routes import hollow_sleeve
except ImportError:
    from mechanical_routes import hollow_sleeve


class NativeFittings:
    PORTS={
        'water_input':((0,-2,.36),'raw water full-size feed reducer',None),
        'hydrogen_output':((-1.5,.5,.36),'full-size gas mouth reducer -1','full-size straight gas receiving barrel -1'),
        'oxygen_output':((1.5,.5,.36),'full-size gas mouth reducer 1','full-size straight gas receiving barrel 1'),
    }

    def __init__(self,scene):
        self.scene=scene;self.groups={};self.basis={};self.vertices={};self.reducers={};self.barrels={};self.shoes=[];self.extensions={}
        for ob in scene.objects:
            if 'column shoe' in ob.name and abs(ob.location.y-1)<.11:
                key='native_fitting_original_basis'
                if key not in ob:ob[key]=[float(v) for row in ob.matrix_basis for v in row]
                raw=list(ob[key]);self.basis[ob]=Matrix([raw[i:i+4] for i in range(0,16,4)])
                self.shoes.append(ob)
        if len(self.shoes)!=2:raise RuntimeError('Expected two actual rear column shoes')
        for role,(_,reducer,barrel) in self.PORTS.items():
            group=[o for o in scene.objects if o.type=='MESH' and o.get('library_instance')==role]
            if len(group)!=10:raise RuntimeError('Expected exact frozen ten-mesh mouth '+role)
            self.groups[role]=group
            self.reducers[role]=scene.objects['TP_ELECTROLYZER_V01 | '+reducer]
            self.barrels[role]=scene.objects['TP_ELECTROLYZER_V01 | '+barrel] if barrel else None
            for ob in group+([self.barrels[role]] if barrel else []):
                key='native_fitting_original_basis'
                if key not in ob:ob[key]=[float(v) for row in ob.matrix_basis for v in row]
                raw=list(ob[key]);self.basis[ob]=Matrix([raw[i:i+4] for i in range(0,16,4)])
            ob=self.reducers[role];key='native_fitting_original_vertices'
            if key not in ob:
                if len(ob.data.vertices)!=256:raise RuntimeError('Expected actual 64-section hollow cast reducer')
                ob.data=ob.data.copy();ob[key]=[float(c) for v in ob.data.vertices for c in v.co]
            raw=list(ob[key]);self.vertices[ob]=[Vector(raw[i:i+3]) for i in range(0,len(raw),3)]
            normal=Vector((0,-1,0) if role=='water_input' else (-1,0,0) if role=='hydrogen_output' else (1,0,0))
            base=sum(self.vertices[ob][:64],Vector())/64
            name='TP_NATIVE_FITTING | '+role+' full-bore straight extension'
            ext=scene.objects.get(name)
            if ext is None:
                ext=hollow_sleeve(ob.users_collection[0],name,base,normal,.01,.285,.245,ob.data.materials[0])
                ext.parent=ob.parent;ext.matrix_parent_inverse=ob.matrix_parent_inverse;ext.matrix_basis=Matrix.Identity(4)
                ext['native_extension_radial']=[float(c) for vertex in ext.data.vertices for c in (vertex.co-base-normal*(vertex.co-base).dot(normal))]
            raw=list(ext['native_extension_radial']);radial=[Vector(raw[i:i+3]) for i in range(0,len(raw),3)]
            self.extensions[role]=(ext,base,normal,radial)

    def apply(self,angle):
        rotation=Matrix.Rotation(math.radians(angle),3,'Z');inverse=rotation.inverted()
        result=[]
        # Shift the two rear shoes .09 along the foundation. The original
        # anchor heads remain inside each plate, and the columns retain a
        # broad seat, while the relocated large mouth cores clear the plate.
        for ob in self.shoes:ob.matrix_basis=Matrix.Translation((0,.09,0)) @ self.basis[ob]
        for role,(center,_,_) in self.PORTS.items():
            old=rotation @ Vector(center)
            world_delta=Vector((0,(math.sqrt(2)-1)*old.y,0))
            delta=inverse @ world_delta
            for ob in self.groups[role]+([self.barrels[role]] if self.barrels[role] else []):
                ob.matrix_basis=Matrix.Translation(delta) @ self.basis[ob]
            ob=self.reducers[role]
            ext,base,normal,radial=self.extensions[role]
            axial=abs((rotation @ normal).y)>.5 and delta.length>.001
            ext.hide_render=not axial
            for i,(vertex,r) in enumerate(zip(ext.data.vertices,radial)):
                vertex.co=base+r+(delta if i%48>=24 and axial else normal*.001 if i%48>=24 else Vector())
            ext.data.update()
            for i,(vertex,original) in enumerate(zip(ob.data.vertices,self.vertices[ob])):
                vertex.co=original+(delta if not axial and (i<64 or 128<=i<192) else Vector((0,0,0)))
            ob.data.update()
            result.append(dict(role=role,source_yaw=angle,rigid_world_offset=list(world_delta),
                posed_mouth_center=list(old+world_delta),
                projected_native_relative=[old.x,-old.y-.36*math.sqrt(.5)],
                method='rigid donor mouth/barrel; full-bore straight axial extension or offset receiving taper; fixed camera unchanged'))
        self.scene['native_fitting_source_yaw']=angle
        return result
