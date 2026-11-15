"""Fabricator-specific rolled plate, welded seams, clamp wear and mounted detail."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from authored_pbr import material_from_maps
from mh7_machine_scene import sha
from mechanical_routes import hollow_sleeve
from blender_build import uv_for_visible_surface
import refine_process as p


def mesh_digest(obj):
    payload=dict(vertices=[list(v.co) for v in obj.data.vertices],faces=[list(f.vertices) for f in obj.data.polygons],
                 shapes={k.name:[list(v.co) for v in k.data] for k in obj.data.shape_keys.key_blocks} if obj.data.shape_keys else {})
    return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()


def planar(obj,long_axis=0):
    uv=obj.data.uv_layers.active
    low=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    span=[max(v.co[i] for v in obj.data.vertices)-low[i] for i in range(3)]
    for face in obj.data.polygons:
        dominant=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=dominant]
        if long_axis in axes:axes=[next(i for i in axes if i!=long_axis),long_axis]
        for li in face.loop_indices:
            q=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=tuple((q[i]-low[i])/max(span[i],1e-6) for i in axes)


def cylindrical(obj):
    uv=obj.data.uv_layers.active;low=min(v.co.z for v in obj.data.vertices);length=max(v.co.z for v in obj.data.vertices)-low
    for face in obj.data.polygons:
        coords=[]
        for li in face.loop_indices:
            q=obj.data.vertices[obj.data.loops[li].vertex_index].co
            coords.append(((math.atan2(q.y,q.x)/math.tau)%1,(q.z-low)/max(length,1e-6)))
        seam=max(a for a,b in coords)-min(a for a,b in coords)>.5
        for li,(a,b) in zip(face.loop_indices,coords):uv.data[li].uv=(a+1 if seam and a<.5 else a,b)
        face.use_smooth=abs(face.normal.z)<.8
    obj.data.set_sharp_from_angle(angle=math.radians(35))


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve finish studies')
    out.mkdir(parents=True);source=src/'fabricator-v02.blend';bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene;scene.frame_set(0)
    prefix='TP Vessel Fabricator V02 | ';new='TP Fabricator V03 | ';col=bpy.data.collections['PROCESS']
    receipt=json.loads((src/'construction-receipt.json').read_text());original={o.name:mesh_digest(o) for o in scene.objects if o.type=='MESH'}
    def obj(label):return scene.objects[prefix+label]
    def mat(key):return bpy.data.materials[prefix+key]
    added=[]
    def own(o):added.append(o.name);uv_for_visible_surface(o);return o
    def bolt(label,center,axis='Z',radius=.019,depth=.018):return own(p.cyl(col,new+label,center,radius,depth,mat('iron'),axis,6))
    def joint(a,b,label):receipt['contacts'].append(dict(a=a.name,b=b.name,label=label))
    lid=obj('forming reservoir service lid');motor=obj('forming pressure pump motor')
    for x in (-1.23,-.73):
        for y in (.95,1.55):joint(bolt('reservoir lid screw '+str((x,y)),(x,y,.723)),lid,'lid screw seated on actual removable flange')
    for x in (-1.08,-.88):
        foot=own(p.block(col,new+'pump motor saddle '+str(x),(x,1.25,.739),(.06,.28,.05),mat('iron'),.003));joint(foot,lid,'motor saddle grounded on reservoir lid');joint(foot,motor,'motor housing supported by saddle')
    for y in (1.15,1.20,1.25,1.30,1.35):
        ring=own(hollow_sleeve(col,new+'pump motor cooling ring '+str(y),(-.98,y,.85),(0,1,0),.012,.145,.129,mat('gunmetal_dark'),40));joint(ring,motor,'cooling ring seated on motor housing')
    cap=own(p.cyl(col,new+'pump motor closed service cap',(-.98,1.09,.85),.132,.03,mat('gunmetal_dark'),'Y',40));joint(cap,motor,'motor service cap seated outside pump pressure chamber')
    for angle in (0,math.pi/2,math.pi,3*math.pi/2):
        joint(bolt('motor cap screw '+str(angle),(-.98+.10*math.cos(angle),1.069,.85+.10*math.sin(angle)),'Y',.012,.014),cap,'motor screw seats on closed cap')
        joint(bolt('tailstock cap screw '+str(angle),(1.652,.125*math.cos(angle),.95+.125*math.sin(angle)),'X',.016,.026),obj('closed annular tailstock pressure cap'),'tailstock screw seats outside open pressure core')
    # Anchors sit on actual grounded mounting plates, never on unsupported floor.
    for support in list(scene.objects):
        if support.type!='MESH' or support.parent or not any(t in support.name for t in ('grounded foot','grounded shoe','grounded clevis foot')):continue
        corners=[support.matrix_world@Vector(c) for c in support.bound_box]
        low=[min(q[i] for q in corners) for i in range(3)];high=[max(q[i] for q in corners) for i in range(3)]
        for side in (-1,1):
            x=(low[0]+high[0])/2+side*(high[0]-low[0])*.30;y=(low[1]+high[1])/2
            if 'clevis foot' in support.name:y+=.11
            joint(bolt('ground anchor '+support.name.split(' | ')[-1]+str(side),(x,y,high[2]+.008)),support,'anchor head seated on actual grounded plate')
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1);maps=[];assignments=[]
    def apply(label,objects,color,rough,metal,height,plan):
        material,records=material_from_maps(new+label,out/'textures'/label,color,rough,metal,height,plan);maps.extend(records)
        for o in objects:o.data.materials.clear();o.data.materials.append(material);assignments.append(dict(object=o.name,material=material.name,plan=plan))
        return material
    blank=obj('welded two-plate pressure blank');uv=blank.data.uv_layers.active
    for face in blank.data.polygons:
        indices=[blank.data.loops[li].vertex_index for li in face.loop_indices];angles=[(i%64)/64 for i in indices];wrap=max(angles)-min(angles)>.5
        for li,index,a in zip(face.loop_indices,indices,angles):
            q=blank.data.vertices[index].co;uv.data[li].uv=((q.x+1.18)/2.36,a+1 if wrap and a<.5 else a)
        face.use_smooth=abs(face.normal.x)<.95
    blank.data.set_sharp_from_angle(angle=math.radians(35))
    grain=.5+.5*np.sin(v*math.tau*197+.18*np.sin(u*math.tau*9));seam=np.minimum(np.minimum(v,1-v),abs(v-.5));heat=np.exp(-(seam/.023)**2)
    color=np.stack((.34+.007*grain,.36+.007*grain,.37+.007*grain),axis=2)
    color=color*(1-.48*heat[:,:,None])+np.array((.18,.135,.078))*(.48*heat[:,:,None])
    apply('formed-plate-steel',[blank],color,.32+.055*grain+.12*heat,.93-.10*heat,.00032*grain,
          'U is actual X length; V is the original two-sheet angular perimeter. Fine longitudinal rolling grain expands with the real morph. Restrained weld heat follows both actual Y-edge seams, not a front ellipse or global grunge stamp. Round necks retain real dimensions.')
    seams=[obj('actual longitudinal weld seam '+str(y)) for y in (-.535,.535)]
    for o in seams:cylindrical(o)
    ripple=.5+.5*np.sin(v*math.tau*120+2*np.sin(u*math.tau));color=np.stack((.23+.025*ripple,.235+.022*ripple,.23+.016*ripple),axis=2)
    apply('longitudinal-weld-beads',seams,color,.39+.12*ripple,np.full_like(u,.91),.0011*ripple,
          'Cylinder axial V follows each actual 1.37-tile seam. Shallow repeated weld ripples follow travel and stay on supported edge beads; no seam geometry or blank thickness is changed.')
    frames=[o for o in scene.objects if o.type=='MESH' and any(slot.material and slot.material.name==prefix+'martian_red' for slot in o.material_slots)]
    for o in frames:planar(o,2 if 'column' in o.name or 'pedestal' in o.name else 0)
    grain=.5+.5*np.sin(u*math.tau*133+.35*np.sin(v*math.tau*37));edge=np.exp(-(np.minimum(u,1-u)/.024)**2);end=np.exp(-(np.minimum(v,1-v)/.032)**2);wear=np.clip(.55*edge+.16*end,0,.65)
    color=np.broadcast_to(np.array((.27,.045,.031)),(size,size,3)).copy()+grain[:,:,None]*.004;color=color*(1-wear[:,:,None])+np.array((.15,.14,.12))*wear[:,:,None]
    apply('fabricator-frame-enamel',frames,color,.49+.06*grain+.09*end,.28+.42*wear,.0006*grain,
          'Per-face longitudinal UV follows each frame member. Fine red enamel, narrow exposed manufactured edges and dirt at member ends preserve the family finish without the pilot cloud pattern.')
    lands=[o for o in scene.objects if o.type=='MESH' and any(t in o.name for t in ('clamping land','welded sheet flange','upper flange clamping land','welding tool linear guide'))]
    for o in lands:planar(o)
    grind=.5+.5*np.sin(u*math.tau*221+.12*np.sin(v*math.tau*11));rub=np.exp(-((u-.5)/.33)**4);end=np.exp(-(np.minimum(v,1-v)/.045)**2)
    color=np.stack((.33+.008*grind,.35+.008*grind,.36+.008*grind),axis=2)+.035*rub[:,:,None]-.025*end[:,:,None]
    apply('ground-clamp-and-guide',lands,color,.28+.055*grind-.09*rub+.10*end,.94-.05*end,.00025*grind,
          'V runs along actual clamp/guide length, U across each face. Fine axial grind and a broad polished mating strip follow the exposed clamping lands, sheet flanges and linear guide. No sockets, hinge pivots or movement dimensions change.')
    cabinet=[obj('closed forming-fluid reservoir'),lid]
    for o in cabinet:planar(o,2)
    edge=np.exp(-(np.minimum(u,1-u)/.025)**2);seat=np.exp(-(np.minimum(v,1-v)/.04)**2);grain=.5+.5*np.sin(u*math.tau*79+np.sin(v*math.tau*31))
    color=np.stack((.070+.003*grain,.092+.003*grain,.096+.003*grain),axis=2)*(1-.13*seat[:,:,None])+.012*edge[:,:,None]
    apply('forming-fluid-reservoir',cabinet,color,.47+.07*grain+.10*seat,.62+.10*edge,.0005*grain,
          'Cabinet UV follows the actual hollow tank and lid edges. Dark painted steel has restrained seam oil and edge rub; bores and cavity stay open. The motor retains a separate circumferential finish.')
    motors=[motor,cap]+[o for o in scene.objects if 'pump motor cooling ring' in o.name]
    cylindrical(motor);cylindrical(cap)
    rib=.5+.5*np.sin(v*math.tau*83);oil=np.exp(-(np.minimum(v,1-v)/.055)**2)
    color=np.stack((.095+.004*rib,.115+.004*rib,.12+.004*rib),axis=2)*(1-.13*oil[:,:,None])
    apply('pump-motor-casting',motors,color,.46+.06*rib+.10*oil,.69-.10*oil,.0007*rib,
          'Axial/circumferential motor UV and real seated cooling rings. Fine cast finish and end-seam oil are confined to motor housing, separate from reservoir enamel and machined pressure fittings.')
    tooling=[obj(k) for k in ('upper die lift piston','hollow pressure injection mandrel','fixed full die hinge shaft','supported seam welding torch','actual welding contact tip')]
    for o in tooling:
        if o.data.vertices and not o.data.shape_keys and 'mandrel' not in o.name:cylindrical(o)
    grind=.5+.5*np.sin(v*math.tau*239);oil=np.exp(-(np.minimum(v,1-v)/.055)**2)
    color=np.stack((.38+.006*grind,.40+.006*grind,.405+.006*grind),axis=2)*(1-.10*oil[:,:,None])
    apply('ground-shafts-and-tool',tooling,color,.23+.045*grind+.09*oil,.95-.05*oil,.00025*grind,
          'Circumferential fine turning on real shaft/tool axes, restrained seated-end oil. Actual bore UV is retained on the mandrel. No scale, pressure bore or attachment frame changes.')
    fittings=[obj(k) for k in ('external neck restraint','moving upper die hinge lug -0.98','moving upper die hinge lug 0.98','upper die lift cylinder trunnion')]
    grain=.5+.5*np.sin(v*math.tau*147);seat=np.exp(-(np.minimum(v,1-v)/.055)**2)
    color=np.stack((.30+.007*grain,.21+.005*grain,.085+.003*grain),axis=2)*(1-.16*seat[:,:,None])
    apply('retaining-bronze',fittings,color,.34+.04*grain+.10*seat,.91-.05*seat,.0003*grain,
          'Existing physical sleeve U/V follows circumferential and axial dimensions. Restrained bronze machining and seam darkening belong to actual neck restraint, hinge lugs and grounded trunnion, not every steel part.')
    if any(mesh_digest(scene.objects[name])!=digest for name,digest in original.items()):raise RuntimeError('Finish changed preserved geometry or morph')
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    bpy.ops.file.pack_all();scene.frame_set(25);target=out/'fabricator-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt.update(status='dedicated finish and mounted-detail candidate; independent export and review pending',revision='V03',previous_source_sha256=sha(source),source_sha256=sha(target),preserved_geometry_and_morph_digests=original,
                   added_objects=added,surface_assignments=assignments,textures=[dict(**r,sha256=sha(r['file'])) for r in maps],
                   pending=['Independent exported mechanics, pressure core and material review','Relevant welding/pump sound','Final four-direction capture','Native fluid/item prototype and real pipe seating'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    scene.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('FABRICATOR_FINISH_SAVED',sha(target),len(maps),'MAPS',len(added),'MOUNTED_DETAILS',flush=True)


if __name__=='__main__':main()
