"""Author vessel, gantry, slide and metering surfaces on the proven mechanics."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parent))
from authored_pbr import material_from_maps
from finish_fabricator_v03 import mesh_digest,planar
from mh7_machine_scene import sha


def cylinder_uv(obj,axis=2):
    # Sleeves and formed shells have world-coordinate vertices; primitive
    # cylinders have local-coordinate vertices. Derive each actual local axis.
    uv=obj.data.uv_layers.active
    low=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    high=[max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    radial=[i for i in range(3) if i!=axis];radial_i,radial_j=radial
    cx,cy=((low[i]+high[i])/2 for i in radial);length=high[axis]-low[axis]
    for face in obj.data.polygons:
        coords=[]
        for li in face.loop_indices:
            q=obj.data.vertices[obj.data.loops[li].vertex_index].co
            coords.append(((math.atan2(q[radial_j]-cy,q[radial_i]-cx)/math.tau)%1,(q[axis]-low[axis])/max(length,1e-6)))
        wrap=max(a for a,b in coords)-min(a for a,b in coords)>.5
        for li,(a,b) in zip(face.loop_indices,coords):uv.data[li].uv=(a+1 if wrap and a<.5 else a,b)


def round_normals(obj):
    for face in obj.data.polygons:face.use_smooth=True
    obj.data.set_sharp_from_angle(angle=math.radians(35))


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve surface studies')
    out.mkdir(parents=True);source=src/'assembler-v02.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0)
    prefix='TP Canister Assembler V02 | ';new='TP Assembler V03 | '
    receipt=json.loads((src/'construction-receipt.json').read_text());meshes=[o for o in s.objects if o.type=='MESH' and not o.get('library_instance')]
    original={o.name:mesh_digest(o) for o in s.objects if o.type=='MESH'};maps=[];assignments=[];surface_plans=[]
    size=512;v,u=np.mgrid[0:size,0:size].astype(np.float32)/(size-1)
    def material(label,color,rough,metal,height,plan):
        m,records=material_from_maps(new+label,out/'textures'/label,color,np.broadcast_to(rough,u.shape),np.broadcast_to(metal,u.shape),height,plan)
        maps.extend(records);surface_plans.append(dict(region=label,plan=plan));return m
    def assign(o,m):
        o.data.materials.clear();o.data.materials.append(m);assignments.append(dict(object=o.name,material=m.name))
    grain=.5+.5*np.sin(u*math.tau*173+.25*np.sin(v*math.tau*17));ends=np.exp(-(np.minimum(v,1-v)/.035)**2)
    cast=material('machined-cast-frame',np.stack((.085+.006*grain,.095+.006*grain,.10+.006*grain),axis=2)*(1-.16*ends[:,:,None]),.49+.07*grain+.06*ends,.74,.0007*grain,
        'Fine cast steel belongs to actual nests, mounting bed, crosshead, carriage, bearing bridges and guide mounts. Per-face UV follows each member, with restrained end-seam oil; no repeated painted stripes on unrelated parts.')
    for o in meshes:
        if any(sl.material and sl.material.name==prefix+'iron' for sl in o.material_slots):planar(o,2 if 'support' in o.name else 0);assign(o,cast)
    edges=np.exp(-(np.minimum(u,1-u)/.021)**2);wear=np.clip(.45*edges+.12*ends,0,.55)
    enamel=material('gantry-red-enamel',np.broadcast_to(np.array((.25,.038,.026)),(size,size,3)).copy()*(1-wear[:,:,None])+np.array((.16,.15,.13))*wear[:,:,None]+.003*grain[:,:,None],.48+.055*grain+.08*ends,.28+.40*wear,.00045*grain,
        'Longitudinal member UV directs fine enamel texture along actual upright, shoe and spanning beam. Narrow edge exposure and seated-end grime replace the donor cloud pattern. Cap actuator uprights receive the same structural enamel.')
    for o in meshes:
        if any(sl.material and sl.material.name==prefix+'martian_red' for sl in o.material_slots):planar(o,0 if 'beam' in o.name else 2);assign(o,enamel)
    grind=.5+.5*np.sin(v*math.tau*229+.18*np.sin(u*math.tau*7));seat=np.exp(-(np.minimum(v,1-v)/.035)**2)
    steel=material('turned-shoulder-and-cap',np.stack((.31+.008*grind,.33+.008*grind,.34+.008*grind),axis=2)*(1-.10*seat[:,:,None]),.28+.045*grind+.08*seat,.94-.04*seat,.00022*grind,
        'Cylindrical U wraps the actual vessel axis; V follows its formed shoulder. Fine circumferential turning follows shell necks and cap perimeters. Planar cap faces retain their own projection, avoiding collapsed polar UV on closed ends.')
    roll=.5+.5*np.sin(u*math.tau*179+.22*np.sin(v*math.tau*11))
    band_seats=np.exp(-((v-(.60-.52)/.93)/.025)**2)+np.exp(-((v-(1.14-.52)/.93)/.025)**2)
    vessel=material('canister-body-enamel',np.stack((.053+.003*roll,.071+.003*roll,.064+.003*roll),axis=2)*(1-.12*band_seats[:,:,None]),.43+.045*roll+.06*band_seats,.47,.00030*roll,
        'U is actual shell circumference and V is .52..1.45 vessel height, independently centered for each of three vessels. Fine axial manufacturing grain and slight darkening under actual retaining bands distinguish the body enamel from bare formed shoulders. No painted pseudo-window or generic front ellipse.')
    for x in (-1.0,0.0,1.0):
        o=s.objects[prefix+'hollow canister shell '+str(x)];cylinder_uv(o);assign(o,vessel);o.data.materials.append(steel)
        for face in o.data.polygons:
            face.material_index=int(sum(o.data.vertices[i].co.z for i in face.vertices)/len(face.vertices)>1.165)
        assignments.append(dict(object=o.name,material=steel.name,region='formed shoulder and neck above Z1.165'))
    for o in meshes:
        if 'pressure cap plate' in o.name or 'canister closed bottom' in o.name:planar(o);assign(o,steel)
    rub=np.exp(-((u-.5)/.32)**4);grind=.5+.5*np.sin(u*math.tau*239+.12*np.sin(v*math.tau*9))
    guide=material('ground-guides-and-ram',np.stack((.34+.007*grind,.36+.007*grind,.37+.007*grind),axis=2)+.025*rub[:,:,None]-.018*ends[:,:,None],.26+.04*grind-.07*rub+.08*ends,.96-.03*ends,.00019*grind,
        'Per-face V follows rails, carrier channels and jaw lift lands; cylindrical U/V follows actual primitive shaft axes on rods and hollow tools. Polished mating strips remain on guides and tooling rather than the red frame.')
    tools=('ground head linear guide','cap transfer rail','cap carrier rear saddle','cap jaw lift guide','cap rim lifting jaw','cap slide piston','annular cap sealing punch','telescoping hollow sealing ram','stationary nozzle guide sleeve','actual sliding pellet gate','meter eccentric pin','gate connecting-rod pivot','supported pellet metering spindle','shell loading roller')
    for o in meshes:
        if any(t in o.name for t in tools):
            if any(t in o.name for t in ('piston','punch','ram','sleeve','pin','pivot','spindle','roller')):cylinder_uv(o)
            else:planar(o,1 if 'cap ' in o.name else 0)
            assign(o,guide)
    grain=.5+.5*np.sin(v*math.tau*181+.16*np.sin(u*math.tau*9))
    bronze=material('retaining-and-meter-bronze',np.stack((.29+.007*grain,.20+.005*grain,.074+.003*grain),axis=2)*(1-.15*ends[:,:,None]),.35+.045*grain+.08*ends,.91,.00026*grain,
        'Restrained bronze belongs to actual retaining bands, window flanges, lid locking lips, metering bearings and eccentric arm. Sleeve U/V follows real bores and seating faces; it is not repeated across painted frames or bare tools.')
    for o in meshes:
        if any(t in o.name for t in ('retaining band','retaining head','witness window','cap locking lip','meter spindle bearing','meter eccentric arm','telescoping pellet fill tube')):
            if any(t in o.name for t in ('band','lip','bearing','tube')):cylinder_uv(o)
            else:planar(o)
            assign(o,bronze)
    grain=.5+.5*np.sin(u*math.tau*191+.15*np.sin(v*math.tau*13))
    feed=material('hopper-and-meter-steel',np.stack((.17+.006*grain,.19+.006*grain,.195+.006*grain),axis=2)*(1-.13*ends[:,:,None]),.36+.06*grain+.10*ends,.91,.00032*grain,
        'Actual hopper circumference and throat-height UV carry fine rolled steel. Existing route UV follows the curved feed arc length; the valve retains machined per-face projection. Throat-end darkening stays localized to feed and metering hardware.')
    for o in meshes:
        if any(t in o.name for t in ('open metered pellet hopper','carriage pellet feed bore','bored sliding gate valve body')):
            if 'hopper' in o.name:cylinder_uv(o)
            elif 'valve body' in o.name:planar(o,2)
            assign(o,feed)
    grain=.5+.5*np.sin(u*math.tau*151+.33*np.sin(v*math.tau*23))
    housing=material('tool-and-actuator-casting',np.stack((.054+.004*grain,.070+.004*grain,.076+.004*grain),axis=2)*(1-.16*ends[:,:,None]),.47+.06*grain+.08*ends,.66,.00055*grain,
        'Dedicated dark cast housing finish follows the actual hollow press and cap-slide cylinders, distinct from machined rods and bronze seals. Existing bore UV remains cylindrical; mild seated-end oil explains service joints.')
    for o in meshes:
        if 'hollow electric press housing' in o.name or 'cap slide actuator ' in o.name:cylinder_uv(o,1 if 'cap slide actuator ' in o.name else 2);assign(o,housing)
    fine=.5+.5*np.sin(v*math.tau*101)
    conductor=material('conductor-contact-brass',np.stack((.32+.005*fine,.235+.004*fine,.10+.002*fine),axis=2),.29+.03*fine,.95,.00012*fine,
        'Linear guide-length UV follows real current rails and contact pads. Fine contact rub distinguishes electrical brass from worn vessel retainers; supports and insulation keep their original material identity.')
    for o in meshes:
        if 'insulated conductor rail' in o.name or 'conductive sliding pad' in o.name:planar(o);assign(o,conductor)
    mottled=.5+.18*np.sin(u*math.tau*17)*np.sin(v*math.tau*19)+.12*np.sin(u*math.tau*47+v*math.tau*31)
    concrete=material('equipment-footing',np.stack((.20+.018*mottled,.205+.018*mottled,.19+.017*mottled),axis=2),.84+.05*mottled,0,.001*mottled,
        'Fine low-contrast mineral variation on the actual equipment footing, separate from metal tooling. Full footing-face UV prevents scaling another machine concrete atlas over individual bolts or shells.')
    assign(s.objects[prefix+'full 4x4 equipment footing'],concrete)
    # Smooth the actual round shells, shoulders, hopper and routed feed while
    # retaining hard profile breaks. This changes normals, never the mesh.
    for o in meshes:
        if any(t in o.name for t in ('hollow canister shell','canister retaining band','cap locking lip','open metered pellet hopper','carriage pellet feed bore','hollow electric press housing','cap slide actuator ','stationary nozzle guide sleeve','telescoping pellet fill tube','annular cap sealing punch','telescoping hollow sealing ram','meter spindle bearing','bored sliding gate valve body')):round_normals(o)
    if any(mesh_digest(s.objects[name])!=digest for name,digest in original.items()):raise RuntimeError('Surface pass changed source geometry')
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    bpy.ops.file.pack_all();s.frame_set(43);target=out/'assembler-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt.update(status='assembler-specific surface candidate; independent export and visual review pending',previous_source_sha256=sha(source),source_sha256=sha(target),preserved_geometry_and_morph_digests=original,surface_assignments=assignments,surface_plans=surface_plans,textures=[dict(**r,sha256=sha(r['file'])) for r in maps],pending=['Independent source/export geometry, PBR and visual review','Relevant metering/index/sealing sound','Four idle and working capture directions','State-preserving native pellet/shell assembly'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('ASSEMBLER_FINISH_SAVED',sha(target),len(maps),'MAPS',len(assignments),'SURFACE_ASSIGNMENTS',flush=True)


if __name__=='__main__':main()
