"""Technical UV/bore repair + bounded reference mineral rebake. Fixed geometry
and socket positions preserved except drilled electrical insulation bores."""
import bpy,bmesh,pathlib,sys,json,hashlib,shutil,math
from mathutils import Vector
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];sys.path.insert(0,str(HERE))
from pipette_power_terminal import _uv_and_normals
from bake_surface_atlas import bake
OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v09';OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(exist_ok=True,parents=True);pilot='--pilot' in sys.argv
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v09.blend'));c=json.loads((OLD/'source-contract.json').read_text());S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
for o in S.objects:
    if o.type=='MESH' and 'tapered cage shoulder' in o.name:
        # Actual route witness found the lower shoulder intruding into the
        # winding envelope. Move only the lower cast leg inboard, preserving
        # its real upper cage seat and crossmember load path.
        for v in o.data.vertices:
            if v.co.z<.30:v.co.x-=math.copysign(.060,v.co.x)
        for q in c['surface_contacts']:
            if q['a']==o.name and 'shoulder lower cap' in q['reason']:q['point'][0]=math.copysign(.195,q['point'][0])
for o in list(S.objects):
    if o.type=='MESH' and o.get('pipette_asset_owned'):_uv_and_normals(o)
BORES=[]
for o in list(S.objects):
    if not o.name.startswith('Insulator '):continue
    # Bus is an electrical conductor, so every insulating sleeve has an actual
    # through-bore instead of an invisible wire intersecting a solid cylinder.
    p=o.matrix_world.translation;bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.0115,depth=.45,location=p,rotation=(math.pi/2,0,0));cut=bpy.context.object
    mod=o.modifiers.new('Actual axial power-bus clearance bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True);_uv_and_normals(o)
    BORES.append({'object':o.name,'axis_point':list(p),'axis':[0,1,0],'designed_bore_radius':.0115,'wire_radius':.010,'minimum_polygonal_radial_clearance':.0115*math.cos(math.pi/32)-.010})
for f in c['pipette']['fixtures']:
    # Inventory every remaining fitting fastener/cover by its actual hardware
    # interface, not only the lug-to-pad backface already in the source receipt.
    d=f['source_bore_measurement']['wire_od'];r=d*1.1;p=Vector(f['source_mating_measurement']['proposed_pad_point']);n=Vector(f['source_mating_measurement']['normal']);t=Vector(f['wire_entry_socket']['normal']);u=n.cross(t).normalized();outer=r*.74;length=r*1.3;eye=r*1.23;bore=r*.39;thick=r*.22;axis=outer+d*.014;center=eye+length*.55;bootcenter=center+length*.5-d*.32
    body,boot,stud,washer,nut=f['objects'];parent=f['surface_contacts'][0]['b']
    for a,b,q,normal,why in [(stud,parent,p,n,'Retaining stud actual bottom cap to receiving pad'),(washer,body,p+u*(bore*1.20)+n*thick,n,'Washer actual lower annular face on lug eye upper annulus'),(nut,washer,p+u*(bore*.71*1.30)+n*(thick+d*.14),n,'Bored hex nut actual rear annulus on washer'),(boot,body,p+t*bootcenter+u*outer+n*axis,u,'Insulating crimp cover actual bore on conductive barrel outer surface')]:
        c['surface_contacts'].append({'a':a,'b':b,'point':list(q),'normal':list(normal),'tolerance':2e-5,'ray_span':.00015,'reason':why})
records=[]
rocks=c['rock_bays'][3:4] if pilot else c['rock_bays']
for i,record in enumerate(rocks):
    o=bpy.data.objects[record['object']];records.append(bake([o],OUT/'textures','V09 Noctilith '+record['object'][-2:],768,c['surface_contacts'],mineral=True));print('MINERAL_REBAKE',o.name,flush=True)
reference=ROOT/'docs/art/thruster-resumption-20261117/animation-capture/noctilith-reference.json'
shutil.copy2(reference,OUT/'noctilith-reference.json')
c['bounded_mineral_pass']={'status':'ONE_ROCK_INSPECTION_PILOT' if pilot else 'ALL_SEVEN_ROCKS_BAKED_REVIEW_PENDING','reference_receipt_sha256':sha(reference),'bakes':records,'geometry_policy':'No rock vertex/face changes; actual geometry/contacts/energized recess assignments preserved','interpretation':'Pinned original blackstone icons and legacy cold/run rock windows: broad angular charcoal/olive mineral face mottling, granular chipped faces, sparse subdued ochre nonmetal fracture web; separate recessed green energized faces. Not gray asteroid family or metallic brass.'}
c['pipette']['insulator_bores']=BORES;c['pipette']['terminal_uv_repair']='Per-triangle local physical origin prevents tiny Boolean-face float UV collapse; no relaxed triangle or UV thresholds.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v09.blend';glb=OUT/'void-fusion-v09.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
c.update({'blend_sha256':sha(blend),'glb_sha256':sha(glb)});(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json'):shutil.copy2(OLD/name,OUT/name)
print('V09_FINISH_HANDOFF_SAVED',glb,flush=True)
