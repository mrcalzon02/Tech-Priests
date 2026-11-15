"""Rigid intact intake assembly, straight axial neck and true-radius small feed.

Only the native capture derivative is posed. The accepted engineering file,
all 64 reducer sections and frozen ten-mesh mouth remain unwarped.
"""
import math
import bpy
from mathutils import Matrix,Vector
try:
    from .mechanical_routes import hollow_sleeve,hollow_route
except ImportError:
    from mechanical_routes import hollow_sleeve,hollow_route


class FabricatorNativeFittings:
    def __init__(self,scene):
        self.scene=scene;prefix='TP Vessel Fabricator V02 | '
        self.mouth=[o for o in scene.objects if o.type=='MESH' and o.get('library_instance')=='forming-fluid intake']
        if len(self.mouth)!=10:raise RuntimeError('Expected unchanged ten-mesh intake')
        self.barrel=scene.objects[prefix+'forming-fluid receiving barrel'];self.reducer=scene.objects[prefix+'straight forming inlet reducer'];self.feed=scene.objects[prefix+'local forming-fluid feed']
        self.foot=scene.objects[prefix+'rear hinge grounded foot -1.5']
        self.anchors=[o for o in scene.objects if 'ground anchor rear hinge grounded foot -1.5' in o.name]
        self.basis={}
        for obj in self.mouth+[self.barrel,self.reducer,self.foot]+self.anchors:
            key='fabricator_native_original_basis'
            if key not in obj:obj[key]=[float(v) for row in obj.matrix_basis for v in row]
            raw=list(obj[key]);self.basis[obj]=Matrix([raw[i:i+4] for i in range(0,16,4)])
        self.base=sum((v.co for v in list(self.reducer.data.vertices)[:64]),Vector())/64
        name='TP_NATIVE_FITTING | fabricator full-bore straight intake extension';self.extension=scene.objects.get(name)
        if self.extension is None:
            self.extension=hollow_sleeve(self.reducer.users_collection[0],name,self.base,(-1,0,0),.01,.285,.245,self.reducer.data.materials[0])
            self.extension.parent=self.reducer.parent;self.extension.matrix_parent_inverse=self.reducer.matrix_parent_inverse;self.extension.matrix_basis=Matrix.Identity(4)
            self.extension['native_extension_radial']=[float(c) for v in self.extension.data.vertices for c in (v.co-self.base-Vector((-1,0,0))*(v.co-self.base).dot(Vector((-1,0,0))))]
        raw=list(self.extension['native_extension_radial']);self.radial=[Vector(raw[i:i+3]) for i in range(0,len(raw),3)]

    def apply(self,angle):
        rotation=Matrix.Rotation(math.radians(angle),3,'Z');old=rotation@Vector((-2,.5,.36))
        world_delta=Vector((0,(math.sqrt(2)-1)*old.y,0));delta=rotation.inverted()@world_delta
        axial=abs((rotation@Vector((-1,0,0))).y)>.5
        for obj in self.mouth+[self.barrel]:obj.matrix_basis=Matrix.Translation(delta)@self.basis[obj]
        # Side views shift the intact reducer with the receiving assembly. Its
        # small downstream feed has space for a real circular bend; no cast
        # reducer rings are skewed to manufacture a visual connection.
        self.reducer.matrix_basis=Matrix.Translation((0,delta.y if not axial else 0,0))@self.basis[self.reducer]
        self.extension.hide_render=not axial
        for index,(vertex,radial) in enumerate(zip(self.extension.data.vertices,self.radial)):
            vertex.co=self.base+radial+(delta if axial and index%48>=24 else Vector((-.001,0,0)) if index%48>=24 else Vector())
        self.extension.data.update()
        # The low, large barrel clears the left hinge mounting plate after the
        # lateral pose. Post overlap remains broad; original anchors follow it.
        for obj in [self.foot]+self.anchors:obj.matrix_basis=Matrix.Translation((.12,0,0))@self.basis[obj]
        y=.5+(delta.y if not axial else 0)
        path=[(-1.28,y,.40)]+[(-1.20+.10*math.cos(-math.pi/2+i*math.pi/24),y+.10+.10*math.sin(-math.pi/2+i*math.pi/24),.40) for i in range(13)]+[(-1.10,.96,.40)]
        temporary=hollow_route(self.feed.users_collection[0],'temporary native feed',path,.04,.0288,self.feed.data.materials[0],rounded=False)
        old_mesh=self.feed.data;self.feed.data=temporary.data.copy();self.feed['flow_path_samples']=[list(p) for p in path]
        bpy.data.objects.remove(temporary,do_unlink=True)
        if old_mesh.users==0:bpy.data.meshes.remove(old_mesh)
        self.scene['native_fitting_source_yaw']=angle
        return [dict(role='forming_fluid_intake',source_yaw=angle,rigid_world_offset=list(world_delta),method='unchanged rigid mouth and reducer; full-bore axial extension or intact lateral intake with constant-radius small feed; supported plate shifted .12')]
