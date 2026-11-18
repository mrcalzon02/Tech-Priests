"""Assemble exact V06 ownership names without changing any authored model."""
import json,pathlib
R=pathlib.Path.cwd();B=R/'build/thruster-resume-20261117';S=B/'thetazine-v06-motion'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
root=read(S/'root-allowed-changes.json');side=read(S/'core06-seated-rods/side-actuator-motion.json')
detail=read(S/'core06-seated-rods/detail-manifest.json')
base=read(B/'thetazine-v05-detail/inspection/source35-original-mesh-baseline.json')['objects']
v05=read(R/'art/source-to-3d/space-platform-engines/thetazine-thruster/v05-mechanical-detail/detail-manifest.json')
changed=set(root['allowed_source_changes'])|set(side['allowed_source_changes'])
core='V04 independently suspended engine core'
names=set(base);parents={n:r['parent']for n,r in base.items()}
for row in v05['details']:names.add(row['name']);parents[row['name']]=row['host']
def in_core(name):
    seen=set()
    while name and name not in seen:
        if name==core:return True
        if name in base and core in base[name].get('parent_chain',[]):return True
        seen.add(name);name=parents.get(name)
    return False
fixed=sorted(n for n in names if n not in changed and not in_core(n))
new=sorted(set(side['new_meshes'])|set(detail['localized_static_mounts']['new_detail_names']))
physical=sorted(names|set(new))
declarations={'status':'EXACT_NAMES_AND_OWNERSHIP_FOR_INDEPENDENT_V06_CHECK',
 'new_names':new,'source_only_names':['V04 render-only full-throated combustion volume'],
 'fixed_names':fixed,
 'loop_groups':[{'names':physical,'frames':[1,65],'tolerance':1e-6,'reason':'Author-specified working-loop closure within float32 transform precision; frame0 is distinct cold pose.'}],
 'clearance':{'participants':sorted((changed-{core})|set(new)),'participant_roots':[core],
 'minimum_clearance':.0005,'bounded_contacts':[]},
 'declaration_inputs':{'root':'root-allowed-changes.json','side':'core06-seated-rods/side-actuator-motion.json',
 'static':'core06-seated-rods/detail-manifest.json'},
 'contact_note':'Exact intentional annular actuator fits are independently measured by dedicated per-pose mesh checks; static bounded mate declarations are separately supplied by static author.'}
out=S/'aggregate-validation-declarations.json';out.write_text(json.dumps(declarations,indent=2),encoding='utf-8')
print('EXACT_DECLARATIONS',len(new),'new',len(fixed),'fixed',len(physical),'physical',len(declarations['clearance']['participants']),'explicit affected meshes')
