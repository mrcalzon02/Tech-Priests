"""Deterministic, surface-anchored short electrical crackle capture derivative.

Public API (Blender):
    receipt = build_electric_arcs(body_objects, family=..., seed=6143,
        samples=64, cycle_start=1, cycle_end=97, strength=.24)
    set_electric_arcs_phase(receipt, phase)  # normalized phase; 1 wraps to 0

Only newly owned ribbon meshes/object colors/visibility change. Actual source
surface rays anchor both main ends and each branching end. This is light/FX,
not physical wires, Pipette, hose, particle exhaust or closed field tubes.
Local discrete crackle has no independent global brightness sine: the native
whole-engine electrical-draw envelope belongs to the runtime/capture owner.
"""
from __future__ import annotations
import hashlib,json,math,pathlib,random,struct,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

VERSION='electric-arcs-v1'

def geometry_digest(objects):
    from array import array
    h=hashlib.sha256()
    for o in sorted(objects,key=lambda q:q.name):
        h.update(o.name.encode());h.update(struct.pack('<16d',*(x for row in o.matrix_world for x in row)))
        a=array('f',[0])*(len(o.data.vertices)*3);o.data.vertices.foreach_get('co',a);h.update(a.tobytes());o.data.calc_loop_triangles()
        a=array('i',[0])*(len(o.data.loop_triangles)*3);o.data.loop_triangles.foreach_get('vertices',a);h.update(a.tobytes())
    return h.hexdigest()

def _unit(seed,*parts):
    s=str(seed)+'|'+'|'.join(map(str,parts));return int(hashlib.sha256(s.encode()).hexdigest()[:13],16)/float(16**13)

def _roles(objects):
    roles={'stone':[],'contact':[],'cage':[],'coil':[]}
    for o in objects:
        n=o.name.lower()
        if (n.startswith('v04 retained noctilith blackrock ') or n.startswith('fractured noctilith block ')):roles['stone'].append(o)
        elif ('fitted ceramic contact' in n or 'fitted mineral contact shoe' in n or 'shaped copper pocket carrier' in n):roles['contact'].append(o)
        elif ('cage longitudinal crown rail' in n or 'tapered cage shoulder' in n or n.startswith('open cage formed retaining channel')):roles['cage'].append(o)
        elif ('continuous visible route' in n and ('narrow-coil-' in n or 'wide-winding-' in n)):roles['coil'].append(o)
    return {k:sorted(v,key=lambda q:q.name) for k,v in roles.items()}

