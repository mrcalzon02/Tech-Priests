"""Anatomy-specific packed PBR maps for the cell wraps and rectifier cover.

Direct authored texture functions, with matched UV frames and real fastening
geometry. Does not tint a shared master or change the process/port positions.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Keep all earlier construction evidence')
    out.mkdir(parents=True);texdir=out/'textures';texdir.mkdir()
    source=src/'electrolyzer-v01.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1);maps=[];assignments=[]
    def image(slug,channel,rgb,noncolor=False):
        im=bpy.data.images.new('TP Electrolyzer V04 | '+slug+' '+channel,width=size,height=size,alpha=True)
        if noncolor:im.colorspace_settings.name='Non-Color'
        rgba=np.ones((size,size,4),dtype=np.float32);rgba[:,:,:3]=np.clip(rgb,0,1)
        im.pixels.foreach_set(rgba.reshape(-1));im.filepath_raw=str(texdir/(slug+'-'+channel+'.png'));im.file_format='PNG'
        im.save();im.pack();maps.append(dict(file=str(Path(im.filepath_raw).relative_to(out)),sha256=sha(im.filepath_raw),color_space=im.colorspace_settings.name))
        return im
    def surface(slug,color,rough,metal,height,plan):
        gy,gx=np.gradient(height)
        normal=np.stack((-gx*16,-gy*16,np.ones_like(gx)),axis=2)
        normal/=np.linalg.norm(normal,axis=2,keepdims=True)
        albedo=image(slug,'albedo',color)
        orm=image(slug,'orm',np.stack((np.ones_like(rough),rough,metal),axis=2),True)
        tangent=image(slug,'normal',normal*.5+.5,True)
        mat=bpy.data.materials.new('TP Electrolyzer V04 | '+slug);mat.use_nodes=True
        mat['surface_plan']=plan;nd=mat.node_tree.nodes;lk=mat.node_tree.links;bs=nd.get('Principled BSDF')
        color_tex=nd.new('ShaderNodeTexImage');color_tex.image=albedo;lk.new(color_tex.outputs['Color'],bs.inputs['Base Color'])
        orm_tex=nd.new('ShaderNodeTexImage');orm_tex.image=orm
        separate=nd.new('ShaderNodeSeparateColor');lk.new(orm_tex.outputs['Color'],separate.inputs[0])
        lk.new(separate.outputs['Green'],bs.inputs['Roughness']);lk.new(separate.outputs['Blue'],bs.inputs['Metallic'])
        ntex=nd.new('ShaderNodeTexImage');ntex.image=tangent;nmap=nd.new('ShaderNodeNormalMap')
        nmap.inputs['Strength'].default_value=.38;lk.new(ntex.outputs['Color'],nmap.inputs['Color']);lk.new(nmap.outputs['Normal'],bs.inputs['Normal'])
        return mat
    for i,x in enumerate((-.62,.62),1):
        ob=bpy.data.objects['TP_ELECTROLYZER_V01 | electrode chamber shell '+str(i)]
        layer=ob.data.uv_layers.active
        # Circumferential U, vertical V. Match the actual vessel height and
        # place the front observation frame at U=.25, without planar seams.
        for poly in ob.data.polygons:
            coords=[]
            for index in poly.loop_indices:
                pos=ob.matrix_world @ ob.data.vertices[ob.data.loops[index].vertex_index].co
                coords.append(((math.atan2(-pos.y,-(pos.x-x))/math.tau)%1,(pos.z-.5)/1.36))
            seam=max(c[0] for c in coords)-min(c[0] for c in coords)>.5
            for index,(a,b) in zip(poly.loop_indices,coords):layer.data[index].uv=(a+1 if seam and a<.5 else a,b)
        z=.5+v*1.36
        bands=sum(np.exp(-((z-h)/.028)**2) for h in (.55,1.04,1.81))
        front=np.exp(-((u-.25)/.075)**2)
        drip=front*np.exp(-((z-.78)/.23)**2)*(0.6+0.4*np.sin(u*220+i)**2)
        brush=.5+.5*np.sin(v*math.tau*231+.14*np.sin(u*math.tau*3))
        grain=.5+.5*np.sin(u*math.tau*113+np.sin(v*math.tau*7+i))
        base=np.stack((.265+.018*grain,.285+.020*grain,.278+.017*grain),axis=2)
        dirt=np.clip(.30*bands+.21*drip,0,.65)
        color=base*(1-dirt[:,:,None])+np.array((.075,.065,.045))*dirt[:,:,None]
        rough=np.clip(.34+.07*brush+.12*bands+.10*drip,.2,.75)
        metal=np.clip(.88-.18*drip-.10*bands,.5,.9)
        height=.0025*brush+.0007*grain
        plan='Closed steel cell wrap: circumferential machining, seated-band contact dirt at actual .55/1.04/1.81 heights, restrained condensate beneath actual front window. Cylindrical UVs; no lettering.'
        mat=surface('cell-'+str(i)+'-machined-wrap',color,rough,metal,height,plan)
        ob.data.materials.clear();ob.data.materials.append(mat)
        assignments.append(dict(object=ob.name,material=mat.name,uv='circumference/height',plan=plan))
    cover=bpy.data.objects['TP_ELECTROLYZER_V01 | rectifier service cover']
    for poly in cover.data.polygons:
        for index in poly.loop_indices:
            pos=cover.matrix_world @ cover.data.vertices[cover.data.loops[index].vertex_index].co
            cover.data.uv_layers.active.data[index].uv=((pos.x+.78)/1.56,(pos.z-.57)/1.02)
    border=np.minimum.reduce((u,1-u,v,1-v));edge=np.exp(-border/.018)
    fasteners=np.zeros_like(u);brass=next(m for m in bpy.data.materials if m.name.startswith('TP Electrolyzer V01 | brass'))
    new_contacts=[]
    for x in (-.68,.68):
        for z in (.68,1.08,1.48):
            uu=(x+.78)/1.56;vv=(z-.57)/1.02
            fasteners+=np.exp(-(((u-uu)*1.56)**2+((v-vv)*1.02)**2)/(.044**2))
            bolt=p.cyl(bpy.data.collections['PROCESS'],'TP_ELECTROLYZER_V04 | cover retained hex '+str((x,z)),(x,.947,z),.022,.026,brass,'Y',6)
            new_contacts.append(dict(a=bolt.name,b=cover.name,label='rectifier cover fastening'))
    texture=.5+.5*np.sin(u*math.tau*89)*np.sin(v*math.tau*107)
    paint=np.stack((.205+.014*texture,.040+.004*texture,.027+.003*texture),axis=2)
    wear=np.clip(.67*edge+.18*fasteners,0,.75)
    color=paint*(1-wear[:,:,None])+np.array((.19,.18,.15))*wear[:,:,None]
    rough=np.clip(.54+.055*texture-.18*edge+.06*fasteners,.2,.8)
    metal=np.clip(.16+.62*wear,.1,.85)
    mat=surface('rectifier-retained-oxide-cover',color,rough,metal,.0018*texture,
        'Oxide red rectifier service cover with edge rub and deposits only at six actual retaining heads. Cover-local X/Z UV, physical pattern scale; no decals.')
    cover.data.materials.clear();cover.data.materials.append(mat)
    assignments.append(dict(object=cover.name,material=mat.name,uv='cover X/Z',plan=mat['surface_plan']))
    for name in ('port_manifest.json','part_provenance.json'):
        shutil.copy2(src/name,out/name)
    prior=json.loads((src/'construction-receipt.json').read_text())
    bpy.ops.file.pack_all();target=out/'electrolyzer-v01.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt=dict(status='candidate_native; finish visual review pending',revision='V04 model-specific finish',
        source_sha256=sha(source),native_sha256=sha(target),surface_assignments=assignments,maps=maps,
        contacts=prior['contacts']+new_contacts,
        pending=['independent contacts/route/export regression','actual closeup/front/rear/clay review','motion capture','native prototype'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('ELECTROLYZER_FINISH_SAVED',sha(target),'authored_maps',len(maps),flush=True)


if __name__=='__main__':main()
