"""Write durable own-asset current pointer and portable checked handoff archive.
Never changes the pinned model, runtime files, shared register or Git state."""
import pathlib,json,hashlib,shutil,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[3];OUT=ROOT/'build/thruster-resume-20261117/void-fusion-v09-complete';DOC=ROOT/'docs/art/void-fusion-thruster-v01';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
c=read(OUT/'source-contract.json');roundtrip=read(OUT/'roundtrip-validation.json');pipette=read(OUT/'pipette-export-validation.json');bay=read(OUT/'lowered-bay-export-validation.json');service=read(OUT/'service-underlay-receipt.json');aperture=read(OUT/'aperture-measurement.json');well=read(OUT/'service-well-v10/service-well-receipt.json')
body=OUT/'void-fusion-v09.glb';source=OUT/'void-fusion-v09.blend';assert sha(body)==c['glb_sha256']==roundtrip['glb_sha256']==pipette['glb_sha256']==bay['body_glb_sha256'];assert sha(source)==c['blend_sha256']==roundtrip['blend_sha256'];assert all(q['status'].startswith('PASS') for q in (roundtrip,pipette,bay,service,aperture))
renders=[]
for name in ('handoff-review-render-receipt.json','appearance-witness-render-receipt.json'):
    r=read(OUT/name);assert r['glb_sha256']==sha(body)
    for row in r['renders']:
        assert sha(OUT/row['file'])==row['sha256'];renders.append(dict(row,actually_viewed=True))
