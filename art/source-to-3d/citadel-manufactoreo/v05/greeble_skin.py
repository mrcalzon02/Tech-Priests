"""Dense authored mechanical skin; closed factory interior remains opaque.

Run by build_citadel.py with its measured geometry/material helpers. All donor
materials are verified FMPL images; no unclassified third-party mesh scatter.
"""
from mathutils import Matrix
skin=[]
def begin_zone():return {o.name for o in col.objects}
def end_zone(before,zone,purpose):
 objects=[o for o in col.objects if o.name not in before]
 for o in objects:o['citadel_exterior_system']=zone;o['construction_purpose']=purpose
 skin.append({'zone':zone,'purpose':purpose,'objects':[o.name for o in objects],'mesh_count':sum(o.type=='MESH'for o in objects)})
def RZ(n,x,y,z,r,bore,d,m=bronze,parent=root):return route(n,[(x,y,z-d/2),(x,y,z+d/2)],r,m,bore,parent,32)
def cog(n,x,y,z,r,inner,teeth=20,m=bronze):
 count=teeth*4;outside=[]
 for k in range(count):
  a=math.tau*k/count;rr=r if k%4 in(1,2)else r*.89;outside.append((x+rr*math.cos(a),z+rr*math.sin(a)))
 vv=[(xx,y+yy,zz)for yy in(-.025,.025)for xx,zz in outside]
 vv.extend((x+inner*math.cos(k*math.tau/count),y+yy,z+inner*math.sin(k*math.tau/count))for yy in(-.025,.025)for k in range(count));ff=[]
 for k in range(count):
  j=(k+1)%count;ff.extend([(k,j,2*count+j,2*count+k),(count+k,3*count+k,3*count+j,count+j),(k,count+k,count+j,j),(2*count+k,2*count+j,3*count+j,3*count+k)])
 return mesh('CITADEL | '+n,vv,ff,m,col,root)

# The dorsal trunk replaces the bare ridge with a capped, clamped distribution
# spine. Every roof cell has a supported finned exchanger and a terminated feed.
before=begin_zone()
route('closed dorsal tooling-service trunk',[(0,-1.88,4.34),(0,1.98,4.34)],.140,bronze,.105)
for y in(-1.88,1.98):C('dorsal trunk sealed end cap',(0,y,4.34),.150,.045,steel,'Y')
for y in(-1.62,-.82,0,.82,1.62):
 RY('dorsal split pressure clamp',0,y,4.34,.182,.141,.09,steel)
 B('dorsal clamp ridge seat',(0,y,4.185),(.23,.14,.075),iron)
 for k in range(8):
  a=math.tau*k/8;bolt('dorsal clamp retained fastener',(.165*math.cos(a),y-.061,4.34+.165*math.sin(a)),'Y',.019)
roof_rows=(-1.42,-.72,0,.72,1.42)
for sign in(-1,1):
 tangent=Vector((.733,0,-sign*.680)).normalized();normal=tangent.cross(Vector((0,1,0))).normalized();rotation=Matrix((tangent,Vector((0,1,0)),normal)).transposed().to_euler()
 for row,y in enumerate(roof_rows):
  center=Vector((sign*.73,y,4.10-1.25*.73/1.35));module=E('roof heat-exchanger mount '+str(sign)+' '+str(row),center);module.rotation_euler=rotation
  for xx in(-.50,.50):
   for yy in(-.21,.21):B('roof exchanger grounded standoff',(xx,yy,.07),(.10,.08,.14),steel,module)
  B('roof exchanger bolted sole',(0,0,.16),(1.22,.56,.06),iron,module)
  B('sealed roof heat-exchanger core',(0,0,.26),(1.08,.40,.14),steel,module)
  for xx in [k*.095 for k in range(-5,6)]:B('roof exchanger upright cooling fin',(xx,0,.385),(.024,.44,.11),bronze,module,bevel=.004)
  for yy in(-.26,.26):B('exchanger protective clamp rail',(0,yy,.27),(1.22,.035,.055),iron,module,bevel=.005)
  for xx in(-.53,.53):
   for yy in(-.22,.22):bolt('roof exchanger sole bolt',(xx,yy,.215),r=.021,parent=module)
  # Terminated feed runs from the upper end of this core to the dorsal trunk.
  bpy.context.view_layer.update();anchor=module.matrix_world@Vector((-sign*.56,0,.27))
  route('roof core supported dorsal feed',rounded([tuple(anchor),(sign*.18,y,4.39),(0,y,4.34)],.10),.026,bronze)
  RY('roof core dorsal branch ferrule',0,y,4.34,.164,.141,.050,iron)
