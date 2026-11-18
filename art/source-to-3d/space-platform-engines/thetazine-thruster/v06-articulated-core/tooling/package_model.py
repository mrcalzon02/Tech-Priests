"""Archive only the fully checked V06 model; preserve evidence bytes and baselines."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

p=argparse.ArgumentParser();p.add_argument('--final-clearance',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[3];stage=repo/'build/thruster-resume-20261117/thetazine-v06-motion'
out=repo/'art/source-to-3d/space-platform-engines/thetazine-thruster/v06-articulated-core'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
source=stage/'core10-complete-pose-range/thetazine-v06-complete-motion.blend'
glb=stage/'core10-complete-pose-range/thetazine-v06-complete-motion.glb'
source_sha='35c4f470ad92015b70d056086b7f6e53573f4ccabbecab6af346ab382734871e'
glb_sha='77892d382fe0b1f39f28d84082d6c68dbb3b00c26f1476a3963cac97b9fce074'
assert sha(source)==source_sha and sha(glb)==glb_sha
a.final_clearance=a.final_clearance.resolve();last=read(a.final_clearance)
assert last['status'].startswith('PASS'),('Final scoped clearance not passed',last['status'])
assert source_sha in json.dumps(last), 'Final clearance not bound to exact source'
assert last['source']['sha256']==source_sha and last['actual_glb']['sha256']==glb_sha
for ref in last.get('references',[]):assert sha(Path(ref['path']))==ref['sha256']
reports={
    'motion-export-validation.json':stage/'independent10-export66/validation.json',
    'core-fixed-envelope.json':stage/'core08-matched-collar-facets/core-vs-original-fixed-envelope.json',
    'core-restored-pumpbed-envelope.json':stage/'core08-matched-collar-facets/core-vs-restored-fixed-pumpbed-envelope.json',
    'new-bracket-moving-clearance.json':stage/'core07-collar-aligned/static-bracket-moving-clearance.json',
    'static-bracket-seats.json':stage/'core06-seated-rods/static-contact-first-pose.json',
    'final-measured-interface-lineage.json':stage/'core07-collar-aligned/flex-lineage-validation.json',
    'four-shaft-repair-lineage.json':stage/'core08-matched-collar-facets/facet-repair-lineage-validation.json',
    'leaf-flex-validation.json':stage/'core-02-owned-flex/flex-validation.json',
    'hose-support-validation.json':stage/'core-03c-seated-interfaces/interface-validation.json',
    'retained-collar-frames.json':stage/'core08-matched-collar-facets/actual-collar-frame-measurement.json',
    'actuator-interface-nonmates.json':a.final_clearance,
}
for name,path in reports.items():assert read(path)['status'].startswith('PASS'),(name,read(path)['status'])
motion=read(reports['motion-export-validation.json'])
assert motion['source_sha256']==source_sha and motion['glb_sha256']==glb_sha
preview=stage/'core08-matched-collar-facets/motion-preview'
capture=read(preview/'motion-capture.json');package=read(preview/'motion-preview-package.json')
assert capture['binding']['source_sha256']==package['source_sha256']==source_sha
assert len(capture['frames'])==66 and {r['frame']for r in capture['frames']}==set(range(66))
render_dir=stage/'core10-complete-pose-range/export-preview';render=read(render_dir/'render-receipt.json')
assert render['source_sha256']==source_sha and render['glb_sha256']==glb_sha and len(render['rendered'])==4
for row in render['rendered']:assert sha(render_dir/row['file'])==row['sha256']
assert not out.exists(),'Archive exists; do not overwrite a delivered revision'
out.mkdir(parents=True)
copied=[]

def copy(src,relative):
    dst=out/relative;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    assert sha(src)==sha(dst)
    copied.append({'file':str(relative).replace('\\','/'),'sha256':sha(dst),'bytes':dst.stat().st_size,'copied_from':str(src)})

copy(source,Path('thetazine-v06-articulated-core.blend'));copy(glb,Path('thetazine-v06-articulated-core.glb'))
for name,path in reports.items():copy(path,Path('evidence')/name)
for index,ref in enumerate(last.get('references',[])):
    path=Path(ref['path'])
    if str(path)not in {r['copied_from']for r in copied}:
        copy(path,Path('evidence/scoped-contact-references')/f'{index:02}-{path.name}')
for filename in ('core-motion.json',):copy(stage/'core-01'/filename,Path('provenance')/filename)
for directory,names in (
    ('core-02-owned-flex',('core-flex-retarget.json',)),
    ('core-03c-seated-interfaces',('interface-retarget.json','pipette-pose-plans.json')),
    ('core08-matched-collar-facets',('matched-facet-repair.json',)),
    ('core05-fixedbrackets',('static-allowed-changes.json',)),
    ('core10-complete-pose-range',('complete-pose-range-export.json','detail-manifest.json','side-actuator-motion.json','visual-review.json')),
):
    for name in names:copy(stage/directory/name,Path('provenance')/name)
# Keep the exact role/terminal-span authorities used by the final scoped review.
already={r['file']for r in copied}
for path in sorted((stage/'core10-complete-pose-range').glob('*.json')):
    relative=Path('provenance')/path.name
    if relative.as_posix()not in already:copy(path,relative)
for filename in ('motion-capture.json','motion-preview-package.json','motion-video-preview.json',
                 'thetazine-v06-mechanism-cycle.gif','thetazine-v06-mechanism-cycle.mp4','thetazine-v06-mechanism-poses.png'):
    copy(preview/filename,Path('motion-preview')/filename)
for row in render['rendered']:copy(render_dir/row['file'],Path('export-preview')/row['file'])
copy(render_dir/'render-receipt.json',Path('export-preview/render-receipt.json'))
tools=repo/'tools/art/thetazine_v06'
for path in sorted(tools.glob('*.py')):copy(path,Path('tooling')/path.name)
for name in ('animate_core_v06.py','retarget_core_flex_v06.py','verify_core_flex_v06.py'):
    copy(repo/'tools/art/thetazine_v05'/name,Path('tooling')/name)
manifest={'status':'VALIDATED_V06_MODEL_ANIMATION_SOURCE_AND_GLB_LOCAL_ARCHIVE',
          'native':{'file':'thetazine-v06-articulated-core.blend','sha256':source_sha},
          'glb':{'file':'thetazine-v06-articulated-core.glb','sha256':glb_sha},
          'source_baseline':'../v05-mechanical-detail','working_frames':[1,64],'cold_frame':0,'wrap_frame':65,'fps':30,
          'source_saved_scene_range':[1,65],'actual_glb_export_range':[0,65],
          'physical_export':{'meshes':3202,'empty_nodes':21,'animation_channels':150,'source_only_combustion_volume_excluded':True},
          'runtime_status':'Ordinary native sprites remain V04/source35. No V06 sprite integration, native-client rerun, Git commit or publication is claimed.',
          'geometry_units':'Blender units (BU), not inferred real-world dimensions',
          'retained_contact_limits':last['acceptance_limit'],
          'files':copied,'clearance_scope':last.get('scope',last.get('clearance_limit','See exact scoped reports and inherited-contact classifications.'))}
(out/'canonical-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('V06_MODEL_ARCHIVE_COPIED_AND_HASH_VERIFIED',str(out),len(copied))
