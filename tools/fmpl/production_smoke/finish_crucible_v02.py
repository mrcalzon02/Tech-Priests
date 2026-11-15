"""Authored crucible pressure/casting surfaces, mounted covers and state clocks."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from authored_pbr import material_from_maps
from mechanical_routes import mesh_object
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve surface candidates')
    out.mkdir(parents=True);source=src/'crucible-v01.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
    prefix='TP Metallization Crucible V01 | ';new='TP Crucible V02 | '
    def ob(label):return s.objects[prefix+label]
    def mat(label):return bpy.data.materials[prefix+label]
    receipt=json.loads((src/'construction-receipt.json').read_text());added=[]
    def own(obj):
        added.append(obj.name)
        if not obj.data.uv_layers:uv_for_visible_surface(obj)
        return obj
    def box(label,loc,size,material='iron',bevel=.006):
        obj=own(p.block(bpy.data.collections['PROCESS'],new+label,loc,size,mat(material),bevel));uv_for_visible_surface(obj);return obj
    def joint(a,b,label):receipt['contacts'].append(dict(a=a.name,b=b.name,label=label))
    # Two curved protection covers occupy the clear flank sectors between the
    # four haunches. Real brackets bridge the pressure collars; the front
    # witnesses, rear thermal bus and low process nozzles remain accessible.
    covers=[]
    for side,center_angle in enumerate((0,math.pi)):
        angles=[center_angle+math.radians(-25+50*i/40) for i in range(41)];verts=[]
        for r,z in ((1.18,1.56),(1.205,1.56),(1.205,1.99),(1.18,1.99)):
            verts.extend((r*math.cos(a),r*math.sin(a),z) for a in angles)
        faces=[];n=len(angles)
        for row in range(4):
            nxt=(row+1)%4
            for i in range(n-1):faces.append((row*n+i,row*n+i+1,nxt*n+i+1,nxt*n+i))
        faces.extend(((0,n,2*n,3*n),(n-1,4*n-1,3*n-1,2*n-1)))
        panel=own(mesh_object(bpy.data.collections['PROCESS'],new+'removable curved side shield '+str(side),verts,faces,mat('gunmetal_dark')));covers.append(panel)
        for offset in (-18,18):
            a=center_angle+math.radians(offset);radial=Vector((math.cos(a),math.sin(a),0))
            for z,band_index in ((1.54,1),(2.04,2)):
                bracket=box('cover collar standoff '+str((side,offset,z)),radial*1.12+Vector((0,0,z)),(.18,.065,.16));bracket.rotation_euler.z=a
                joint(bracket,ob('seated pressure retaining band '+str(band_index)),'cover bracket grounded on pressure collar')
                joint(panel,bracket,'curved cover supported by actual collar standoff')
                head=own(p.cyl(bpy.data.collections['PROCESS'],new+'cover retaining head '+str((side,offset,z)),radial*1.23+Vector((0,0,1.59 if z<2 else 1.96)),.025,.08,mat('brass'),vertices=6))
                head.rotation_euler=radial.to_track_quat('Z','Y').to_euler();joint(head,panel,'cover fastener enters shield and bracket')
        # Arc length across U, actual vertical height along V.
        uv=panel.data.uv_layers.active
        for face in panel.data.polygons:
            for li in face.loop_indices:
                v=panel.data.vertices[panel.data.loops[li].vertex_index].co
                angle=math.atan2(v.y,v.x)-center_angle;angle=(angle+math.pi)%math.tau-math.pi
                uv.data[li].uv=((math.degrees(angle)+25)/50,(v.z-1.56)/.43)
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1);maps=[];assignments=[]
    def apply(label,objects,color,rough,metal,height,plan):
        material,records=material_from_maps(new+label,out/'textures'/label,color,rough,metal,height,plan)
        maps.extend(records)
        for obj in objects:
            obj.data.materials.clear();obj.data.materials.append(material)
            assignments.append(dict(object=obj.name,material=material.name,plan=plan))
        return material
    def cylindrical(obj,z0,height):
        uv=obj.data.uv_layers.active
        for face in obj.data.polygons:
            coords=[]
            for li in face.loop_indices:
                w=obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co
                coords.append(((math.atan2(w.y,w.x)/math.tau)%1,(w.z-z0)/height))
            seam=max(c[0] for c in coords)-min(c[0] for c in coords)>.5
            for li,(a,b) in zip(face.loop_indices,coords):uv.data[li].uv=(a+1 if seam and a<.5 else a,b)
    def periodic(a,b):return np.minimum(abs(a-b),1-abs(a-b))
    shell=ob('thick wall central pressure vessel');cylindrical(shell,.45,1.80)
    z=.45+1.8*v;seats=sum(np.exp(-((z-level)/.045)**2) for level in (.60,1.45,2.12))
    foot=np.exp(-((z-.45)/.15)**2)
    hatch=np.exp(-((np.sqrt((periodic(u,.75)*math.tau*1.04)**2+(z-1.08)**2)-.345)/.055)**2)
    nozzles=np.exp(-((np.sqrt((periodic(u,.5)*math.tau*1.04)**2+(z-1.05)**2)-.14)/.035)**2)+np.exp(-((np.sqrt((periodic(u,0)*math.tau*1.04)**2+(z-.90)**2)-.17)/.035)**2)
    thermal=sum(np.exp(-((z-level)/.035)**2) for level in (1.72,1.93))
    grain=.5+.5*np.sin(math.tau*(u*173+.06*np.sin(v*math.tau*11)))
    brushed=.5+.5*np.sin(v*math.tau*193+.16*np.sin(u*math.tau*7))
    grime=np.clip(.30*seats+.22*foot+.22*hatch+.18*nozzles,0,.65)
    base=np.stack((.205+.010*grain+.020*thermal,.222+.011*grain+.009*thermal,.226+.011*grain-.005*thermal),axis=2)
    color=base*(1-grime[:,:,None])+np.array((.048,.043,.035))*grime[:,:,None]
    apply('pressure-shell',[shell],color,np.clip(.40+.07*brushed+.16*grime,.3,.8),np.clip(.87-.16*grime,.6,.9),.0014*brushed+.0005*grain,
        'Circumferential U / actual vessel Z. Dirt follows three pressure-band seats, lower plinth, true hatch collar and two drilled nozzles. Restrained thermal discoloration follows the two seated contact bands; no uniform decorative striping.')
    roof=ob('closed graded pressure crown');cylindrical(roof,2.25,.34)
    turning=.5+.5*np.sin(v*math.tau*153);variation=.5+.5*np.sin(u*math.tau*31+np.sin(v*math.tau*4))
    rim=np.exp(-(v/.10)**2)+np.exp(-((v-1)/.12)**2)
    steel=np.stack((.255+.009*variation,.267+.009*variation,.268+.008*variation),axis=2)*(1-.22*rim[:,:,None])
    apply('turned-pressure-crown',[roof],steel,np.clip(.38+.075*turning+.13*rim,.3,.8),.88-.10*rim,.0012*turning,
        'Azimuth U / actual graded crown Z. Concentric lathe marks follow pressure-crown rings; restrained dirt only at the lower seated rim and service-hatch collar, replacing broad generic donor clouds.')
    castings=[]
    for k in range(4):
        obj=ob('tapered pressure haunch '+str(k));castings.append(obj);a=math.pi/4+k*math.pi/2
        radial=Vector((math.cos(a),math.sin(a),0));tangent=Vector((-math.sin(a),math.cos(a),0));uv=obj.data.uv_layers.active
        for face in obj.data.polygons:
            face.use_smooth=False
            for li in face.loop_indices:
                w=obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co;t=(w.z-.30)/1.84
                width=.46+(.25-.46)*t;center=2.15+(1.10-2.15)*t
                across=(w.dot(radial)-center)/width if abs(face.normal.dot(tangent))>.5 else w.dot(tangent)/.24
                uv.data[li].uv=(across+.5,t)
    edge=np.exp(-(np.minimum(u,1-u)/.035)**2);dirt=np.exp(-(v/.10)**2);topseat=np.exp(-((v-1)/.055)**2)
    casting=.5+.5*np.sin(u*math.tau*103+np.sin(v*math.tau*37))
    paint=np.stack((.30+.010*casting,.058+.004*casting,.042+.004*casting),axis=2)
    wear=np.clip(.45*edge+.24*dirt+.18*topseat,0,.8)
    paint=paint*(1-wear[:,:,None])+np.array((.105,.093,.078))*wear[:,:,None]
    apply('red-haunch-castings',castings,paint,np.clip(.54+.10*casting+.08*dirt,.4,.85),.32+.28*edge,.0015*casting,
        'Four instances of the same tapered casting. Face UV follows the actual inclined haunch width and height; exposed longitudinal edges wear through red enamel, dirt sits at the grounded shoe and upper collar seat. Fine cast grain, no random black scratch stamp.')
    covergrain=.5+.5*np.sin(u*math.tau*137+.10*np.sin(v*math.tau*6));ends=np.exp(-(v/.06)**2)+np.exp(-((v-1)/.06)**2)
    fasteners=sum(np.exp(-(((u-x)/.055)**2+((v-y)/.09)**2)) for x in (.14,.86) for y in (.07,.93))
    shade=.18*ends+.20*fasteners
    color=np.stack((.095+.006*covergrain,.108+.007*covergrain,.110+.007*covergrain),axis=2)*(1-shade[:,:,None])
    apply('rolled-side-shields',covers,color,.47+.08*covergrain+.12*shade,.82-.15*shade,.0011*covergrain,
        'Separate detachable flank shields. Rolled grain follows arc U; dirt follows the real top/bottom lips and four mounting-head locations. Covers stay between haunches with front/rear maintenance openings.')
    # An eight-second coherent cabinet display accompanies the protected fan.
    # The actual console bars remain inside their existing CRT aperture; no
    # floating new ornament or animated pressure-vessel scaling is introduced.
    bars=[obj for obj in s.objects if 'console live green bar' in obj.name]
    if not bars:raise RuntimeError('Expected actual registered console status bars')
    bases={obj:obj.scale.copy() for obj in bars}
    for obj in bars:
        obj.animation_data_clear()
    for frame in range(0,194):
        theta=math.tau*(max(frame,1)-1)/192
        for k,obj in enumerate(bars):
            obj.scale=bases[obj].copy();obj.scale.z*=.35 if frame==0 else .72+.20*math.sin(theta+k*.67)
            obj.keyframe_insert(data_path='scale',frame=frame)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    for obj in (shell,roof,*covers):obj.data.set_sharp_from_angle(angle=math.radians(35))
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    bpy.ops.file.pack_all();s.frame_set(25);target=out/'crucible-v02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt.update(status='finished surface/state candidate; independent audit and review pending',revision='V02 supported flank shields and authored pressure/casting surfaces',
        previous_source_sha256=sha(source),source_sha256=sha(target),surface_assignments=assignments,textures=[dict(**r,sha256=sha(r['file'])) for r in maps],
        added_objects=added,console_bars=[obj.name for obj in bars],state_scope='Idle reduced CRT bars/stopped fan; working closed vessel with fan and restrained coherent eight-second process readout',
        pending=['Actual source/export mechanical and surface readback','Machine-specific audio','Four-angle idle/working captures','Native 5x5 prototype and pipe fitting'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('CRUCIBLE_FINISH_SAVED',sha(target),len(maps),'maps',len(bars),'CRT bars',flush=True)


if __name__=='__main__':main()
