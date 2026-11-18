"""Bind the actual repaired panel captures and native regression results."""
from pathlib import Path
import json,hashlib,shutil,zipfile
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';E=O/'approved-integration-evidence';B=R/'build/conclave-approved-integration';S=B/'user-data/script-output/conclave-center';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();runtime=R/'tech-priests_src/scripts/core/conclave_center_0558.lua';native=json.loads((S/'native-results.json').read_text());reload=json.loads((S/'reload-results.json').read_text());assert native['passed'] and reload['reloaded'] and reload['reload_inventory_preserved']
assert h(runtime)==h(B/'mods/tech-priests/scripts/core/conclave_center_0558.lua')
art=json.loads((O/'integration.json').read_text())['runtime_art']
for name,digest in art.items():
 assert h(R/'tech-priests_src/graphics/entity/conclave-center-v08'/name)==digest
 assert h(B/'mods/tech-priests/graphics/entity/conclave-center-v08'/name)==digest
receipts=[]
for folder,resolution in [('gui-compact',[922,599]),('gui-large',[1280,800])]:
 D=E/folder;binding=json.loads((D/'source-binding.json').read_text());assert binding['runtime_source_sha256']==h(runtime)
 for i in range(1,6):
  stem='layout-%dx%d-0.75-%d'%(*resolution,i);report=json.loads((D/(stem+'.json')).read_text());assert report['tab']==i;assert len(report['panes'])==5;assert all(p['horizontal_scroll_policy']=='never' and p['vertical_scroll_policy']=='auto' for p in report['panes']);assert report['panel_width']*report['scale']<=resolution[0]-24;assert report['panel_height']*report['scale']<=resolution[1]-24
  receipts.append(dict(resolution=resolution,tab=i,png=(D/(stem+'.png')).relative_to(O).as_posix(),png_sha256=h(D/(stem+'.png')),native_layout=report))
 binding['visual_review']='Viewed all five actual native tab images. Header, action buttons, data columns and timer fit; long doctrine-web content scrolls vertically.';(D/'source-binding.json').write_text(json.dumps(binding,indent=2)+'\n')
 physical=json.loads((D/'physical-governance.json').read_text());assert physical['passed'] and physical['physical_open_event']['entity_name']=='tech-priests-conclave-center'
for name in ('native-results.json','reload-results.json'):
 shutil.copy2(S/name,E/name)
for name in ('test','reload','dump'):
 shutil.copy2(B/(name+'.log'),E/(name+'.log'))
baseline=json.loads((O/'owner-approval.json').read_text());assert baseline['owner_approved'];assert baseline['source_sha256']==h(O/'conclave-center-v08.blend');assert baseline['export_sha256']==h(O/'conclave-center-v08.glb')
result=dict(passed=True,scope='Accepted Conclave V08 integration and production panel layout repair',owner_model_accepted=True,runtime_source_sha256=h(runtime),source_sha256=baseline['source_sha256'],export_sha256=baseline['export_sha256'],model_art_unchanged=True,changes=['Viewport budget accounts for actual GUI scale.','Status on its own row; action buttons on a separate full-width row.','All six tables have column-width budgets and wrapped labels; full captions retained as tooltips.','All five panes use vertical scrolling only.','Native sprite resizing disabled for the timer; image scales to a32 GUI-unit widget.','Live resolution/scale events rebuild an open panel while preserving selected tab.'],native_tab_captures=receipts,physical_open_verified=True,ordinary_four_sided_inserters=native['inserter_input']+native['inserter_output'],save_reload_verified=reload['reload_inventory_preserved'],limits=['Overview-button navigation was not separately exercised.','Live window-resize tab preservation was not separately exercised; distinct window sizes were tested.','This is scoped integration evidence, not whole-mod release certification.'])
(E/'layout-validation.json').write_text(json.dumps(result,indent=2)+'\n')
# A source integration payload, not a standalone or verified whole-mod release.
files=[runtime,R/'tech-priests_src/prototypes/conclave_center_0558.lua',R/'tech-priests_src/credits/Conclave-DGordillo-skull.txt']+sorted((R/'tech-priests_src/graphics/entity/conclave-center-v08').glob('*.png'))
delivery=B/'delivery';delivery.mkdir(exist_ok=True);path=delivery/'conclave-center-v08-source-integration.zip'
with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for p in files:archive.write(p,p.relative_to(R).as_posix())
 archive.writestr('README.txt','Accepted Conclave V08 source integration payload. The current production tree already contains these files. Includes the panel layout repair and art; excludes private test add-ons. This is not a standalone Factorio mod or a certified whole-mod release.\n')
 archive.writestr('manifest.json',json.dumps({p.relative_to(R).as_posix():h(p) for p in files},indent=2))
with zipfile.ZipFile(path) as archive:assert archive.testzip() is None
(E/'integration-payload.json').write_text(json.dumps(dict(path=path.relative_to(R).as_posix(),sha256=h(path),contents={p.relative_to(R).as_posix():h(p) for p in files},classification='Source integration payload; no whole-mod release claim'),indent=2)+'\n')
print('CONCLAVE_LAYOUT_NATIVE_VALIDATION_PASS',len(receipts),'tab captures; payload',path)
