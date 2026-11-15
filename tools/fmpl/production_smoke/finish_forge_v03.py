"""Forge-specific enamel, flow wear, ground tooling and mounted hydraulic pack."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from authored_pbr import material_from_maps
from blender_build import uv_for_visible_surface
from mechanical_routes import hollow_route,hollow_sleeve
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve forge finish studies')
    out.mkdir(parents=True);source=src/'forge-v02.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1)
    prefix='TP Pelletization Forge V01 | ';new='TP Forge V03 | ';col=bpy.data.collections['PROCESS']
    receipt=json.loads((src/'construction-receipt.json').read_text());added=[]
    def ob(label):return s.objects[prefix+label]
    def mat(label):return bpy.data.materials[prefix+label]
    def own(obj):
        added.append(obj.name);uv_for_visible_surface(obj);return obj
    def box(label,loc,size,key='iron',bevel=.006):return own(p.block(col,new+label,loc,size,mat(key),bevel))
    def cyl(label,loc,r,depth,key='machine_steel',axis='Z',vertices=40):return own(p.cyl(col,new+label,loc,r,depth,mat(key),axis,vertices))
    def sleeve(label,center,axis,length,outer,inner,key='iron'):return own(hollow_sleeve(col,new+label,center,axis,length,outer,inner,mat(key),40))
    def joint(a,b,label):receipt['contacts'].append(dict(a=a.name,b=b.name,label=label))
    def drill(obj,center,r,depth,axis='X'):
        cutter=cyl('temporary service drill',center,r,depth,axis=axis);bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Actual hydraulic service opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name);added.remove(cutter.name);bpy.data.objects.remove(cutter,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(obj.data);bm.free()
    base=ob('full equipment footing')
    tank=box('closed hydraulic reservoir',(.94,.84,.36),(.56,.70,.44),'gunmetal_dark')
    cavity=box('temporary reservoir cavity',(.94,.84,.36),(.48,.62,.36),bevel=0)
    bpy.context.view_layer.objects.active=tank
    for mod in list(tank.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=tank.modifiers.new('Closed reservoir wall thickness','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cavity
    bpy.ops.object.modifier_apply(modifier=mod.name);added.remove(cavity.name);bpy.data.objects.remove(cavity,do_unlink=True)
    feet=[]
    for x in (.73,1.15):
        foot=box('powerpack grounded skid '+str(x),(x,.84,.14),(.10,.70,.04));feet.append(foot)
        joint(foot,base,'hydraulic skid on footing');joint(tank,foot,'reservoir supported by skid')
    lid=box('removable reservoir lid',(.94,.84,.60),(.60,.74,.04),'iron');joint(lid,tank,'service lid seated on reservoir')
    pump=cyl('hydraulic pump foot flange',(.94,.84,.65),.165,.06,'iron');joint(pump,lid,'pump mounting flange on reservoir lid')
    motor=cyl('hydraulic powerpack motor',(.94,.84,.81),.135,.26,'gunmetal_dark');joint(motor,pump,'pump motor seated on flange')
    for z in (.72,.77,.82,.87):
        ring=sleeve('powerpack cooling ring '+str(z),(.94,.84,z),(0,0,1),.018,.15,.134,'iron');joint(ring,motor,'motor cooling ring retained on housing')
    for x in (.70,1.18):
        for y in (.51,1.17):
            bolt=cyl('lid retaining head '+str((x,y)),(x,y,.634),.018,.03,'brass',vertices=6);joint(bolt,lid,'lid fastener seats on actual flange')
    # Separate supply/return routes pass behind the frame. No gameplay fluid
    # mouth is invented: these belong to the closed local hydraulic system.
    routes=[]
    for label,z,x,y in [('pressure supply',2.33,1.20,.40),('pressure return',2.12,1.08,.48)]:
        start=(x-.06,.57,.62)
        drill(lid,(x-.06,.57,.57),.027,.20,axis='Z');drill(tank,(x-.06,.57,.57),.027,.20,axis='Z')
        port=sleeve(label+' reservoir port',start,(0,0,1),.10,.050,.027,'brass');joint(port,lid,'hydraulic reservoir port on service lid')
        points=[start,(x-.06,.57,.74),(x,y,.74),(x,y,z),(.34,y,z),(.36,-.10,z),(.18,-.10,z)]
        route=own(hollow_route(col,new+label+' hose',points,.025,.018,mat('gunmetal_dark')));routes.append(route)
        joint(route,port,'hose seated in reservoir coupling')
        drill(ob('closed hydraulic press cylinder'),(.18,-.10,z),.028,.29)
        coupling=sleeve(label+' actuator coupling',(.18,-.10,z),(1,0,0),.10,.050,.028,'brass')
        joint(coupling,ob('closed hydraulic press cylinder'),'actuator coupling seated in drilled cylinder wall');joint(route,coupling,'hose terminates in actuator coupling')
        clamp=sleeve(label+' riser clamp',(x,y,1.43),(0,0,1),.065,.047,.026,'iron')
        joint(clamp,route,'riser pipe supported by external clamp')
        a=Vector((.89,.07,1.43));center=Vector((x,y,1.43));b=center+(a-center).normalized()*.050;brace=box(label+' frame standoff',(a+b)/2,(.045,.045,(b-a).length))
        brace.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        joint(brace,ob('red press column flange '+str((.89,.07))),'riser standoff grounded on rear press flange');joint(brace,clamp,'external clamp carried by frame standoff')
    retainer=sleeve('bolted die retaining flange',(0,-.10,.5875),(0,0,1),.035,.25,.145,'machine_steel')
    joint(retainer,ob('die supporting transverse bed'),'die retaining flange seated on bed')
    joint(retainer,ob('open tapered pellet die'),'close-fitting flange retains die body')
    for k in range(4):joint(ob('die flange stud '+str(k)),retainer,'die retaining head seats through actual flange')
    # Surface placement belongs to each real component rather than a shared
    # global grunge stamp. Texture geometry is held fixed throughout this step.
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1);maps=[];assignments=[]
    def apply(label,objects,color,rough,metal,height,plan):
        material,records=material_from_maps(new+label,out/'textures'/label,color,rough,metal,height,plan);maps.extend(records)
        for obj in objects:
            obj.data.materials.clear();obj.data.materials.append(material);assignments.append(dict(object=obj.name,material=material.name,plan=plan))
        return material
    def planar(obj,long_axis=2):
        uv=obj.data.uv_layers.active;vs=obj.data.vertices
        low=[min(p.co[i] for p in vs) for i in range(3)];span=[max(p.co[i] for p in vs)-low[i] for i in range(3)]
        for face in obj.data.polygons:
            dominant=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=dominant]
            if long_axis in axes:axes=[next(i for i in axes if i!=long_axis),long_axis]
            for li in face.loop_indices:
                pt=vs[obj.data.loops[li].vertex_index].co;uv.data[li].uv=tuple((pt[i]-low[i])/max(span[i],1e-6) for i in axes)
    frame=[o for o in s.objects if o.type=='MESH' and any(t in o.name for t in ('red press column','rigid overhead press crossbeam','hopper supported upright'))]
    for obj in frame:planar(obj,0 if 'crossbeam' in obj.name else 2)
    grain=.5+.5*np.sin(u*math.tau*137+.33*np.sin(v*math.tau*69))
    edge=np.exp(-(np.minimum(u,1-u)/.025)**2);seat=np.exp(-(np.minimum(v,1-v)/.04)**2)
    wear=np.clip(.55*edge+.20*seat,0,.7)
    color=np.stack((.26+.006*grain,.042+.003*grain,.031+.002*grain),axis=2)
    color=color*(1-wear[:,:,None])+np.array((.13,.12,.105))*wear[:,:,None]
    apply('press-frame-enamel',frame,color,.51+.08*grain+.10*seat,.30+.30*edge,.001*grain,
          'Per-face UV along the actual I-section and crossbeam length. Red enamel has fine cast/rolled grain, narrow exposed edge wear and grime at actual member ends; no repeated generic cloudy patches.')
    hopper=ob('open raw pellet hopper');uv=hopper.data.uv_layers.active
    for face in hopper.data.polygons:
        inner=face.index%4==1
        for li in face.loop_indices:
            w=hopper.matrix_world@hopper.data.vertices[hopper.data.loops[li].vertex_index].co;t=(w.z-1.19)/.41
            hx=(.09+.375*t) if inner else (.105+.395*t);hy=(.09+.235*t) if inner else (.105+.255*t)
            across=(w.y-.8)/hy if abs(face.normal.x)>abs(face.normal.y) else (w.x-.135*(1-t))/hx
            uv.data[li].uv=(across*.5+.5,t)
    grain=.5+.5*np.sin(u*math.tau*201+.08*np.sin(v*math.tau*17));corners=np.exp(-(np.minimum(u,1-u)/.055)**2)
    throat=np.exp(-(v/.17)**2);flow=np.exp(-((u-.5)/.23)**2)
    dirt=.23*corners+.14*throat;rub=flow*(.2+.8*(1-v))
    color=np.stack((.275+.006*grain,.291+.006*grain,.295+.006*grain),axis=2)*(1-dirt[:,:,None])+.025*rub[:,:,None]
    apply('hopper-flow-steel',[hopper],color,.40+.09*grain+.15*dirt-.12*rub,.86-.10*dirt,.0006*grain,
          'Separate tapered wall UVs run from the real upper lip to offset throat. Grain and polished feed tracks follow descent; dirt sits in actual corner folds and throat, with no opaque cap over the opening.')
    tooling=[o for o in s.objects if o.type=='MESH' and any(t in o.name for t in ('on-axis press punch','punch mounting shank','fixed press guide rod','telescoping press piston rod'))]
    for obj in tooling:
        uv=obj.data.uv_layers.active;zs=[p.co.z for p in obj.data.vertices];z0=min(zs);depth=max(zs)-z0
        for face in obj.data.polygons:
            coords=[]
            for li in face.loop_indices:
                q=obj.data.vertices[obj.data.loops[li].vertex_index].co;coords.append(((math.atan2(q.y,q.x)/math.tau)%1,(q.z-z0)/depth))
            seam=max(a for a,b in coords)-min(a for a,b in coords)>.5
            for li,(a,b) in zip(face.loop_indices,coords):uv.data[li].uv=(a+1 if seam and a<.5 else a,b)
        obj.data.set_sharp_from_angle(angle=math.radians(35))
    grind=.5+.5*np.sin(v*math.tau*233);oil=np.exp(-(v/.07)**2)+np.exp(-((v-1)/.07)**2)
    color=np.stack((.38+.006*grind,.40+.006*grind,.405+.006*grind),axis=2)*(1-.12*oil[:,:,None])
    tooling_material=apply('ground-press-tooling',tooling,color,.23+.045*grind+.09*oil,.94-.08*oil,.00035*grind,
          'Cylindrical U / actual axial V. Fine circumferential grinding on ram and guide surfaces, restrained oil at seated axial ends. Bore and stroke dimensions are unchanged.')
    # The bed and crosshead have different real contact patterns and maps.
    for label,obj,sx,sy,pads in [
        ('cast-die-bed',ob('die supporting transverse bed'),1.60,.58,(-.30,.30)),
        ('machined-crosshead',ob('guided moving crosshead'),.76,.24,(-.30,.30))]:
        planar(obj);x=(u-.5)*sx;y=(v-.5)*sy
        seat=sum(np.exp(-((np.sqrt((x-p)**2+y*y)-.075)/.025)**2) for p in pads)
        die_seat=np.exp(-((np.sqrt(x*x+y*y)-.25)/.035)**2) if 'bed' in label else 0
        grain=.5+.5*np.sin(u*math.tau*183+.12*np.sin(v*math.tau*47))
        contact=.22*seat+.16*die_seat
        base_color=np.array((.125,.143,.15)) if 'bed' in label else np.array((.31,.33,.34))
        color=np.broadcast_to(base_color,(size,size,3)).copy()+.005*grain[:,:,None]-contact[:,:,None]*.07
        apply(label,[obj],color,.46+.07*grain+.12*contact,.85-.10*contact,.0006*grain,
              'Planar faces use actual component dimensions. Contact dirt follows the two real guide seats'+(' and actual die retaining flange.' if 'bed' in label else '; restrained longitudinal ground grain follows the bored crosshead.'))
    die_parts=[ob('open tapered pellet die'),retainer]
    r=np.sqrt(((u-.5)*.54)**2+((v-.5)*.54)**2)
    turning=.5+.5*np.sin(r*math.tau*650);oil=np.exp(-((r-.15)/.014)**2)+np.exp(-((r-.25)/.012)**2)
    color=np.stack((.32+.006*turning,.34+.006*turning,.35+.006*turning),axis=2)*(1-.08*oil[:,:,None])
    face_material=apply('turned-die-faces',die_parts,color,.29+.055*turning+.08*oil,.92-.06*oil,.0003*turning,
          'Actual top/bottom annuli map in XY at .54-tile width; concentric tooling marks follow the true die axis. Cylinder/conical bores separately use circumferential/axial ground-tool UVs and material.')
    for obj in die_parts:
        obj.data.materials.clear();obj.data.materials.append(tooling_material);obj.data.materials.append(face_material)
        uv=obj.data.uv_layers.active
        for face in obj.data.polygons:
            flat=abs(face.normal.z)>.5;face.material_index=1 if flat else 0
            for li in face.loop_indices:
                w=obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv.data[li].uv=((w.x/.54+.5,(w.y+.10)/.54+.5) if flat else ((math.atan2(w.y+.10,w.x)/math.tau)%1,(w.z-.54)/.12))
    chutes=[ob('inclined product chute floor'),ob('open die feed shoe floor'),ob('open front item pickup tray')]
    for obj in chutes:planar(obj,1 if 'tray' in obj.name else 2)
    grain=.5+.5*np.sin(u*math.tau*229+.10*np.sin(v*math.tau*7));track=np.exp(-((u-.5)/.22)**2)
    folded=np.exp(-(np.minimum(u,1-u)/.06)**2)
    color=np.stack((.25+.005*grain,.27+.005*grain,.28+.005*grain),axis=2)+.04*track[:,:,None]-.04*folded[:,:,None]
    apply('pellet-contact-chutes',chutes,color,.44+.06*grain-.14*track+.10*folded,.88-.12*folded,.00045*grain,
          'U spans actual chute width; V follows stock travel. Central polished contact lane and dirt at side folds, separately mapped to the small feed shoe, discharge ramp and accessible tray.')
    planar(tank);planar(lid)
    seam=np.exp(-(np.minimum(v,1-v)/.045)**2);edge=np.exp(-(np.minimum(u,1-u)/.035)**2)
    grain=.5+.5*np.sin(u*math.tau*91+np.sin(v*math.tau*27));oil=.25*seam+.14*edge
    color=np.stack((.071+.003*grain,.084+.003*grain,.089+.003*grain),axis=2)*(1-oil[:,:,None])
    apply('hydraulic-reservoir',[tank,lid],color,.48+.07*grain+.13*oil,.74-.18*oil,.0007*grain,
          'Flat cabinet faces follow each physical edge. Dark painted reservoir has restrained oil around lid seams and softened exposed edges; motor and brass fittings retain their distinct library metals.')
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    bpy.ops.file.pack_all();s.frame_set(25);target=out/'forge-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt.update(status='forge surface/service candidate; independent export, mechanics and native work pending',revision='V03 model-specific finish and closed hydraulic powerpack',
        previous_source_sha256=sha(source),source_sha256=sha(target),surface_assignments=assignments,textures=[dict(**r,sha256=sha(r['file'])) for r in maps],added_objects=added,
        pending=['Independent source/export material-path and service clearance checks','Machine-specific sound','Four-angle idle/working captures','Native age/HP/quality-preserving item processing'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('FORGE_FINISH_SAVED',sha(target),len(maps),'maps',flush=True)


if __name__=='__main__':main()
