"""Bind explicit interface adjudication to final source and actual GLB sweeps."""
from pathlib import Path
import json,re,hashlib
from review_fixed_interfaces import decisions
R=Path(__file__).resolve().parent;A=R/'authored-v12'if(R/'authored-v12').is_dir()else R
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
approved={d['interface']:d for d in decisions.values()if d['decision']=='intentional-fixed-interface'}
rejected={d['interface']:d for d in decisions.values()if d['decision']=='repair-required-must-be-absent'}
added={}
def allow(a,b,reason):added[' <> '.join(sorted((a,b)))]={'decision':'intentional-fixed-interface','reason':reason,'review_basis':'Final fitted candidate construction and actual source/runtime contact inventory.'}
for a,b in[
 ('opaque vaulted manufacturing nave','tower facade protected service line'),('facade clamp tower standoff','opaque vaulted manufacturing nave'),
 ('bundle founded twin-entry manifold','opaque vaulted manufacturing nave'),('closed front service tower','console founded support'),
 ('bundle founded twin-entry manifold','closed front service tower'),('bundle founded twin-entry manifold','tower corner load rib'),
 ('bundle founded twin-entry manifold','front tower founded cast boot'),('bundle founded twin-entry manifold','nave left roof load rib'),
 ('bundle founded twin-entry manifold','nave right roof load rib'),('bundle founded twin-entry manifold','facade service column founded plinth'),
 ('crown maintenance pad','supported tower crown')]:
 allow(a,b,'Fitted stationary entry/support casting seats into its opaque tower/nave or actual joined load rib/base. The entry block bridges the existing enclosure edge and contains the tube terminations. Set-back console feet and newly exposed maintenance pads retain contact with their structural host.')
allow('bundle founded twin-entry manifold','tower facade protected service line','The two separate protected lines terminate inside their founded closed entry block. These are intentional body entries; no native fluid socket is added.')
allow('facade bundle split clamp','facade clamp tower standoff','The extended saddle ends seat in the outer clamp wall while remaining clear of the protected tube and its bore. Each bracket shares a founded support root; it is not a moving link.')
allow('facade clamp tower standoff','facade clamp tower standoff','The two fixed bracket arms form a joined fork at their common mounting root. This is one stationary support casting/load path, not a crossing of independently moving links.')
allow('crown cassette rim fastener','crown thermal cassette seated rim','Relocated heads now seat on free rim corners, with a gap to the independent end fins. The former bolt/fin interference is rejected and must be absent.')
allow('crown cast stepped service tablet','crown tablet twin embossed trace','Embossed trace strips deliberately seat on their parent cast tablet. Exact seam/coplanar seating changes triangle-contact reporting after GLB transforms; source/runtime pose bounds independently match.')
allow('roof exchanger upright cooling fin','sealed roof heat-exchanger core','Cooling fins seat against their own sealed thermal core as fixed butt joints. These are the pre-existing source/core seams; export floating-point transforms can turn exact coplanar seats into tiny triangle contacts.')
for a,b in[
 ('tower armor stud seated shank','tower facade armor stud'),('tower armor stud seated shank','closed front service tower'),
 ('tower armor stud seated shank','front tower founded cast boot'),
 ('tower armor stud seated shank','FMPL recovered console console / service interface casting'),
 ('tower armor stud seated shank','FMPL recovered console console cast side extension'),
 ('main arch pressure stud seated shank','main arch pressure ring stud'),('main arch pressure stud seated shank','heavy main door pressure arch'),
 ('main arch pressure stud seated shank','facade consecrated inspection seal'),('main arch pressure stud seated shank','facade cog inspection seal')]:
 allow(a,b,'An explicit retained fastener stem joins its visible head to the actual fixed supporting casting. Where a fixed inspection seal/console casting already overlaps the host plate, the same stem retains that stacked stationary mounting interface; no moving clearance is consumed.')

