"""Small authored-machine kit: frozen library append, named meshes and camera.

Geometry and process design belong to each machine generator. This helper does
not provide a generic silhouette or promote native interfaces automatically.
"""
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import refine_process as p
from blender_build import uv_for_visible_surface
from mechanical_routes import hollow_route,hollow_sleeve
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from blender_camera_guard import install_canonical_camera


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class MachineScene:
    def __init__(self,name,donor,registry,material_prefix='TP Library | '):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.name=name;self.prefix='TP '+name+' | ';self.scene=bpy.context.scene
        self.registry_path=Path(registry).resolve();self.registry=json.loads(self.registry_path.read_text())
        self.registry_sha=sha(self.registry_path);self.instances=[]
        self.cols={k:bpy.data.collections.new(k) for k in ('FRAME','PROCESS','PIPING','CONTROLS','PORT_MARKERS')}
        for col in self.cols.values():self.scene.collection.children.link(col)
        keys=('ferrocrete_dark','iron','machine_steel','brass','martian_red','gunmetal_dark','dark_recess')
        with bpy.data.libraries.load(str(Path(donor).resolve()),link=False) as (fr,to):to.materials=[material_prefix+k for k in keys]
        self.mats={}
        for key,mat in zip(keys,to.materials):
            if mat is None:raise RuntimeError('Actual packed donor material missing '+key)
            local=mat.copy();local.name=self.prefix+key
            if local.asset_data:local.asset_clear()
            self.mats[key]=local
    def own(self,ob,label,role):
        ob.name=self.prefix+label;ob['assembly_role']=role
        ob['provenance']='new construction from MH7 process packet; not recovered historical meshes'
        if ob.type=='MESH' and not ob.data.uv_layers:uv_for_visible_surface(ob)
        return ob
    def box(self,label,loc,size,mat='iron',role='FRAME',bevel=.008):
        ob=p.block(self.cols[role],label,loc,size,self.mats[mat],bevel);uv_for_visible_surface(ob)
        return self.own(ob,label,role)
    def cyl(self,label,loc,radius,depth,mat='machine_steel',axis='Z',role='PROCESS',vertices=40):
        return self.own(p.cyl(self.cols[role],label,loc,radius,depth,self.mats[mat],axis,vertices),label,role)
    def sleeve(self,label,center,axis,length,outer,inner,mat='iron',role='PROCESS',segments=40):
        return self.own(hollow_sleeve(self.cols[role],label,center,axis,length,outer,inner,self.mats[mat],segments),label,role)
    def pipe(self,label,points,radius=.06,mat='iron'):
        return self.own(hollow_route(self.cols['PIPING'],label,points,radius,radius*.72,self.mats[mat]),label,'PIPING')
    def torus(self,label,center,major,minor,mat='brass',axis='Z',role='PROCESS'):
        return self.own(p.torus(self.cols[role],label,center,major,minor,self.mats[mat],axis),label,role)
    def beam(self,label,a,b,width=.07,depth=.06,mat='iron',role='FRAME'):
        a,b=Vector(a),Vector(b);ob=self.box(label,(a+b)/2,(width,depth,(b-a).length),mat,role)
        ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob
    def reuse(self,part_id,label,transform,role):
        part=next(p for p in self.registry['parts'] if p['part_id']==part_id and p['revision']=='v1')
        source=self.registry_path.parent/part['source_blend']
        if part['status']!='verified' or sha(source)!=part['source_sha256']:raise RuntimeError('Unverified/changed library master')
        with bpy.data.libraries.load(str(source),link=False) as (fr,to):to.collections=[part['collection']]
        collection=to.collections[0];collection.name=self.prefix+label;self.cols[role].children.link(collection)
        bpy.context.view_layer.update();frames={o:o.matrix_world.copy() for o in collection.all_objects};materials={}
        for ob in collection.all_objects:
            ob.matrix_world=transform @ frames[ob];ob.name=self.prefix+label+' / '+ob.name;ob['library_instance']=label
            for slot in ob.material_slots:
                if not slot.material:continue
                if slot.material not in materials:
                    local=slot.material.copy();local.name=self.prefix+'donor '+local.name
                    if local.asset_data:local.asset_clear()
                    materials[slot.material]=local
                slot.material=materials[slot.material]
        self.instances.append(dict(part_id=part_id,revision='v1',source_blend=part['source_blend'],source_sha256=part['source_sha256'],instance=label,transform=[list(r) for r in transform]))
        return collection
    def camera(self,target_z=1,scale=6.35):
        s=self.scene;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24;s.cycles.seed=4362
        s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100
        s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
        s.render.fps=24;s.frame_start=0;s.frame_end=97
        cfg=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',directions=[0,90,180,270],source_size=640,
          states={'idle':[0],'working':[25]},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,distance=6*math.sqrt(2),target=[0,0,target_z],ortho_scale=scale,shift_x=0,shift_y=0))
        install_canonical_camera(s,cfg,bpy)
        for name,loc,power,size in (('Key',(-3,-4,7),1150,5),('Fill',(4,-2,5),700,4),('Rim',(0,5,6),1000,4)):
            data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size
            ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=loc
            ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
        s.world=bpy.data.worlds.new('Neutral industrial world');s.world.use_nodes=True
        s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.11,.11,.11,1)
    def save(self,out,filename):
        out=Path(out);bpy.ops.file.pack_all();self.scene.frame_set(25)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/filename),check_existing=False)
        (out/'part_provenance.json').write_text(json.dumps(dict(registry_sha256=self.registry_sha,instances=self.instances),indent=2)+'\n')
        self.scene.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
