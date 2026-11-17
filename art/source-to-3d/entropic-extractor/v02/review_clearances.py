"""Explicit reviewed construction seats; independent motion must remain clear."""
from pathlib import Path
import json,re,hashlib
A=Path(__file__).resolve().parent;decisions={}
def group(reason,text):
 for line in text.strip().splitlines():decisions[' <> '.join(sorted(line.strip().split(' <> ')))]=reason
group('Stationary founded casting/support seats; the common deck carries these joined loads.', '''
closed blackstone conversion mantle <> core founded shoe
core founded shoe <> founded structural rib
core founded shoe <> thermal casting founded shoe
core founded shoe <> fuel vestibule founded casing
core founded shoe <> rear casket founded support foot
closed blackstone conversion mantle <> sealed roof casting
closed blackstone conversion mantle <> mantle seated retaining band
closed blackstone conversion mantle <> founded structural rib
closed blackstone conversion mantle <> sealed surface cassette
closed blackstone conversion mantle <> fuel vestibule founded casing
mantle seated retaining band <> sealed roof casting
founded structural rib <> sealed roof casting
founded structural rib <> mantle seated retaining band
fuel vestibule founded casing <> mantle seated retaining band
founded structural rib <> fuel vestibule founded casing
closed lower service tablet <> fuel vestibule founded casing
closed thermal side casting <> thermal casting founded shoe
closed rear regulating casket <> rear casket load leg
rear casket founded support foot <> rear casket load leg
''')
group('Stationary retained fastener seats in the actual bracket, rib, rim or cover; pylon corner anchors retain the overlapping foot/flange edge.', '''
deck corner bracket <> deck foundation anchor
sealed roof casting <> upper shell retained stud
founded structural rib <> rib retained band stud
pylon foot anchor <> pylon forged end retainer
thermal rail fastener <> thermal retaining rail
closed rear regulating casket <> rear casket retaining screw
''')
group('Fixed opaque pane is seated in its blind cassette; jamb/sill/muntin/crossbar junctions form one retained lattice.', '''
opaque blind green core window <> sealed surface cassette
opaque blind green core window <> seated window jamb
opaque blind green core window <> sealed window sill
green pane retained tracery <> opaque blind green core window
opaque blind green core window <> seated blind glazing crossbar
sealed window sill <> seated window jamb
seated blind glazing crossbar <> seated window jamb
green pane retained tracery <> seated blind glazing crossbar
''')
group('Embossed relief is cast/seated on its own stationary tablet or roof.', '''
closed lower service tablet <> tablet raised retaining edge
closed lower service tablet <> tablet embossed runic rib
radial roof casting relief <> sealed roof casting
''')
group('Founded pylon stack and supported winding: stave roots seat in ceramic core and end retainers; winding touches its ceramic staves and terminates under the upper retained crown.', '''
pylon forged end retainer <> pylon founded foot
pylon ceramic core <> pylon forged end retainer
pylon ceramic core <> pylon coil support stave
pylon coil support stave <> pylon forged end retainer
pylon continuous supported copper winding <> pylon forged end retainer
pylon coil support stave <> pylon continuous supported copper winding
''')
group('Thermal fins are embedded into their own closed casting and fixed retaining rails.', '''
closed thermal side casting <> seated external thermal fin
seated external thermal fin <> thermal retaining rail
''')
group('Closed fuel cover seats on its vestibule; captured hinge and latch are stationary while the generator operates.', '''
closed fragment fuel hatch <> fuel vestibule founded casing
closed fragment fuel hatch <> fuel hatch captured hinge
closed captive latch <> fuel hatch latch seat
''')
group('Sealed indicator lens sits in its own fixed bezel.', 'rear blind indicator seat <> rear green sealed indicator')
group('Fixed shaft is founded in the opaque backing; axial washers/retainer seat on the shaft. Grille bars terminate in the stationary rim.', '''
fan opaque backplate <> fixed fan shaft
fixed fan shaft <> shaft retained axial washer
fixed fan shaft <> shaft top seated retainer
fan guard grille retained rim <> fixed fan guard grille
''')
rows=[]
for fn,artifact in [('clearance-raw.json','entropic-v02.blend'),('clearance-runtime-raw.json','entropic-v02.glb')]:
 d=json.loads((A/fn).read_text());assert d['sha256']==hashlib.sha256((A/artifact).read_bytes()).hexdigest();unknown=[];foreign=[];reviewed=[]
 for pair,r in d['pairs'].items():
  names=pair.split(' <> ');key=' <> '.join(sorted(re.sub(r'\.\d+$','',n).replace('ENTROPIC | ','')for n in names));key=re.sub(r'pylon [-0-9.]+ [-0-9.]+ ','pylon ',key)
  if r['moving']:
   if len({d['motion_owners'][n]for n in names})!=1:foreign.append(pair)
   if key!='bored rotor hub <> fan rigid blade':unknown.append(pair)
   reason='Six fan blade roots join the same bored rotating hub; no independent moving/stationary contact.'
  else:
   reason=decisions.get(key)
   if reason is None:unknown.append(pair)
  reviewed.append({'pair':pair,'interface':key,'reason':reason})
 rows.append({'artifact':artifact,'sha256':d['sha256'],'sampled_poses':d['sampled_poses'],'half_frames':True,'contact_count':len(d['pairs']),'foreign_moving_contacts':foreign,'unreviewed':unknown,'reviewed':reviewed,'passed':not unknown and not foreign})
r={'passed':all(x['passed']for x in rows),'reports':rows,'fixed_interface_types_reviewed':len(decisions),'rejected_v01_interfaces':['rear casket against green pane/window bars/band studs','pylon foot anchors against ceramic core','fuel door fasteners against hinges'],'owner_visual_approved':False};(A/'clearance-review.json').write_text(json.dumps(r,indent=2));print('ENTROPIC_CLEARANCE',r['passed'],[(x['contact_count'],len(x['unreviewed']))for x in rows]);assert r['passed']