for a,b in[
 ('bundle founded twin-entry manifold','side riser split clamp'),('bundle founded twin-entry manifold','side riser wall standoff'),
 ('bundle founded twin-entry manifold','founded side shoe articulated clamp'),('bundle founded twin-entry manifold','side shoe clamp stud'),
 ('bundle founded twin-entry manifold','tower facade armor stud'),('facade clamp tower standoff','tower facade protected service line'),
 ('facade service column founded plinth','tower facade protected service line')]:
 rejected[' <> '.join(sorted((a,b)))]={'reason':'Independent visible hardware clearance: final narrowed entry blocks and outer-wall saddles must not intersect these neighbouring fittings/tubes.'}
moving_allowed={
 'fan retained blade root <> fan rotating bored hub':'Retained blade roots join the rotating hub in the same rigid rotor.',
 'fan outer vane <> fan retained blade root':'Vane joins its own retained blade root in the same rotor.',
 'pressure needle bored retained hub <> pressure needle pointer':'Pointer is attached to its own moving retained hub.'}
reports=[];unknown=set();bad={};all_rows=[]
for file,artifact in[('clearance-raw.json','citadel-v12.blend'),('clearance-runtime-raw.json','citadel-v12.glb')]:
 raw=json.loads((A/file).read_text());assert raw['sha256']==sha(A/artifact);assert raw['includes_half_frames']
 owners=raw['motion_owners'];counts={};foreign=[];unreviewed=[];repaired_still_present=[];adjudicated=[]
 for pair,data in raw['pairs'].items():
  names=pair.split(' <> ');key=' <> '.join(sorted(re.sub(r'\.\d+$','',n).replace('CITADEL | ','')for n in names))
  if data['moving']:
   if len({owners[n]for n in names})>1:foreign.append(pair)
   elif key not in moving_allowed:unreviewed.append(pair)
   else:adjudicated.append({'exact_pair':pair,'type':key,'decision':'same-rigid-motion-attachment','reason':moving_allowed[key]})
  elif key in rejected:repaired_still_present.append(pair)
  elif key not in approved and key not in added:unreviewed.append(pair);unknown.add(key)
  else:
   decision=added.get(key)or approved[key];adjudicated.append({'exact_pair':pair,'type':key,'decision':'intentional-fixed-interface','reason':decision['reason']});counts[key]=counts.get(key,0)+1
 report={'raw_report':file,'artifact_sha256':raw['sha256'],'sampled_poses':raw['sampled_poses'],'half_frames':True,'moving_meshes':len(raw['moving_meshes']),'raw_contact_pairs':len(raw['pairs']),'adjudicated_pairs':len(adjudicated),'fixed_interface_types':len(counts),'foreign_moving_contacts':foreign,'unreviewed_contacts':unreviewed,'repaired_unwanted_contacts_still_present':repaired_still_present,'decisions':adjudicated,'passed':not foreign and not unreviewed and not repaired_still_present}
 reports.append(report);bad[file]={'foreign':foreign,'unreviewed':unreviewed,'repaired_still_present':repaired_still_present}
summary={'passed':all(r['passed']for r in reports),'source_sha256':sha(A/'citadel-v12.blend'),'runtime_sha256':sha(A/'citadel-v12.glb'),'scope':'Every raw source/runtime contact has an explicit reviewed interface decision. Intended fixed structural/fastener/casting seats and same-rigid-motion attachments remain present; unwanted interfaces must be absent. No pair is excluded from the raw collision inventories.','v11_basis_reviewed_types':len(decisions),'prior_unwanted_interface_types_rejected':len(rejected),'source_runtime_reports':reports,'owner_visual_approved':False}
(A/'clearance-review.json').write_text(json.dumps(summary,indent=2)+'\n')
print('CITADEL_FINAL_CLEARANCE',json.dumps({'passed':summary['passed'],'unknown_types':sorted(unknown),'failures':bad,'counts':[{'artifact':r['raw_report'],'raw_pairs':r['raw_contact_pairs'],'adjudicated':r['adjudicated_pairs']}for r in reports]}),flush=True)
assert summary['passed']
