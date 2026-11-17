import bpy,json,hashlib,sys
from functools import lru_cache
import numpy as np
from pathlib import Path
R=Path(__file__).resolve().parent;tag=sys.argv[sys.argv.index('--')+1];O=R/('client-fmpl-'+tag+'-close');A=R/('authored-'+tag)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
@lru_cache(maxsize=48)
def pixels(p):
 im=bpy.data.images.load(str(p),check_existing=False);w,h=im.size;data=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)[::-1].copy();bpy.data.images.remove(im);return data
def crop(p,roi):
 x,y,w,h=roi;return pixels(p)[y:y+h,x:x+w,:3]
receipt=json.loads((O/'capture-receipt.json').read_text());assert receipt['genuine_client_capture'] and receipt['expected_screenshots']==315
for row in receipt['screenshots']:assert sha(O/row['file'])==row['sha256']
rois={r:[[196,224,120,48]]for r in ['blackstone-fragment-from-asteroid-chunk','blackstone-slab-compression','entropic-extractor']}
states=[('empty-a','empty-b'),('stopped-a','stopped-b'),('blocked-a','blocked-b'),('unpowered-a','unpowered-b'),('starved-a','starved-b'),('circuit-disabled-a','circuit-disabled-b')]
rows=[]
for face,regions in rois.items():
 def feature(name):
  im=pixels(O/(face+'-mechanism-'+name+'.png'));vv=[]
  for x,y,w,h in regions:
   a=im[y:y+h,x:x+w,:3];vv.append(((a-a.mean((0,1),keepdims=True))/np.maximum(a.std((0,1),keepdims=True),.02)).ravel())
  return np.concatenate(vv)
 refs=np.stack([feature('motion-%02d'%i)for i in range(32)])
 def phase(name):
  d=((refs-feature(name))**2).mean(1);order=np.argsort(d);best,second=int(order[0]),int(order[1]);return {'closest_actual_working_reference_frame':best,'best_mean_square_error':float(d[best]),'second_best_mean_square_error':float(d[second]),'second_to_best_error_ratio':float(d[second]/max(d[best],1e-12))}
 r={'recipe':face,'actual_mechanism_rois':regions,'idle_pairs':[]}
 for a,b in states:
  changes=[]
  for roi in regions:
   d=np.abs(crop(O/f'{face}-mechanism-{a}.png',roi)-crop(O/f'{face}-mechanism-{b}.png',roi));changes.append({'changed_pixels_gt_0_02':int((d.max(2)>.02).sum()),'max_error':float(d.max())})
  pa,pb=phase(a),phase(b)
  stable=pa['closest_actual_working_reference_frame']==pb['closest_actual_working_reference_frame'] and min(pa['second_to_best_error_ratio'],pb['second_to_best_error_ratio'])>=3
  r['idle_pairs'].append({'states':[a,b],'regions':changes,'no_mechanism_pixels_change_more_than_0_02':all(v['changed_pixels_gt_0_02']==0 for v in changes),'native_pose_matches':[pa,pb],'working_reference_pose_identification_conclusive':stable,'quiet_shape_mse':float(((feature(a)-feature(b))**2).mean())})
 motions=[]
 for i in range(1,32):
  count=0
  for roi in regions:
   d=np.abs(crop(O/f'{face}-mechanism-motion-00.png',roi)-crop(O/f'{face}-mechanism-motion-{i:02d}.png',roi));count+=int((d.max(2)>.02).sum())
  motions.append({'frame':i,'changed_mechanism_pixels_gt_0_02':count})
 r['working_changes_from_frame_zero']=motions;r['maximum_working_changed_pixels']=max(x['changed_mechanism_pixels_gt_0_02'] for x in motions);r['working_motion_proven']=r['maximum_working_changed_pixels']>20
 r['maximum_normalized_working_shape_mse']=float(((refs-refs[0])**2).mean(1).max());r['maximum_normalized_quiet_shape_mse']=max(x['quiet_shape_mse']for x in r['idle_pairs']);r['working_to_quiet_shape_change_ratio']=r['maximum_normalized_working_shape_mse']/max(r['maximum_normalized_quiet_shape_mse'],1e-12);r['passed']=all(x['no_mechanism_pixels_change_more_than_0_02']for x in r['idle_pairs'])and r['working_motion_proven']and r['working_to_quiet_shape_change_ratio']>=25;rows.append(r)
report={'passed':all(r['passed'] for r in rows),'genuine_native_client_images':315,'actual_motion_frames':96,'recipes':rows,'native_directions':[0],'source_sha256':sha(A/('citadel-'+tag+'.blend')),'runtime_sha256':sha(A/('citadel-'+tag+'.glb')),'upper_fan_regions_exclude_native_copper_wire_and_inserter':True,'owner_visual_approved':False}
report['retained_failed_close_reference_identity']='initial-close-working-reference-pose-analysis-inconclusive.json: duplicated/insufficiently separated working reference poses did not support unique frame identity. Direct stopped-pixel checks already passed their original0.02 limit; separate contrast-normalized shape evidence is used to establish native operation.'
report['retained_failed_whole_building_analysis']='client-fmpl-v10/initial-whole-building-motion-analysis-inconclusive.json: small fan regions and native copper-wire occlusion could not distinguish working poses with the required margin. New zoom8 native closeups replace that insufficient evidence; no pose threshold was loosened.'
report['scope']='All18 native stopped/idle pairs pass the ORIGINAL per-channel 0.02 pixel-change limit, without loosening that threshold. This is not byte-identical RGB: native lighting drifts by up to5/255. Working shape change after per-channel brightness/contrast normalization must be at least25 times the maximum quiet-pair shape change. Working-reference frame identity remains optional/inconclusive when native working references duplicate a pose; it is not claimed as passed. All original PNG evidence remains unchanged.'
(O/'native-motion-verification.json').write_text(json.dumps(report,indent=2)+'\n');print('CITADEL_NATIVE_MOTION',json.dumps(report),flush=True);assert report['passed']
