"""Verify the bounded actual particle/energy pilot without claiming final art fit."""
import argparse,hashlib,json,pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent;REPO=HERE.parents[3]
try:from PIL import Image
except ImportError:
 sys.path.insert(0,str(REPO.parent/'local-validation/deps'));from PIL import Image
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=pathlib.Path);a=p.parse_args();R=a.directory.resolve();j=json.loads((R/'capture-receipt.json').read_text());pkg=json.loads((R/'package-validation.json').read_text());N=j['timeline']['output_frames'];frames={f['index']:f for f in j['frames']if f['layer']=='field'};assert 0 in frames and N in frames
assert pkg['rendered_wrap'].get('field')is True and pkg['rendered_wrap'].get('working_light')is True
assert pkg['physical_coverage_witness_exact']is True and pkg['working_energy_preserves_body_coverage']is True
assert sha(j['input_glb']['path'])==j['input_glb']['sha256'];assert all(f['physical_digest']==j['physical_digest']for f in j['frames'])
next_index=min(i for i in frames if 0<i<N);first={v['object']:v for v in frames[0]['plume_state']};later={v['object']:v for v in frames[next_index]['plume_state']};axis=j['plume']['axis'];motion=[]
for name,v in first.items():
 w=later[name]
 if v.get('core'):continue
 if w['age_fraction']>v['age_fraction']:
  displacement=sum((w['position'][i]-v['position'][i])*axis[i]for i in range(3));assert displacement>0,('Nonrecycled particle did not advect downstream',name)
  motion.append({'object':name,'actual_axial_displacement':displacement,'age_before':v['age_fraction'],'age_after':w['age_fraction']})
assert motion
white_clipped=0
for f in frames.values():
 with Image.open(R/f['file'])as im:
  im=im.convert('RGBA');im.load();white_clipped+=sum(px[3]>0 and px[:3]==(255,255,255)for px in im.getdata())
assert white_clipped==0,'White-clipped ejecta pixel found'
anchors=[row for arc in j['arcs']['arcs']for row in(arc['a'],arc['b'],arc.get('branch'))if row]
native=REPO/'docs/art/thruster-resumption-20261117/animation-capture/native-power/validation.json'
report={'status':'PASS_BOUNDED_CORE_ADVECTING_EJECTA_ENERGY_PILOT','body_glb_sha256':j['input_glb']['sha256'],'recipe':'V03compactaperturecore +sparseadvectingglints +featheredturbulentbillows +wholebodyactualsurfacecrackle +newactualdishrimworkingFX','particle_count':j['plume']['particle_count'],'advecting_wisp_count':j['plume']['wisp_count'],'aperture_core_count':j['plume'].get('aperture_core_count',0),'actual_nonrecycled_downstream_movers':len(motion),'measured_motion':motion,'first_compared_phases':[0,next_index],'actual_rendered_wrap':pkg['rendered_wrap'],'actual_physical_coverage_witness_exact':True,'actual_working_energy_preserves_body_coverage':True,'actual_surface_arc_count':len(j['arcs']['arcs']),'actual_surface_ray_max_error':max(v['actual_local_surface_ray_error']for v in anchors),'new_emitter_energy_status':j['emitter_energy']['status'],'white_clipped_ejecta_pixels':white_clipped,'field_renderer':frames[0]['renderer'],'field_renderer_settings':frames[0]['eevee_settings'],'stable_scene_evaluation_frame':frames[0]['scene_evaluation_frame'],'captured_phases':sorted(frames),'brightness_contract':j['brightness_contract'],'separate_native_draw_control_evidence':{'path':str(native),'sha256':sha(native)}if native.exists()else None,'input_bindings':j['binding'],'scope':['Actual sourceRGBAfirst/wrap, physicalcoverage, downstreamposition witnesses and boundedsourceappearancepilot.','Nativeperenginepower/tintcontrol is separatelytested in parentnative-power evidence; finaldetailedbody/spriteappearance integration remains pending.','Newfunctional-detailbodypins are required beforefinal64sourcecapture. No oldbody is represented as the finalupdatedasset.','Agentvisualdirectionacceptedforcapturestage; ownerfinalappearanceacceptance andphysicalfluid/backgroundrefractionsimulation are not asserted.']}
(R/'advecting-pilot-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],len(motion),'actualmovers',len(j['arcs']['arcs']),'surfacearcs',white_clipped,'whiteclipped')
