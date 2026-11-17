"""Continued owner-requested greeble refinement: layered exterior service networks."""
before=begin_zone()
for sign in(-1,1):
 x=sign*1.17
 points=[(x,-2.085,.64),(x,-2.17,.64)]
 for k in range(1,97):
  phase=math.tau*3*k/96;points.append((x+.115*math.sin(phase),-2.17-.015*math.sin(phase),.64+1.86*k/96))
 points.append((x,-2.085,2.50));route('facade braided armored instrument loom',points,.012,iron,seg=16)
 for z in(.64,2.50):
  C('armored loom seated termination gland',(x,-2.100,z),.030,.060,bronze,'Y',seg=24)
  C('loom gland retained hex collar',(x,-2.133,z),.035,.025,steel,'Y',seg=6)
 # Each split clamp follows the actual cable tangent, with a front-seated
 # cantilever saddle from the service column. No loose clips at nominal X.
 for z in(.84,1.16,1.49,1.82,2.15,2.43):
  phase=math.tau*3*(z-.64)/1.86
  point=Vector((x+.115*math.sin(phase),-2.17-.015*math.sin(phase),z))
  tangent=Vector((.115*math.tau*3/1.86*math.cos(phase),-.015*math.tau*3/1.86*math.cos(phase),1)).normalized()
  route('loom cable fitted tangent split clamp',[tuple(point-tangent*.023),tuple(point+tangent*.023)],.026,steel,.016,seg=24)
  beam('loom clamp front-seated cantilever saddle',(x,-2.111,z),point+Vector((0,.023,0)),.025,.025,bronze)
  C('loom saddle column retained anchor',(x,-2.120,z),.028,.025,iron,'Y',seg=6)

end_zone(before,'braided-facade-instrument-looms','Armored instrumentation looms terminate in seated glands on the existing closed service columns, with retained saddles. Manufacturing internals remain concealed.')

# Raised, framed service arches cross the roof, each supported from an existing
# dorsal clamp and terminated at a sealed crown cartridge. Paired signal lines
# stay separated from the larger service pipe rather than intersecting it.
before=begin_zone()
for y in(-1.34,-.26):
 for sign in(-1,1):
  path=[(0,y,4.34),(sign*.30,y,4.65),(sign*1.85,y,4.65),(sign*1.85,y,4.215)]
  route('crowned roof service arch',rounded(path,.16),.040,bronze)
  for offset in(-.072,.072):
   route('roof arch parallel armored signal line',rounded([(0,y+math.copysign(.20,offset),4.34),(sign*.30,y+offset,4.70),(sign*1.85,y+offset,4.70),(sign*1.85,y+offset,4.227)],.16),.012,iron,seg=16)
  route('roof service arch supported split clamp',[(sign*.625,y,4.65),(sign*.675,y,4.65)],.054,steel,.041,seg=32)
  beam('roof arch grounded diagonal brace',(0,y+.02,4.20),(sign*.65,y,4.59),.025,.030,steel)
  RZ('crown service arch seated ferrule',sign*1.85,y,4.235,.060,.041,.055,iron)
  for k in range(6):
   a=math.tau*k/6;bolt('crown arch foot retained stud',(sign*1.85+.076*math.cos(a),y+.076*math.sin(a),4.2525),r=.012)
for y in(-1.10,-.40,1.10):
 C('dorsal keyed inspection plug flange',(0,y,4.490),.075,.035,iron)
 C('dorsal retained inspection plug',(0,y,4.5425),.055,.070,bronze,seg=8)
 for k in range(4):
  a=math.tau*k/4;bolt('dorsal inspection plug foot screw',(.060*math.cos(a),y+.060*math.sin(a),4.518),r=.011)
end_zone(before,'crowned-roof-service-arches','Raised closed service arches, separated armored signal lines, grounded split clamps and diagonal braces connect the dorsal spine to sealed crown cartridges; keyed plug flanges further articulate the spine.')

# The rear receives the same density as the front, with protected trace runs and
# cast service seals in every remaining visible gable field.
before=begin_zone()
for sign in(-1,1):
 x=sign*.425
 route('rear protected diagnostic riser',rounded([(x,2.30,.55),(x,2.30,.68),(x,2.30,2.98),(x,2.02,3.10)],.08),.018,bronze)
 for z in(1.0,1.90,2.90):
  RZ('rear diagnostic riser split clamp',x,2.30,z,.029,.019,.040,iron)
  B('rear riser founded wall shoe',(x,2.085,z),(.12,.070,.080),steel)
  B('rear riser supported standoff',(x,2.193,z),(.055,.156,.040),iron,bevel=.004)
 for x in(sign*.30,):
  for z in(.91,1.52):
   C('rear access leaf keyed seal',(x,2.196,z),.064,.036,bronze,'Y',seg=8)
   C('rear seal captured center',(x,2.223,z),.028,.024,iron,'Y',seg=6)
rear_cells=[]
def exposed_rear(x,z):
 if abs(x)>1.25 or z<.42 or z>4.10-1.25*abs(x)/1.35-.055:return False
 if abs(x)<.70 and z<1.88:return False
 if abs(abs(x)-.425)<.13 and any(abs(z-v)<.12 for v in(1.0,1.90,2.90)):return False
 if any(abs(x-v)<.36 for v in(-.85,0,.85))and 2.15<z<2.96:return False
 if x*x+(z-3.42)**2<.34**2:return False
 return True
for i in range(15):
 x=-1.12+i*.16
 for j in range(22):
  z=.51+j*.16
  if not all(exposed_rear(x+dx,z+dz)for dx in(-.06,.06)for dz in(-.06,.06)):continue
  B('rear cast service-rite tablet',(x,2.075,z),(.125,.060,.125),iron,bevel=.005)
  mode=(i*3+j*7)%3
  if mode==0:
   C('rear cast octagonal tamper seal',(x,2.125,z),.045,.035,bronze,'Y',seg=8)
   C('rear seal retained center pin',(x,2.149,z),.019,.018,steel,'Y',seg=6)
  elif mode==1:
   for zz in(-.036,0,.036):B('rear cast blind relief slot',(x,2.124,z+zz),(.095,.035,.014),bronze,bevel=.002)
  else:
   for dx in(-.042,.042):B('rear cast protected trace',(x+dx,2.124,z),(.012,.035,.100),steel,bevel=.002)
   for dz in(-.044,.044):B('rear trace closed terminal',(x,2.124,z+dz),(.085,.035,.012),bronze,bevel=.002)
  rear_cells.append([x,z])
end_zone(before,'rear-diagnostic-looms-and-cast-relief','Protected rear diagnostic risers, founded standoffs, keyed access seals and cast trace/tamper relief occupy the remaining exposed rear gable fields. All construction stays outside the closed factory envelope.')
(O/'continued-refinement.json').write_text(json.dumps({'owner_request':'continue grebel refinement','continued_refinement':True,'factory_interior_remains_hidden':True,'rear_cast_cells':len(rear_cells),'roof_service_arches':4,'parallel_signal_lines':8,'facade_braided_looms':2,'clearance_review_pending':True,'owner_visual_approved':False},indent=2)+'\n')
