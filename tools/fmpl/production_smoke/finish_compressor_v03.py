"""Compressor finish: real pressure instrumentation, guarded drive, local PBR."""
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
from mechanical_routes import hollow_route,hollow_sleeve,compression_joint
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve earlier construction candidates')
    out.mkdir(parents=True);source=src/'compressor-v01.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    prefix='TP Compressor V03 | ';added=[];contacts=[]
    def mat(token):return next(m for m in bpy.data.materials if m.name=='TP Hydrogen Compressor V01 | '+token)
    mats={k:mat(k) for k in ('iron','brass','martian_red','gunmetal_dark')}
    def own(ob):
        added.append(ob.name)
        if not ob.data.uv_layers:uv_for_visible_surface(ob)
        return ob
    def box(label,loc,size,material='iron',role='PROCESS',bevel=.005):
        ob=own(p.block(bpy.data.collections[role],prefix+label,loc,size,mats[material],bevel));uv_for_visible_surface(ob);return ob
    def cyl(label,loc,r,depth,material='brass',axis='Z',vertices=32):
        return own(p.cyl(bpy.data.collections['PROCESS'],prefix+label,loc,r,depth,mats[material],axis,vertices))
    def drill(ob,label,center,radius,depth,axis):
        bpy.context.view_layer.objects.active=ob
        for modifier in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=center);cut=bpy.context.object
        if axis=='Y':cut.rotation_euler.x=math.pi/2
        if axis=='X':cut.rotation_euler.y=math.pi/2
        bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bm.to_mesh(ob.data);bm.free();ob.data.update()
    def pair(a,b,label):contacts.append(dict(a=a.name,b=b.name,label=label))
    # Cast drive guard: two grounded posts and a sparse inspectable grille.
    base=s.objects['TP Hydrogen Compressor V01 | equipment footing']
    posts=[]
    for x in (-.93,.93):
        foot=box('front crank guard sole '+str(x),(x,-1.51,.135),(.16,.22,.07),'iron','FRAME')
        post=box('front crank guard upright '+str(x),(x,-1.51,.58),(.035,.04,.83),'martian_red','FRAME')
        posts.append(post);pair(foot,base,'crank guard anchored to footing');pair(post,foot,'guard upright supported')
    rails=[]
    for z in (.50,.98):
        rail=box('front crank guard transverse rail '+str(z),(0,-1.51,z),(1.86,.04,.04),'gunmetal_dark','FRAME')
        rails.append(rail)
        for post in posts:pair(rail,post,'guard rail seated on uprights')
    for x in (-.6,-.3,0,.3,.6):
        bar=box('front crank guard wire '+str(x),(x,-1.51,.74),(.014,.018,.44),'iron','FRAME',.002)
        for rail in rails:pair(bar,rail,'guard wire retained in frame')
    # The gauge receives pressure through a real drilled tap. It is not a
    # gameplay output, lettering or a generic dashboard texture.
    header=s.objects['TP Hydrogen Compressor V01 | discharge independent pressure header']
    tap=own(hollow_route(bpy.data.collections['PIPING'],prefix+'discharge gauge pressure tap',[(.38,.75,1.34),(.38,.75,1.58),(.38,.62,1.58)],.025,.018,mats['brass']))
    drill(header,'Actual upper-only gauge pressure pickup',(.38,.75,1.415),.0185,.15,'Z')
    drill(tap,'Open gauge tap at shared header',(.38,.75,1.34),.058,.18,'X')
    case=cyl('pressure gauge cast case',(.38,.58,1.58),.12,.08)
    drill(case,'Recessed dial and lens seat',(.38,.54,1.58),.103,.08,'Y')
    drill(case,'Blind pressure entry at back',(.38,.62,1.58),.0185,.06,'Y')
    pair(tap,header,'pressure tap at drilled manifold');pair(tap,case,'gauge stem seated in case')
    def plain(name,color,rough,metal=0,transmission=0):
        m=bpy.data.materials.new(prefix+name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal;bs.inputs['Transmission Weight'].default_value=transmission
        return m
    mats['ceramic']=plain('gauge enamel',(.70,.68,.57),.40)
    mats['ink']=plain('gauge physical tick marks',(.015,.019,.014),.52)
    mats['lens']=plain('seated clear gauge lens',(.78,.88,.88),.065,transmission=.94)
    face=cyl('pressure gauge seated enamel dial',(.38,.575,1.58),.102,.010,'ceramic','Y')
    lens=cyl('pressure gauge recessed lens',(.38,.546,1.58),.102,.008,'lens','Y')
    bezel=own(p.torus(bpy.data.collections['PROCESS'],prefix+'pressure gauge lens retaining bezel',(.38,.54,1.58),.111,.009,mats['brass'],'Y'))
    pair(face,case,'dial plate on case recess');pair(bezel,case,'lens bezel seated on casting');pair(lens,bezel,'lens retained by bezel')
    for k in range(9):
        angle=math.radians(-140+k*35)
        tick=box('gauge radial tick '+str(k),(.38+.082*math.sin(angle),.568,1.58+.082*math.cos(angle)),(.006,.004,.016),'ink',bevel=.001)
        tick.rotation_euler.y=angle
    needle=box('gauge mechanical needle',(.397,.563,1.602),(.007,.005,.068),'ink',bevel=.001);needle.rotation_euler.y=.65
    cyl('gauge needle pivot',(.38,.562,1.58),.012,.009,'brass','Y')
    # Normally closed relief valve: model-space service hardware, not an
    # invented recipe reject or additional Factorio fluid connection.
    stem=own(hollow_sleeve(bpy.data.collections['PIPING'],prefix+'relief threaded pressure stem',(-.35,.75,1.40),(0,0,1),.12,.035,.019,mats['brass']))
    drill(header,'Actual upper-only relief pressure pickup',(-.35,.75,1.415),.020,.15,'Z')
    drill(stem,'Open relief stem/header intersection',(-.35,.75,1.34),.058,.18,'X')
    valve=own(hollow_sleeve(bpy.data.collections['PIPING'],prefix+'normally closed relief valve body',(-.35,.75,1.50),(0,0,1),.14,.055,.020,mats['iron']))
    cap=cyl('relief spring bonnet',(-.35,.75,1.60),.065,.075,'brass')
    pair(stem,header,'relief stem at pressure manifold');pair(valve,stem,'relief body threaded on stem');pair(cap,valve,'normally closed spring bonnet')
    for z in (1.57,1.59,1.61):own(p.torus(bpy.data.collections['PROCESS'],prefix+'relief bonnet retaining rib '+str(z),(-.35,.75,z),.067,.006,mats['iron']))
    vent=own(hollow_route(bpy.data.collections['PIPING'],prefix+'normally closed relief outlet stub',[(-.35,.75,1.50),(-.35,1.04,1.50),(-.35,1.04,1.40)],.022,.015,mats['iron']))
    drill(valve,'Relief outlet side bore',(-.35,.80,1.50),.016,.18,'Y');pair(vent,valve,'relief discharge stub on body')
    # Model-specific cylindrical maps: actual retaining-band levels, head
    # oil halos and a restrained warm discharge region at the rear/top.
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1);records=[];assignments=[]
    for index,x in enumerate((-.72,0,.72)):
        ob=s.objects['TP Hydrogen Compressor V01 | closed horizontal compressor cylinder '+str(x)]
        uv=ob.data.uv_layers.active
        for poly in ob.data.polygons:
            coords=[]
            for li in poly.loop_indices:
                pos=ob.matrix_world @ ob.data.vertices[ob.data.loops[li].vertex_index].co
                coords.append(((math.atan2(pos.z-.78,pos.x-x)/math.tau)%1,(pos.y+.15)/1.10))
            seam=max(p[0] for p in coords)-min(p[0] for p in coords)>.5
            for li,(a,b) in zip(poly.loop_indices,coords):uv.data[li].uv=(a+1 if seam and a<.5 else a,b)
        y=-.15+1.1*v;contacts_mask=sum(np.exp(-((y-level)/.025)**2) for level in (.05,.45,.9))
        heads=np.exp(-((y+.14)/.08)**2)+np.exp(-((y-.94)/.08)**2)
        heat=np.exp(-((u-.25)/.11)**2)*np.exp(-((y-.75)/.17)**2)
        brush=.5+.5*np.sin(v*math.tau*197+.15*np.sin(u*math.tau*5))
        grain=.5+.5*np.sin(u*math.tau*109+np.sin(v*math.tau*11+index))
        steel=np.stack((.265+.014*grain+.022*heat,.28+.015*grain+.010*heat,.276+.013*grain),axis=2)
        dirt=np.clip(.25*contacts_mask+.25*heads,0,.65)
        color=steel*(1-dirt[:,:,None])+np.array((.052,.046,.034))*dirt[:,:,None]
        rough=np.clip(.32+.07*brush+.14*contacts_mask+.12*heads,.2,.8);metal=np.clip(.89-.10*contacts_mask-.12*heads,.6,.9)
        plan='Axial Y/circumferential U machined compressor shell; dirt only at .05/.45/.9 retaining bands and actual head ends; warm discharge region at rear/top nozzle. No generic stripes or lettering.'
        material,maps=material_from_maps(prefix+'cylinder '+str(index+1)+' machined steel',out/'textures'/('cylinder-'+str(index+1)),color,rough,metal,.002*brush+.0005*grain,plan)
        ob.data.materials.clear();ob.data.materials.append(material)
        records.extend(maps);assignments.append(dict(object=ob.name,material=material.name,plan=plan))
    chrome=plain('polished piston rod',(.39,.43,.43),.19,.93)
    for ob in s.objects:
        if 'working piston rod' in ob.name:ob.data.materials.clear();ob.data.materials.append(chrome)
        if ob.type=='MESH' and any(token in ob.name for token in ('closed horizontal compressor cylinder','independent pressure header',' cell branch ')):
            for poly in ob.data.polygons:poly.use_smooth=True
            ob.data.set_sharp_from_angle(angle=math.radians(35))
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    prior=json.loads((src/'construction-receipt.json').read_text());prior['contacts'].extend(contacts)
    bpy.ops.file.pack_all();target=out/'compressor-v01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    prior.update(status='candidate_native; finishing and mechanical/export readback pending',revision='V03 guarded/instrumented/surfaced candidate',source_sha256=sha(source),native_sha256=sha(target),surface_assignments=assignments,
        textures=[dict(**row,sha256=sha(row['file'])) for row in records],added_objects=added,
        service_hardware='Manifold gauge and normally closed pressure relief; neither creates an additional native gameplay fluid port')
    (out/'construction-receipt.json').write_text(json.dumps(prior,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('COMPRESSOR_FINISH_SAVED',sha(target),flush=True)


if __name__=='__main__':main()
