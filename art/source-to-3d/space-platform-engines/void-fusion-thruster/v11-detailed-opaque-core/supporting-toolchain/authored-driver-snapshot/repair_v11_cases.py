"""Transplant only repaired closed new receiver covers into validated detail
hardware; all accepted primary/guide geometry remains unchanged."""
import bpy,pathlib,sys,json,hashlib,shutil,bmesh
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v11d-detailed';REPAIRED=ROOT/'build/thruster-resume-20261117/void-fusion-v10j-closed-reliefs';OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(exist_ok=True,parents=True);sys.path.insert(0,str(HERE));from bake_surface_atlas import bake
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v11.blend'));c=json.loads((OLD/'source-contract.json').read_text());names=[r['object']for r in c['functional_detail_v10']['receiver_covers']];original={n:bpy.data.objects[n]for n in names}
with bpy.data.libraries.load(str(REPAIRED/'void-fusion-v10.blend'),link=False)as(a,b):b.objects=list(names)
mat=bpy.data.materials.new('V11 repaired blackened cast iron receiver surfaces');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.035,.043,.038,1);mat.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.66;mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.64
repairs=[];targets=[]
for i,loaded in enumerate(b.objects):
    # Name suffixes are local library collision names; recipe order binds exact
    # original names independently of Blender's numeric suffix allocation.
    name=names[i];target=original[name];target.data=loaded.data.copy();target.data.materials.clear();target.data.materials.append(mat);targets.append(target);bpy.data.objects.remove(loaded,do_unlink=True)
    bm=bmesh.new();bm.from_mesh(target.data);assert all(len(e.link_faces)==2 for e in bm.edges),(name,'Repaired cover still open');volume=bm.calc_volume(signed=True);assert volume>.002;bm.free();repairs.append({'object':name,'actual_closed_volume':volume,'repair':'Actual rock-pocket cuts preserved. Degenerate coplanar complex pocket-carrier Boolean reliefs replaced by bounded machined reliefs on actual unchanged carrier bounds +.00035 clearance; simple body/base cuts first; distant/touching cutters skipped.'})
bake_record=bake(targets,OUT/'textures','V11 closed-receiver-machining-surfaces',768,c['surface_contacts'],False)
c['functional_detail_v10']['closed_case_repair']={'input_previous_detail_glb_sha256':sha(OLD/'void-fusion-v11.glb'),'guarded_repair_source_glb_sha256':sha(REPAIRED/'void-fusion-v10.glb'),'cases':repairs,'case_surface_bake':bake_record,'policy':'Only six added detail receiver-cover meshes replaced; all889 nonexempt primary parts, eight authorized repaired braces, all38 wires,34 guide assemblies and62 fasteners unchanged from prior detail source.'};c['revision']='V11 final constructed narrow detail candidate: closed receivers, supported protected guides, retained machinery backing';c['functional_detail_v10']['stage']='CONSTRUCTION_COMPLETE_TECHNICAL_CHECKS_PENDING'
for im in bpy.data.images:
    if im.source=='FILE'and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type in('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v11.blend';glb=blend.with_suffix('.glb');bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True);c.update({'blend_sha256':sha(blend),'glb_sha256':sha(glb)});(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json','noctilith-reference.json'):shutil.copy2(OLD/name,OUT/name)
print('V11_CLOSED_DETAIL_CANDIDATE_SAVED',glb,flush=True)