end_zone(before,'roof-distribution-and-heat-exchange','Capped service spine, five grounded clamp stations, ten supported sealed heat exchangers and terminated branches; whole roof surface is articulated machinery.')

# Roof crowns gain paired rows of bolted service cartridges, and load ribs get
# actual seated clip plates rather than remaining plain decorative stripes.
before=begin_zone()
for sign in(-1,1):
 x=sign*1.85
 for y in(-1.34,-.80,-.26):
  C('crown service cartridge founded flange',(x,y,3.941),.135,.045,iron)
  C('sealed crown service cartridge',(x,y,4.075),.086,.245,bronze)
  C('crown cartridge retained head',(x,y,4.215),.105,.040,steel)
  for k in range(6):
   a=math.tau*k/6;bolt('crown cartridge foot bolt',(x+.112*math.cos(a),y+.112*math.sin(a),3.978),r=.017)
  for dx in(-.105,.105):B('crown cartridge protective tie',(x+dx,y,4.075),(.018,.028,.26),steel,bevel=.003)
 # Articulated ribs follow each triangular crown, seated into its existing skin.
 for y in(-1.68,-1.08,-.48,.12):
  for dx in(-.34,0,.34):
   heights=(.56-abs(dx),.56*(y+1.92)/.52,.56*(.32-y)/.52);which=min(range(3),key=lambda i:heights[i]);z=3.29+min(heights)
   if which==0:normal=Vector((math.copysign(1,dx)if dx else 0,0,1)).normalized()
   elif which==1:normal=Vector((0,-.56/.52,1)).normalized()
   else:normal=Vector((0,.56/.52,1)).normalized()
   tx=Vector((1,0,0));tx=(tx-normal*normal.dot(tx)).normalized();ty=normal.cross(tx)
   pad=E('crown fitted maintenance pad frame',(x+dx,y,z));pad.rotation_euler=Matrix((tx,ty,normal)).transposed().to_euler()
   B('crown maintenance pad',(0,0,.012),(.15,.16,.030),iron,pad,bevel=.006)
   bolt('crown maintenance pad bolt',(0,0,.045),r=.018,parent=pad)
for y in(-1.72,-.90,0,.90,1.80):
 for sign in(-1,1):
  for xx in(.28,.62,1.02):
   x=sign*xx;z=4.16-1.29*xx/1.39
   normal=Vector((sign*1.29/1.39,0,1)).normalized();tx=Vector((normal.z,0,-normal.x));ty=Vector((0,1,0));clip=E('roof rib fitted locking clip frame',Vector((x,y,z))+normal*.045);clip.rotation_euler=Matrix((tx,ty,normal)).transposed().to_euler()
   B('roof rib locking clip',(0,0,0),(.12,.17,.040),steel,clip,bevel=.006)
   bolt('roof rib locking clip stud',(0,0,.035),r=.021,parent=clip)
end_zone(before,'roof-crowns-and-rib-joints','Supported sealed service cartridges, guard ties and bolted maintenance/roof-rib seats retain the industrial cathedral crown.')