class _Surface:
    def __init__(self,obj):
        self.obj=obj;m=obj.data;m.calc_loop_triangles();self.v=[obj.matrix_world@v.co for v in m.vertices];self.tri=[tuple(t.vertices) for t in m.loop_triangles]
        self.tree=BVHTree.FromPolygons(self.v,self.tri,all_triangles=True);self.lo=Vector([min(p[i] for p in self.v) for i in range(3)]);self.hi=Vector([max(p[i] for p in self.v) for i in range(3)]);self.center=(self.lo+self.hi)/2
    def anchor(self,point):
        near=self.tree.find_nearest(Vector(point))
        if near[0] is None:return None
        p,n=near[:2];n.normalize();hit=self.tree.ray_cast(p+n*.018,-n,.036)
        if hit[0] is None:return None
        p,n,index,_=hit;n.normalize();proof=self.tree.ray_cast(p+n*.006,-n,.012)
        if proof[0] is None or (proof[0]-p).length>1e-5:return None
        return {'object':self.obj.name,'point':list(p),'normal':list(n),'triangle_index':index,'actual_local_surface_ray_error':(proof[0]-p).length}
    def candidates(self,maximum=128):
        step=max(1,len(self.tri)//maximum);rows=[]
        for tri in self.tri[::step]:
            a,b,c=[self.v[i] for i in tri];normal=(b-a).cross(c-a)
            if normal.length<1e-10:continue
            normal.normalize()
            if normal.z<-.20:continue
            p=(a+b+c)/3;row=self.anchor(p)
            if row is not None:rows.append(row)
        return rows

def _pair(stone,target_surfaces,side,max_gap,seed,role,min_gap=.026):
    choices=[]
    for a in stone.candidates():
        p=Vector(a['point']);na=Vector(a['normal'])
        if side*(p.x-stone.center.x)<-.015:continue
        for target in target_surfaces:
            if target.obj is stone.obj:continue
            # Conservative AABB reject only; actual end is obtained by a ray.
            if any(p[i]<target.lo[i]-max_gap or p[i]>target.hi[i]+max_gap for i in range(3)):continue
            b=target.anchor(p+na*.045+Vector((side*.025,0,.025)))
            if b is None:continue
            q=Vector(b['point']);delta=q-p;d=delta.length
            if not min_gap<d<max_gap:continue
            direction=delta/d;nb=Vector(b['normal'])
            if na.dot(direction)<-.10 or nb.dot(-direction)<-.10:continue
            score=abs(d-max_gap*.45)+abs(p.y-stone.center.y)*.06+_unit(seed,stone.obj.name,target.obj.name,role,a['triangle_index'])*.015
            choices.append((score,a,b))
    return min(choices,key=lambda q:q[0])[1:] if choices else None

def _emission(name):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;nt=mat.node_tree;nt.nodes.clear();info=nt.nodes.new('ShaderNodeObjectInfo');em=nt.nodes.new('ShaderNodeEmission');em.name='ELECTRIC_ARC_NORMALIZED_RADIANCE';em.inputs['Strength'].default_value=1;out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(info.outputs['Color'],em.inputs['Color']);nt.links.new(em.outputs[0],out.inputs['Surface']);return mat

def _mesh_object(name,material,collection):
    me=bpy.data.meshes.new(name);obj=bpy.data.objects.new(name,me);collection.objects.link(obj);me.materials.append(material);obj['electric_arc_derivative']=VERSION;return obj

def _ribbons(paths,width,inner_width=0):
    vv=[];ff=[]
    for points in paths:
        for i,(a,b) in enumerate(zip(points,points[1:])):
            axis=(b-a).normalized();ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(ref).normalized();v=axis.cross(u).normalized()
            taper=.64+.36*math.sin(math.pi*(i+.5)/(len(points)-1))
            for n in (u,v):
                if inner_width:
                    # Hollow side bands leave the central bright ribbon
                    # physically uncovered; no coplanar opaque fringe overlay.
                    for sign in (-1,1):
                        inside=n*(inner_width*.5*taper*sign);outside=n*(width*.5*taper*sign);k=len(vv);vv += [tuple(a+inside),tuple(a+outside),tuple(b+outside),tuple(b+inside)];ff.append((k,k+1,k+2,k+3))
                else:
                    w=n*(width*.5*taper);k=len(vv);vv += [tuple(a-w),tuple(a+w),tuple(b+w),tuple(b-w)];ff.append((k,k+1,k+2,k+3))
    return vv,ff

def build_electric_arcs(body_objects,*,family,seed=6143,samples=64,cycle_start=1,cycle_end=97,strength=.24,violent=False):
    """Build independently owned FX; return JSON-serializable names/anchor proof.

    Material linear radiance <=strength, default .24 (Standard display ~.53).
    Capture owner must still decode combined energy PNGs and normalize their
    final RGB peak for runtime gain0.5..1.5; material intent alone is not a
    guarantee against combined-layer clipping.
    """
    if family not in ('void-fusion-thruster','large-void-fusion-thruster','narrow','wide'):raise ValueError('Explicit fusion family required')
    if samples!=64 or cycle_end<=cycle_start or not 0<strength<=.30:raise ValueError('Expected64samples, positive cycle and normalized strength<=.30')
    objects=[o for o in body_objects if o.type=='MESH'];bpy.context.view_layer.update();before=geometry_digest(objects);roles=_roles(objects)
    if not roles['stone'] or not roles['cage'] or not roles['coil']:raise ValueError(('Actual source stone/cage/coil roles missing',{k:len(v)for k,v in roles.items()}))
    prefix='CAPTURE_ELECTRIC_ARCS | '+family
    if bpy.data.collections.get(prefix):raise ValueError('Arc collection already exists; reuse its receipt')
    col=bpy.data.collections.new(prefix);bpy.context.scene.collection.children.link(col);core=_emission(prefix+' | pale green core');fringe=_emission(prefix+' | green fringe');surfaces={o.name:_Surface(o) for group in roles.values() for o in group};pairs=[]
    max_gap=.38 if family in ('narrow','void-fusion-thruster') else .58
    for rock in roles['stone']:
        a=surfaces[rock.name]
        for role in ('contact','cage','coil'):
            targets=[surfaces[o.name] for o in roles[role]]
            for side in (-1,1):
                pair=_pair(a,targets,side,max_gap,seed,role)
                if pair:pairs.append((pair[0],pair[1],'stone-to-'+role,side))
    # Additional crackles over the induction equipment cover both long sides.
    for winding in roles['coil']:
        a=surfaces[winding.name];pair=_pair(a,[surfaces[o.name]for o in roles['cage']],1 if a.center.x>=0 else -1,max_gap*.8,seed,'coil-cage')
        if pair:pairs.append((pair[0],pair[1],'coil-to-cage',1 if a.center.x>=0 else -1))
    if violent:
        for rock in roles['stone']:
            a=surfaces[rock.name]
            for side in (-1,1):
                pair=_pair(a,[surfaces[o.name]for o in roles['cage']+roles['coil']],side,max_gap*3.0,seed,'long-rupture',max_gap*.70)
                if pair:pairs.append((pair[0],pair[1],'long-stone-to-induction-rupture',side))
        # Longitudinal crawling discharges follow each actual cage rail. Both
        # ends remain measured source-surface anchors, rather than free wires.
        for rail in roles['cage']:
            surface=surfaces[rail.name];candidates=surface.candidates(160)
            if len(candidates)<3:continue
            candidates.sort(key=lambda r:r['point'][1]);stations=[candidates[int((len(candidates)-1)*q)]for q in(0,.5,1)]
            for a,b in zip(stations,stations[1:]):
                if (Vector(a['point'])-Vector(b['point'])).length>.35:pairs.append((a,b,'longitudinal-cage-crawl',1 if surface.center.x>=0 else -1))
    if len(pairs)<len(roles['stone'])*3:raise RuntimeError(('Too few actual air-gap anchor pairs',len(pairs)))
    arcs=[]
    for index,(a,b,kind,side) in enumerate(pairs):
        p,q=Vector(a['point']),Vector(b['point']);axis=(q-p).normalized();na=Vector(a['normal']);t=axis.cross(na)
        if t.length<.1:t=axis.cross(Vector((0,0,1)))
        if t.length<.1:t=axis.cross(Vector((1,0,0)))
        t.normalize();branch=surfaces[a['object']].anchor(p+t*(q-p).length*.32+na*.035)
        if branch is None:
            candidates=[r for r in surfaces[a['object']].candidates(64) if .012<(Vector(r['point'])-p).length<max(.08,(q-p).length*.8)]
            if candidates:branch=min(candidates,key=lambda r:(Vector(r['point'])-(p+t*(q-p).length*.32)).length)
        name=prefix+' | %03d'%index;co=_mesh_object(name+' core',core,col);fr=_mesh_object(name+' fringe',fringe,col)
        arcs.append({'index':index,'seed':seed+index*9173,'kind':kind,'side':side,'a':a,'b':b,'branch':branch,'core':co.name,'fringe':fr.name,'length':(q-p).length,'burst_frames':2+int(_unit(seed,index,'duration')*3),'phase_offset':int(_unit(seed,index,'phase')*samples),'core_width':(.009+.004*_unit(seed,index,'gauge'))*(3.2 if violent else 1),'fringe_width':(.024+.011*_unit(seed,index,'halo'))*(4.0 if violent else 1)})
    receipt={'schema':'fusion_electric_arcs_v1','version':VERSION,'family':family,'collection':col.name,'materials':[core.name,fringe.name],'objects':[n for a in arcs for n in (a['core'],a['fringe'])],'seed':seed,'samples':samples,'cycle_start':cycle_start,'cycle_end':cycle_end,'strength':strength,'arcs':arcs,'source_body_geometry_digest_before':before,'source_roles':{k:[o.name for o in v]for k,v in roles.items()},'policy':{'actual_surface_rays':'Both main endpoints and branching endpoint measured on actual imported source meshes','geometry':'Short irregular crossed flat emissive ribbon flashes; no physical wires, beveled tubes, closed loops or gas plume','timing':'Deterministic fast local burst/flicker only; no independent global sine. Native operation.factor/electrical draw controls whole-engine envelope separately.','normalization':'Default linear core radiance<=.24; final combined energy PNG peak must be decoded/normalized by capture owner for native0.5..1.5 gain.','occlusion':'Actual body must remain an opaque black depth occluder in energy-only lane. Ribbons naturally depth-occlude; no exhaustive all-phase triangle collision claim.'}}
    receipt['violent_discharge']=violent
    if violent:receipt['policy']['geometry']='Enlarged branching surface discharges, long rock-to-induction ruptures and longitudinal cage crawls; actual measured surface ends; no physical wires or closed loops.'
    set_electric_arcs_phase(receipt,0);after=geometry_digest(objects);assert before==after,'FX builder changed physical source mesh';receipt['source_body_geometry_digest_after']=after;return receipt

def set_electric_arcs_phase(receipt,phase):
    """Set normalized phase deterministically; phase1 exactly equals phase0.
    Call after scene.frame_set(), alongside capture owner's other energy FX.
    """
    tick=int(math.floor((float(phase)%1)*receipt['samples']+1e-8))%receipt['samples'];active=0
    for arc in receipt['arcs']:
        violent=receipt.get('violent_discharge',False);local=(tick+arc['phase_offset'])%receipt['samples'];burst=local//arc['burst_frames'];on=_unit(arc['seed'],burst,'on')>(.18 if violent else .40);flicker=.58+.42*_unit(arc['seed'],local,'fast-flicker');rng=random.Random((arc['seed']<<12)+burst);a=Vector(arc['a']['point']);b=Vector(arc['b']['point']);na=Vector(arc['a']['normal']);nb=Vector(arc['b']['normal']);axis=(b-a).normalized();u=axis.cross(na)
        if u.length<.1:u=axis.cross(Vector((0,0,1)))
        if u.length<.1:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u).normalized();length=arc['length'];points=[a]
        for j in range(1,7):
            t=j/7;lift=na*(1-t)+nb*t+Vector((0,0,.35))
            if lift.length<.1:lift=Vector((0,0,1))
            lift.normalize();envelope=math.sin(math.pi*t);points.append(a.lerp(b,t)+lift*length*(.22 if violent else .14)*envelope+u*rng.uniform(-.14,.14)*length*envelope+v*rng.uniform(-.08,.08)*length*envelope)
        points.append(b);paths=[points]
        if arc['branch'] is not None:
            root=points[3];end=Vector(arc['branch']['point']);branch=[root,root.lerp(end,.38)+u*length*rng.uniform(-.09,.09)+Vector((0,0,length*.04)),root.lerp(end,.72)+v*length*rng.uniform(-.07,.07),end];paths.append(branch)
        for key,width,color,gain in (('core',arc['core_width'],(.48,1,.24)if violent else(.78,1,.58),1),('fringe',arc['fringe_width'],(.018,1,.002),.38 if violent else .22)):
            obj=bpy.data.objects[arc[key]];vv,ff=_ribbons(paths,width,arc['core_width'] if key=='fringe' else 0);obj.data.clear_geometry();obj.data.from_pydata(vv,[],ff);obj.data.update();obj.hide_render=not on;obj.hide_viewport=not on;value=receipt['strength']*flicker*gain;obj.color=tuple(c*value for c in color)+(1,)
        active+=int(on)
    bpy.context.view_layer.update();return {'phase_sample':tick,'active_arc_count':active,'total_arcs':len(receipt['arcs'])}