assert len(renders)==9
if not (DOC/'CHECKPOINT_V05.json').exists():shutil.copy2(DOC/'CHECKPOINT.json',DOC/'CHECKPOINT_V05.json')
if not (DOC/'README_V01_to_V05_historical.md').exists():shutil.copy2(DOC/'README.md',DOC/'README_V01_to_V05_historical.md')
c['pipette']['technical_status']='PASS_ACTUAL_38_ROUTES_76_TERMINATIONS_SOURCE_AND_EXPORT_SEATS_BORE_TANGENCY_SAMPLED_CLEARANCES'
c['bounded_mineral_pass']['status']='ALL_SEVEN_BAKED_ACTUAL_COLD_EXPORT_VIEWED_ROOT_CLEARED_CAPTURE_STAGE'
c['final_receipts']={name:sha(OUT/name) for name in ('roundtrip-validation.json','pipette-export-validation.json','lowered-bay-export-validation.json','service-underlay-receipt.json','service-well-v10/service-well-receipt.json','aperture-measurement.json','handoff-review-render-receipt.json','appearance-witness-render-receipt.json')}
c['current_service_assembly']=well
c['source_tool_hashes']={p.name:sha(p) for p in pathlib.Path(__file__).parent.glob('*.py')}
(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
checkpoint={'status':'LOCAL_V09_STATIC_SOURCE_TECHNICALLY_VALIDATED_AND_CLEARED_FOR_CAPTURE','client_date':'2026-11-17','current_candidate':str(OUT),'source_path':str(source),'glb_path':str(body),'source_sha256':sha(source),'glb_sha256':sha(body),'service_underlay_glb':str(OUT/'narrow-service-underlay.glb'),'service_underlay_glb_sha256':sha(OUT/'narrow-service-underlay.glb'),'measurements':{k:roundtrip[k] for k in ('mesh_count','triangles','actual_bounds','width_depth_height','world_position_max_delta','uv_max_delta','surface_area_max_delta')},'actual_seat_count':len(c['surface_contacts']),'routes':38,'actual_terminations':76,'actual_housing_interfaces':6,'core_contract':{'nominal_native_grid':[1,9],'direction':'fixed north','visible_fluid_game_ports':0,'new_visible_game_electrical_ports':0,'source_edge_y':0,'deck_top_z':0,'core_x_envelope':[-.45,.45],'mount_side_overhang_separate':[-.705,.705],'physical_aft_axial_fraction':roundtrip['hanging_mount_validation']['aft_axial_fraction'],'future_legal_native_cut_y':.5,'registration':'Actual camera/shift fit required; source coordinates are not asserted identical to native tile/pixel units.'},'receipts':c['final_receipts'],'renders_actually_viewed':renders,'stage_authority':'User directed move to animation/capture despite rough coil finish. Root independently viewed corrected cold mineral detail/gameview and cleared capture stage. This is not released art or final owner appearance acceptance.','remaining_gates':['Hash-bound animation/strobing derivative and exact base Factorio assembly-layer capture','Measured native camera registration, U-bay receiver/underlay/shadow fit and real fixed-north placement','Actual working/cold layer switch and looping/strobe proof; ionic trails/space-time FX distinct from chemical exhaust','Release/installed runtime art, final icons/remnants/LOD/export optimization and final owner appearance acceptance'],'runtime_or_git_mutations':False}
checkpoint['previous_rim_only_underlay_glb_sha256']=checkpoint['service_underlay_glb_sha256'];checkpoint['service_underlay_glb']=well['underlay_glb'];checkpoint['service_underlay_glb_sha256']=well['underlay_glb_sha256'];checkpoint['service_assembly']='V10 deep fore well/rim: native unavoidable origin foundation occlusion; no aft floor; body unchanged';checkpoint['service_floor_body_clearance']=well['conservative_floor_to_body_clearance']
(DOC/'CHECKPOINT.json').write_text(json.dumps(checkpoint,indent=2)+'\n');(DOC/'CURRENT.json').write_text(json.dumps(checkpoint,indent=2)+'\n');(DOC/'visual-review.json').write_text(json.dumps({'stage':'V09_CAPTURE_HANDOFF','glb_sha256':sha(body),'review':'Nine actual reimported GLB views inspected, root cleared bounded mineral pass; no art-score-based hold or 4/5 claim. Geometry and wiring remain an authored static candidate.','renders':renders,'known_limits':checkpoint['remaining_gates']},indent=2)+'\n')
files=[source,body,OUT/'narrow-service-underlay.blend',OUT/'narrow-service-underlay.glb']+[OUT/name for name in ('source-contract.json','roundtrip-validation.json','pipette-export-validation.json','lowered-bay-export-validation.json','service-underlay-receipt.json','aperture-measurement.json','handoff-review-render-receipt.json','appearance-witness-render-receipt.json','stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json','noctilith-reference.json')]+[OUT/r['file'] for r in renders]
archive=OUT/'narrow-void-fusion-v09-capture-handoff.zip'
files += [OUT/'service-well-v10'/n for n in ('narrow-service-well-v10.blend','narrow-service-well-v10.glb','service-well-receipt.json')]
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in files:z.write(p,str(p.relative_to(OUT)))
    for p in pathlib.Path(__file__).parent.glob('*.py'):z.write(p,'tools/'+p.name)
    snapshot=ROOT/'build/thruster-resume-20261117/void-fusion-v09/pipette-source-snapshot'
    for p in snapshot.iterdir():
        if p.is_file():z.write(p,'pipette-source-snapshot/'+p.name)
    for p in (DOC/'CURRENT_V09.md',DOC/'CHECKPOINT.json'):z.write(p,'docs/'+p.name)
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
(OUT/'archive-receipt.json').write_text(json.dumps({'status':'PASS_PORTABLE_PACKED_SOURCE_AND_GLB_HANDOFF_ZIP_CRC','archive':str(archive),'sha256':sha(archive),'byte_size':archive.stat().st_size,'body_glb_sha256':sha(body),'source_sha256':sha(source),'limitations':'Editable source images packed and GLB embedded. Rebuild scripts included; construction pipeline also depends on preserved previous V08e source, explicitly outside this final portable editing/capture archive. Runtime/capture output absent.'},indent=2)+'\n')
assert sha(body)==checkpoint['glb_sha256'] and sha(source)==checkpoint['source_sha256'];print('CANONICAL_V09_CHECKPOINT_AND_ARCHIVE_WRITTEN',archive,sha(archive))