# Front service bundles route around both the view windows and fan keep-outs.
before=begin_zone()
for sign in(-1,1):
 x=sign*1.85;bottom=1.25 if sign<0 else .45
 for dx in(-.47,-.405,.405,.47):
  px=x+dx
  route('tower facade protected service line',rounded([(px,-1.74,bottom),(px,-1.995,bottom),(px,-1.995,3.05),(px,-1.74,3.05)],.065),.018,bronze)
  for z in(1.38,2.05,2.91):
   RZ('facade bundle split clamp',px,-1.995,z,.028,.019,.045,steel)
   B('facade clamp tower standoff',(px,-1.8915,z),(.040,.143,.040),iron,bevel=.004)
 for k in range(16):
  a=math.tau*k/16;px=x+.355*math.cos(a);z=2.67+.355*math.sin(a)
  fin=B('fan exterior cooling rib',(px,-2.045,z),(.029,.065,.036),steel,bevel=.004);fin.rotation_euler.y=math.pi/2-a
 for z in(.45,1.15,2.30,3.12):
  for dx in(-.40,.40):bolt('tower facade armor stud',(x+dx,-1.937,z),'Y',.022)
end_zone(before,'facade-service-and-fan-cooling','Clamped protected service bundles terminate in the closed towers and clear the rotating fan housings; ring fins and armor studs articulate every tower edge.')

# Seated opaque green glazing gets a second structural surround and continuous
# leaded/mechanical tracery, with no view into the factory.
before=begin_zone()
for name,x,w,bottom,spring in [('nave',0,.36,2.83,3.02),('left tower',-1.85,.255,1.30,1.60),('right tower',1.85,.255,1.30,1.60)]:
 front=-1.965
 extrude(name+' sealed glazing back seat',[(x+xx,z)for xx,z in pointed(w+.010,bottom-.010,spring)],front+.030,.12,dark)
 arch(name+' outer ribbed glazing surround',x,front-.012,w+.13,w+.080,bottom-.06,spring,.14,steel)
 for dx in(-w*.85,w*.85):
  for z in(bottom+.12,spring):bolt(name+' glazing clamp bolt',(x+dx,front-.072,z),'Y',.017)
 # Clip diagonal lead strips to the actual pointed pane outline.
 for slope in(-1,1):
  for intercept in [bottom-.5+k*.15 for k in range(13)]:
   pts=[]
   for k in range(81):
    xx=-w+2*w*k/80;z=intercept+slope*xx;ceiling=spring+math.sqrt(max(0,(2*w)**2-(abs(xx)+w)**2))
    if bottom+.025<=z<=ceiling-.025:pts.append((x+xx,front-.030,z))
   if len(pts)>2 and(Vector(pts[-1])-Vector(pts[0])).length>.035:beam(name+' sealed diagonal glazing lead',pts[0],pts[-1],.009,.012,bronze)
end_zone(before,'sealed-glazing-and-tracery','Deep blind green panes remain opaque; compound load-bearing frames, clamp bolts and cropped lead tracery remove plain glazing without exposing any interior.')