def _pilot():
    import argparse
    import numpy as np
    p=argparse.ArgumentParser();p.add_argument('--glb',type=pathlib.Path,required=True);p.add_argument('--family',required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);sha=lambda x:hashlib.sha256(pathlib.Path(x).read_bytes()).hexdigest();input_sha=sha(a.glb)
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(a.glb.resolve()));scene=bpy.context.scene;body=[o for o in scene.objects if o.type=='MESH'];receipt=build_electric_arcs(body,family=a.family);states=[]
    for i in range(65):states.append(set_electric_arcs_phase(receipt,i/64))
    def state_digest():
        h=hashlib.sha256()
        for name in receipt['objects']:
            o=bpy.data.objects[name];h.update(str((o.hide_render,tuple(o.color))).encode());h.update(np.asarray([v.co[:] for v in o.data.vertices],dtype='<f4').tobytes())
        return h.hexdigest()
    set_electric_arcs_phase(receipt,0);first=state_digest();set_electric_arcs_phase(receipt,1);assert first==state_digest();assert geometry_digest(body)==receipt['source_body_geometry_digest_before'];assert sha(a.glb)==input_sha
    root=pathlib.Path(__file__).resolve().parents[4];sys.path.insert(0,str(root/'tools/fmpl'));from blender_camera_guard import install_canonical_camera,camera_record
    vv=[o.matrix_world@Vector(v) for o in body for v in o.bound_box];lo=Vector([min(p[i] for p in vv)for i in range(3)]);hi=Vector([max(p[i] for p in vv)for i in range(3)]);target=(lo+hi)/2;scale=max(hi.x-lo.x,(hi.y-lo.y+hi.z-lo.z)*.7072)*1.18
    cfg={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'states':{'working':[0]},'source_size':768,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':15,'ortho_scale':scale,'target':list(target)}};install_canonical_camera(scene,cfg,bpy)
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=2;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.dither_intensity=0;scene.view_settings.view_transform='Standard';scene.view_settings.look='None';world=bpy.data.worlds.new('Arc pilot dark world');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Strength'].default_value=0;scene.world=world
    matte=bpy.data.materials.new('PILOT actual-body black occluder');matte.use_nodes=True;nt=matte.node_tree;nt.nodes.clear();e=nt.nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(0,0,0,1);o=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(e.outputs[0],o.inputs['Surface'])
    for obj in body:
        obj.data.materials.clear();obj.data.materials.append(matte)
        for poly in obj.data.polygons:poly.material_index=0
    rendered=[]
    for i in (0,17,39):
        set_electric_arcs_phase(receipt,i/64);path=out/('arc-energy-frame-%02d.png'%i);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True);rendered.append({'file':str(path),'sha256':sha(path),'phase_sample':i,'actual_material_mode':'Arc-only normalized energy with physical imported body opaque-black depth occluder'})
    set_electric_arcs_phase(receipt,0);bpy.ops.wm.save_as_mainfile(filepath=str(out/'electric-arcs-pilot.blend'),compress=True);receipt.update({'status':'ACTUAL_BLENDER_PILOT_BUILT_CYCLIC_SOURCE_GUARD_PASS_RENDERS_REQUIRE_VIEW','input_glb':str(a.glb.resolve()),'input_glb_sha256':input_sha,'script_sha256':sha(__file__),'64_sample_states':states,'phase0_equals_phase1_digest':first,'body_geometry_unchanged':True,'camera':camera_record(scene),'renders':rendered});(out/'electric-arcs-pilot.json').write_text(json.dumps(receipt,indent=2)+'\n');print('ELECTRIC_ARCS_PILOT_PASS',len(receipt['arcs']),input_sha,flush=True)

if __name__=='__main__':_pilot()
