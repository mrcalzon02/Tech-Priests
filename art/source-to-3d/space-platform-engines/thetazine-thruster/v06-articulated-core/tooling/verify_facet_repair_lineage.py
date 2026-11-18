"""Bind final08 to07 clearance evidence; only four named shaft meshes differ."""
import bpy,json,pathlib,hashlib,importlib.util
R=pathlib.Path.cwd();S=R/'build/thruster-resume-20261117/thetazine-v06-motion';a=S/'core07-collar-aligned/thetazine-v06-collar-aligned-motion.blend';b=S/'core08-matched-collar-facets/thetazine-v06-matched-collar-motion.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
spec=importlib.util.spec_from_file_location('lineage_snapshot',R/'tools/art/thetazine_v05/validate_detail.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
def snapshot(p):
    bpy.ops.wm.open_mainfile(filepath=str(p));bpy.context.scene.frame_set(0);bpy.context.view_layer.update();return h.original_snapshot()
old=snapshot(a);new=snapshot(b);changed={f'Outer actuator body {i}'for i in(-1,1)}|{f'V06 giant actuator sliding rod {i}'for i in(-1,1)}
allowed=('mesh.coordinates','mesh.loops','mesh.polygons','mesh.uv','mesh.uv_active','mesh.custom_normals')
def differences(a,b,p=''):
    if isinstance(a,dict)and isinstance(b,dict):
        for k in sorted(set(a)|set(b)):
            q=p+'.'+k if p else k
            if k not in a or k not in b:yield q
            else:yield from differences(a[k],b[k],q)
    elif a!=b:yield p
fail=[];permitted=[]
if set(old['objects'])!=set(new['objects']):fail.append({'gate':'exact_object_names'})
for name in set(old['objects'])&set(new['objects']):
    for key in differences(old['objects'][name],new['objects'][name]):
        row={'object':name,'field':key}
        if name in changed and any(key==p or key.startswith(p+'.')for p in allowed):permitted.append(row)
        else:fail.append(row)
if old['materials']!=new['materials']:fail.append({'gate':'PBR_or_packed_image_or_shader_animation_changed'})
report={'status':'PASS_ONLY_FOUR_SHAFT_FACET_SURFACES_CHANGED'if not fail else'FAIL_REPAIR_LINEAGE','input_source_sha256':sha(a),'final_source_sha256':sha(b),'script_sha256':sha(pathlib.Path(__file__)),'all_source_objects':len(old['objects']),'permitted_changed_meshes':sorted(changed),'permitted_field_changes':permitted,'failures':fail,'scope':'Every other parent, local matrix, mesh coordinates/connectivity/UV/PBR/morphs and action/keyframe exactly retained. All object transforms/actions retained even for four repaired meshes. Therefore07 static110-vs-moving clearance excluding those four, and40flex lineage evidence carry to08 without rerunning old audits.'}
(b.parent/'facet-repair-lineage-validation.json').write_text(json.dumps(report,indent=2,default=h.json_default),encoding='utf-8');print(report['status'],len(fail),'failures',len(permitted),'permitted fields',flush=True)
