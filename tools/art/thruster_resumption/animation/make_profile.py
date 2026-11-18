"""Bind a validated body and owner's measured installation/aperture handoff."""
import argparse,hashlib,json,pathlib

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--glb',type=pathlib.Path,required=True);p.add_argument('--validation',type=pathlib.Path,required=True);p.add_argument('--geometry',type=pathlib.Path,required=True);p.add_argument('--prototype',choices=['void-fusion-thruster','large-void-fusion-thruster'],required=True);p.add_argument('--stage',choices=['PILOT_TOOLING','FINAL_CAPTURE_CANDIDATE'],required=True);p.add_argument('--frames',type=int,choices=[16,64],default=64);p.add_argument('--size',type=int,choices=[512,768,1024]);p.add_argument('--samples',type=int,default=64);p.add_argument('--field-engine',choices=['BLENDER_EEVEE','CYCLES'],default='BLENDER_EEVEE');p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();a.size=a.size or(768 if a.stage=='FINAL_CAPTURE_CANDIDATE'else 512)
glb=a.glb.resolve();v=a.validation.resolve();g=a.geometry.resolve();geom=json.loads(g.read_text());validation=json.loads(v.read_text());digest=sha(glb)
assert str(geom.get('status','')).startswith('PASS')and str(validation.get('status','')).startswith('PASS')
assert digest in json.dumps(geom)and digest in json.dumps(validation),'Geometry/validation handoff does not bind current body GLB'
cut=.5 if a.prototype=='void-fusion-thruster'else 1
if 'projector_mesh'in geom:
 # The narrow owner supplies two separately measured/exported handoffs.
 service_path=g.parent/'service-underlay-receipt.json';service=json.loads(service_path.read_text());assert str(service.get('status','')).startswith('PASS')and service['body_glb_sha256']==digest
 ap={'actual_mesh':geom['projector_mesh'],'positive_face_plane_point':geom['aperture_center_source'],'measured_center':geom['aperture_center_source'],'outward_axis':geom['outward_axis_source'],'measured_inner_radius':geom['aperture_radius_source'],'separate_downstream_FX_origin':[geom['aperture_center_source'][0],geom['central_projecting_tip_aftmost_y']-.025,geom['aperture_center_source'][2]]}
 geom={'source_edge':{'native_cut':cut},'aperture':ap,'service_underlay':{'glb':service.get('underlay_glb','narrow-service-underlay.glb'),'sha256':service['underlay_glb_sha256'],'source_meshes':[],'exclude_these_from_body_layer':False,'shadow_receiver_polygons':[{'xy':poly}for poly in service['receiver_xy_polygons']]}}
assert geom['source_edge']['native_cut']==cut
under=geom['service_underlay'];under_path=(g.parent/under['glb']).resolve();assert sha(under_path)==under['sha256']
ap=geom['aperture'];center=ap.get('positive_face_plane_point')or ap['measured_center'];fx_origin=ap.get('separate_downstream_FX_origin')or center
cfg={'prototype':a.prototype,'stage':a.stage,'glb':str(glb),'glb_sha256':digest,'validation':{'path':str(v),'sha256':sha(v)},'source_size':a.size,'samples':a.samples,'output_frames':a.frames,'native_pixels_per_source_unit':32,'native_cut_y':cut,'minimum_ortho_scale':8,'registration_status':'EXPLICIT_CANDIDATE_32_NATIVE_PIXELS_PER_BU_REQUIRES_NATIVE_FIT','geometry_handoff':{'path':str(g),'sha256':sha(g)},'body_exclude':under['source_meshes']if under.get('exclude_these_from_body_layer')else[],'underlay':{'glb':str(under_path),'sha256':under['sha256']},'deck_receiver_polygons':[r['xy']for r in under['shadow_receiver_polygons']],'aperture':{'mesh':ap['actual_mesh'],'center':center,'axis':ap['outward_axis'],'radius':ap['measured_inner_radius'],'effect_origin':fx_origin,'validation':{'path':str(g),'sha256':sha(g)}},'field_length':2,'field_radius':.25}
cfg['light_exposure']=-3
cfg['denoise_cold']=True;cfg['field_engine']=a.field_engine;cfg['effects_mode']='ADVECTING_PARTICLES_AND_POWER_LINKED_CRACKLE'
if 'service_path'in locals():cfg['underlay']['validation']={'path':str(service_path),'sha256':sha(service_path)}
assert not a.out.exists(),'Refuse to overwrite a pinned profile';a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(cfg,indent=2)+'\n');print(a.out.resolve())