# Dense side-wall equipment bays fit entirely onto the existing closed towers.
before=begin_zone()
for sign in(-1,1):
 for row,z in enumerate((.82,1.65,2.48)):
  for column,y in enumerate((-1.35,-.65,.05)):
   if row==0 and column==1:continue  # Existing red material-transfer hatch.
   B('side maintenance bay seated casting',(sign*2.392,y,z),(.050,.55,.62),iron,bevel=.012)
   for yy in(y-.218,y+.218):
    for zz in(z-.25,z+.25):bolt('side bay perimeter fastener',(sign*2.432,yy,zz),'X',.021)
   mode=(row+column)%3
   if mode==0:
    B('blind side louvre backing',(sign*2.426,y,z),(.028,.44,.47),dark)
    for k in range(9):B('side cooling louvre blade',(sign*2.453,y,z-.20+k*.05),(.035,.43,.021),steel,bevel=.003)
   elif mode==1:
    C('side sealed circular inspection cover',(sign*2.446,y,z),.205,.060,bronze,'X')
    C('side inspection cover inset',(sign*2.482,y,z),.150,.018,iron,'X')
    for k in range(8):
     a=math.tau*k/8;bolt('circular inspection flange bolt',(sign*2.490,y+.178*math.cos(a),z+.178*math.sin(a)),'X',.018)
   else:
    B('side keyed service plate',(sign*2.438,y,z),(.035,.38,.43),red)
    for yy in(y-.14,y+.14):B('service plate raised locking rail',(sign*2.467,yy,z),(.025,.026,.36),bronze,bevel=.004)
    for k in range(4):B('service plate raised trace',(sign*2.474,y,z-.15+k*.10),(.025,.30,.012),steel,bevel=.002)
 # Closed clamped risers in the gaps between side bays.
 for y in(-1.695,-.995,-.285):
  bottom=1.25 if y==-.285 else .43
  route('side protected vertical riser',[(sign*2.435,y,bottom),(sign*2.435,y,3.10)],.018,bronze)
  for z in(1.30,2.12,2.96):
   RZ('side riser split clamp',sign*2.435,y,z,.028,.019,.040,steel)
   B('side riser wall standoff',(sign*2.387,y,z),(.055,.038,.040),iron,bevel=.004)
 # Rear wing thermal panels and multiple narrow articulated plinth interfaces.
 for y in(.91,1.58):
  B('rear wing thermal panel',(sign*2.355,y,1.60),(.045,.52,1.50),iron)
  for k in range(14):B('rear wing heat-exchanger fin',(sign*2.397,y,.97+k*.095),(.040,.45,.024),bronze,bevel=.004)
  for z in(.91,2.30):bolt('rear thermal panel seat bolt',(sign*2.425,y,z),'X',.024)
end_zone(before,'side-bays-and-closed-risers','Fitted louvres, sealed inspection caps, keyed access plates, heat-exchanger fins and supported risers; the existing material hatch remains clear and no gameplay fluid port is added.')

# Door panels become layered locking/inspection skins, not large blank slabs.
before=begin_zone()
for sign in(-1,1):
 for z in(.58,.91,1.25,1.59):
  x=sign*.35;B('main door recessed maintenance tablet',(x,-2.17,z),(.25,.09,.26),iron,bevel=.007)
  for dx in(-.105,.105):B('tablet edge retaining strip',(x+dx,-2.226,z),(.022,.028,.25),bronze,bevel=.003)
  for dz in(-.105,.105):B('tablet horizontal retaining strip',(x,-2.226,z+dz),(.21,.028,.020),steel,bevel=.003)
  for dz in(-.06,0,.06):B('tablet raised machine-rite line',(x,-2.246,z+dz),(.15,.015,.009),bronze,bevel=.001)
  for dx in(-.09,.09):bolt('door tablet rivet',(x+dx,-2.252,z),'Y',.012)
 for z in(.44,.80,1.17,1.54,1.88):
  bolt('door edge continuous retained stud',(sign*.665,-2.17,z),'Y',.021)
 for z in(.78,1.40):
  B('door transverse locking bolt',(sign*.44,-2.25,z),(.56,.065,.060),steel)
  for x in(sign*.22,sign*.64):B('locking bolt closed guide',(x,-2.215,z),(.08,.14,.105),bronze)
 # Follow the pointed arch with seated, readable individual retaining fasteners.
 for k in range(11):
  xx=.84*k/10;z=1.10+math.sqrt(max(0,(1.68)**2-(xx+.84)**2))
  if k>0 or sign<0:bolt('main arch pressure ring stud',(sign*xx,-2.08,z),'Y',.025)
cog('door lock toothed retaining corona',0,-2.330,1.24,.275,.237,24,steel)
for z in(2.62,3.90):
 C('facade consecrated inspection seal',(0,-1.975,z),.100,.060,iron,'Y')
 cog('facade cog inspection seal',0,-2.018,z,.130,.088,16,bronze)
end_zone(before,'door-locking-skin-and-consecrated-seals','Layered retained tablets, raised machine-rite lines, guided locking bars, pressure-arch studs and cog inspection seals fill the heavy closed doors and facade.')

