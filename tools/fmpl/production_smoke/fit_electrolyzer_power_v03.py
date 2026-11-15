"""Finish the physical electrical path and supported isolation handwheels."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
from mechanical_routes import hollow_route,hollow_sleeve,compression_joint
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain previous assembly versions')
    out.mkdir(parents=True);source=src/'electrolyzer-v01.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    prefix='TP_ELECTROLYZER_V03 | ';cols={c.name:c for c in s.collection.children};added=[];contacts=[]
    # Keep each chamber's top bearing plane while extending its plinth down
    # through the measured .06-tile air gap to the foundation surface.
    for i in (1,2):
        plinth=bpy.data.objects['TP_ELECTROLYZER_V01 | cell bearing plinth '+str(i)]
        plinth.location.z=.22;plinth.dimensions.z=.24
        plinth['v03_repair']='bearing plane retained at .34; sole seated on .10 footing'
    def material(token):
        return next(m for m in bpy.data.materials if m.name.startswith('TP Electrolyzer V01 | '+token))
    mats={k:material(k) for k in ('iron','brass','electrical porcelain','gunmetal_dark')}
    def own(ob):
        added.append(ob.name);ob['construction_revision']='V03 electrical contact refinement'
        if not ob.data.uv_layers:uv_for_visible_surface(ob)
        return ob
    def cyl(label,loc,r,depth,mat='iron',axis='Z',col='PROCESS',vertices=32):
        return own(p.cyl(cols[col],prefix+label,loc,r,depth,mats[mat],axis,vertices))
    def block(label,loc,size,mat='iron',col='PROCESS'):
        ob=p.block(cols[col],prefix+label,loc,size,mats[mat],.004);uv_for_visible_surface(ob);return own(ob)
    def beam(label,a,b,width,depth,mat='brass',col='PROCESS'):
        a,b=Vector(a),Vector(b);ob=block(label,(a+b)/2,(width,depth,(b-a).length),mat,col)
        ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob
    def pair(a,b,label):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,label=label))
    # The earlier diagonal ended beside the gas neck. Replace that with an
    # offset cell terminal seated on the head through electrical porcelain.
    for ob in list(s.objects):
        if 'flat rectifier bus strap ' in ob.name:bpy.data.objects.remove(ob,do_unlink=True)
    for i,x in enumerate((-.62,.62),1):
        head='TP_ELECTROLYZER_V01 | top gas collector closure '+str(i)
        seat=cyl('cell terminal insulated seat '+str(i),(x,.24,1.968),.074,.056,'electrical porcelain')
        stud=cyl('cell terminal conductor '+str(i),(x,.24,2.035),.026,.10,'brass')
        nut=cyl('cell terminal hex nut '+str(i),(x,.24,2.077),.046,.029,'brass',vertices=6)
        pair(seat,head,'insulated cell terminal mounted to head');pair(stud,seat,'conductor retained by porcelain');pair(nut,stud,'lug fastening')
        rectseat=cyl('rectifier top terminal porcelain '+str(i),(x,1.10,1.700),.070,.062,'electrical porcelain')
        rectstud=cyl('rectifier top conductor '+str(i),(x,1.10,1.733),.029,.080,'brass')
        pair(rectseat,'TP_ELECTROLYZER_V01 | rectifier cast enclosure','rectifier terminal support');pair(rectstud,rectseat,'insulated rectifier conductor')
        rise=beam('rectifier bus rise '+str(i),(x,1.10,1.735),(x,.93,2.33),.055,.023)
        feed=beam('insulated cell bus feed '+str(i),(x,.93,2.33),(x,.24,2.075),.055,.023)
        pair(rise,rectstud,'power entry lug');pair(rise,feed,'supported bus joint');pair(feed,nut,'cell power terminal contact')
        pair(feed,'TP_ELECTROLYZER_V01 | busbar insulated bridge stud '+str(x),'bridge-supported busbar')
    # Wheels are real radial assemblies attached to their operating spindles.
    for sign in (-1,1):
        side=sign*1.33
        hub=cyl('handwheel seated hub '+str(sign),(side,.275,1.25),.028,.038,'brass','Y','PIPING')
        pair(hub,'TP_ELECTROLYZER_V01 | gas valve operating spindle '+str(sign),'handwheel hub retained on spindle')
        ring='TP_ELECTROLYZER_V01 | gas isolation handwheel '+str(sign)
        for axis in ('X','Z'):
            a=Vector((side,.275,1.25));b=a.copy();idx=0 if axis=='X' else 2
            a[idx]-=.086;b[idx]+=.086
            spoke=beam('handwheel cross spoke '+str((sign,axis)),a,b,.014,.014,'brass','PIPING')
            pair(spoke,hub,'spoke at hub');pair(spoke,ring,'spoke at rim')
    # A short supported low-voltage conduit joins the actual donor rear gland
    # to the rectifier front cover. This is not a gameplay wire connection.
    cable=hollow_route(cols['CONTROLS'],prefix+'console to rectifier conduit',
        [(.795,-1.475,1.07),(.795,-1.34,1.07),(1.03,-1.34,1.07),
         (1.03,-1.34,.70),(1.03,.72,.70),(.65,.72,.70),(.65,.9565,.70)],.020,.012,mats['gunmetal_dark'])
    own(cable)
    glands=[]
    for name,point,direction in (('console',(.795,-1.475,1.07),(0,1,0)),('rectifier',(.65,.9565,.70),(0,-1,0))):
        parts=compression_joint(cols['CONTROLS'],prefix+name+' electrical gland',point,direction,.02,mats['iron'],mats['brass'],True)
        for ob in parts:own(ob)
        glands.extend(parts)
    # Saddle foot is fastened to the upright, the hoop captures the conduit.
    clamp=own(hollow_sleeve(cols['CONTROLS'],prefix+'upright conduit retaining hoop',(1.03,-1.,.70),(0,1,0),.055,.031,.0205,mats['iron']))
    foot=block('upright conduit clamp foot',(1.06,-1.,.70),(.041,.09,.064),'iron','CONTROLS')
    pair(foot,'TP_ELECTROLYZER_V01 | upright edge flange '+str((1.13,-1.,-.055)),'conduit clamp grounded to upright')
    pair(foot,clamp,'clamp foot to hoop')
    # Resolve exact authored names without depending on Python int formatting.
    candidates=[o for o in s.objects if 'upright edge flange' in o.name and abs(o.location.x-1.075)<.001 and abs(o.location.y+1)<.001]
    if len(candidates)!=1:raise RuntimeError('Ambiguous actual upright clamp receiver')
    contacts[-2]['b']=candidates[0].name
    for name in ('port_manifest.json','part_provenance.json','route-readback.json'):
        shutil.copy2(src/name,out/name)
    bpy.ops.file.pack_all();target=out/'electrolyzer-v01.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    report=dict(status='candidate_native; independent contact check pending',revision='V03 electrical construction',
                source_sha256=sha(source),native_sha256=sha(target),new_objects=added,contacts=contacts,
                pending=['independent electrical support/contact readback','process route regression','export and visual review','finishing','animation capture','native prototype'])
    (out/'construction-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('ELECTROLYZER_POWER_V03_SAVED',sha(target),flush=True)


if __name__=='__main__':main()