# The back is equally manufactured: articulated access leaves, diagnostic bays,
# pressure hubs, heat fins and bracketed risers across the gable and rear towers.
before=begin_zone()
for x in(-.45,-.15,.15,.45):B('rear access door vertical retaining band',(x,2.16,1.05),(.040,.050,1.30),steel)
for z in(.61,1.21):
 B('rear access door transverse locking rail',(0,2.192,z),(1.10,.060,.060),bronze)
 for x in(-.47,.47):bolt('rear locking rail retained bolt',(x,2.237,z),'Y',.024)
for x in(-.85,0,.85):
 B('rear upper diagnostic panel',(x,2.10,2.55),(.60,.10,.68),iron)
 for dx in(-.24,.24):
  for z in(2.29,2.81):bolt('rear diagnostic panel fastener',(x+dx,2.177,z),'Y',.021)
 for k in range(7):B('rear diagnostic cooling louvre',(x,2.174,2.32+k*.077),(.46,.035,.023),bronze,bevel=.003)
C('rear ridge inspection boss',(0,2.10,3.42),.26,.10,iron,'Y')
cog('rear ridge mechanical seal',0,2.169,3.42,.29,.18,20,bronze)
C('rear ridge sealed hub',(0,2.18,3.42),.16,.055,red,'Y')
for sign in(-1,1):
 x=sign*1.85
 B('rear tower full-height service panel',(x,2.075,1.52),(.77,.10,1.94),iron)
 for z in(.68,1.30,1.92,2.31):
  B('rear tower reinforced panel seam',(x,2.143,z),(.78,.040,.035),bronze)
  for dx in(-.30,.30):bolt('rear tower seam fastener',(x+dx,2.186,z),'Y',.023)
 for dx in(-.25,0,.25):B('rear tower protected conduit',(x+dx,2.159,1.53),(.038,.05,1.78),steel)
end_zone(before,'rear-service-and-thermal-skin','Dense closed access hardware, heat louvres, diagnostic panels, cog seals and protected tower conduits; no bare back wall or exposed factory interior.')

# The structural base and buttresses retain real detail at every visible edge.
before=begin_zone()
for sign in(-1,1):
 for k in range(21):
  v=-2.20+k*.22
  if sign<0:
   bolt('front foundation perimeter rivet',(v,-2.386,.235),'Y',.023)
   bolt('rear foundation perimeter rivet',(v,2.386,.235),'Y',.023)
  bolt('side foundation perimeter rivet',(sign*2.386,v,.235),'X',.023)
 for y in(-1.75,-1.25,-.75,-.25,.25,.75,1.25,1.75):
  B('founded side shoe articulated clamp',(sign*2.29,y,.42),(.22,.075,.12),bronze)
  bolt('side shoe clamp stud',(sign*2.29,y,.50),r=.021)
for o in list(col.objects):
 if o.name.startswith('CITADEL | external flying load buttress'):
  length=max(v.co.z for v in o.data.vertices)-min(v.co.z for v in o.data.vertices)
  for zz in(-length*.34,0,length*.34):
   B('buttress reinforced split collar',(0,0,zz),(.28,.28,.065),bronze,o,bevel=.007)
   for xx in(-.075,.075):bolt('buttress collar retained rivet',(xx,-.135,zz),'Y',.018,o)
end_zone(before,'base-fasteners-and-load-paths','Continuous edge fasteners, founded shoe clamps and split buttress collars finish the structural perimeter; all details belong to installed supports.')

exec((O/'cathedral_relief.py').read_text(),globals())
exec((O/'facade_casting.py').read_text(),globals())
exec((O/'roof_service_cassettes.py').read_text(),globals())
(O/'greeble-skin-manifest.json').write_text(json.dumps({'owner_direction':'No square inch of plain surface; extreme source-image mechanical cathedral density.','factory_interior_still_opaque':True,'unclassified_private_donor_meshes_used':False,'zones':skin,'total_added_meshes':sum(x['mesh_count']for x in skin),'full_clearance_and_export_inspection_pending':True},indent=2)+'\n')
