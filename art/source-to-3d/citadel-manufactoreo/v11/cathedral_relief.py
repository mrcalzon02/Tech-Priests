"""Finish the remaining large plain fields with seated mechanical cathedral relief."""
before=begin_zone()
for sign in(-1,1):
 x=sign*1.17
 # Supported, capped service columns frame the closed central facade.
 C('facade service column founded plinth',(x,-1.98,.48),.145,.13,iron)
 C('facade sealed lower tooling cartridge',(x,-2.015,.94),.094,.82,bronze)
 route('facade closed upper service riser',[(x,-2.015,1.34),(x,-2.015,2.56)],.075,steel,.047)
 for z in(.61,1.28,1.49,1.73,1.97,2.21,2.47):
  RZ('facade service split retaining band',x,-2.015,z,.113,.095 if z<1.34 else .076,.060,iron)
  B('facade service founded wall saddle',(x,-1.8875,z),(.15,.055,.055),bronze)
 C('facade service closed top cap',(x,-2.015,2.60),.112,.08,bronze)
 for z in(.925,):
  for k in range(6):
   a=math.tau*k/6;B('lower tooling cartridge captive tie',(x+.101*math.cos(a),-2.015+.101*math.sin(a),z),(.017,.017,.78),steel,bevel=.003)
 route('facade service transom return',rounded([(x,-2.025,2.61),(sign*.96,-2.025,2.77),(sign*.72,-2.025,2.77),(sign*.60,-2.025,2.92),(sign*.60,-1.87,2.92)],.09),.023,bronze)
 for z in(.77,1.05,1.59,2.11,2.38):bolt('facade cartridge retained face stud',(x,-2.137,z),'Y',.018)
 # Blind relief panels occupy the upper door leaves; the inner factory remains hidden.
 xx=sign*.33
 extrude('upper door blind pointed tablet',[(xx+a,z)for a,z in pointed(.14,1.76,1.80)],-2.176,.05,dark)
 arch('upper door tablet retaining arch',xx,-2.197,.185,.148,1.745,1.80,.07,bronze)
 for dx in(-.065,0,.065):B('upper door tablet captive filigree',(xx+dx,-2.219,1.89),(.012,.025,.22),steel,bevel=.002)
 beam('upper door captured tension tie',(sign*.08,-2.21,1.53),(sign*.15,-2.21,2.20),.022,.028,bronze)
 C('upper door tension anchor',(sign*.15,-2.23,2.20),.038,.045,steel,'Y',seg=8)
end_zone(before,'central-facade-tooling-and-door-relief','Capped, wall-supported service columns, retained cartridge ties, closed transom returns and upper-leaf relief fill the remaining nave/door fields without exposing processing internals.')

# Complete the front tower hip roofs: plate frames follow the real hip planes,
# while front/rear triangular faces are covered by stepped heat louvres.
before=begin_zone()
for sign in(-1,1):
 x=sign*1.85
 for side in(-1,1):
  normal=Vector((side,0,1)).normalized();tx=Vector((normal.z,0,-normal.x));ty=Vector((0,1,0));rot=Matrix((tx,ty,normal)).transposed().to_euler()
  for y in(-1.08,-.48):
   frame=E('tower crown fitted thermal cassette',Vector((x+side*.32,y,3.85-.32))+normal*.025);frame.rotation_euler=rot
   B('crown thermal cassette seated rim',(0,0,0),(.38,.43,.040),iron,frame,bevel=.008)
   for k in range(7):B('crown thermal cassette formed fin',(-.15+k*.05,0,.047),(.018,.36,.056),bronze,frame,bevel=.003)
   for xx in(-.15,.15):
    for yy in(-.18,.18):bolt('crown cassette rim fastener',(xx,yy,.043),r=.014,parent=frame)
 for front in(True,False):
  normal=Vector((0,-.56/.52 if front else .56/.52,1)).normalized();tx=Vector((1,0,0));ty=normal.cross(tx);rotation=Matrix((tx,ty,normal)).transposed().to_euler()
  for k in range(6):
   y=(-1.84+k*.08)if front else(.24-k*.08);height=.56*((y+1.92)if front else(.32-y))/.52;half=.56-height
   frame=E('crown hip louvre plane',(x,y,3.29+height));frame.rotation_euler=rotation
   B('crown hip fitted heat louvre',(0,0,.020),(max(.05,2*half-.05),.035,.035),steel,frame,bevel=.004)
   for xx in([0]if half<.075 else[-half+.045,half-.045]):bolt('crown hip louvre rivet',(xx,0,.052),r=.010,parent=frame)
end_zone(before,'crown-thermal-cassettes-and-hip-louvres','Fitted thermal cassettes, retained fins and triangular-face louvres cover the remaining crown surfaces, each oriented to its actual supporting roof plane.')

# Fill the formerly plain rear tower roof caps with tightly framed service bays.
before=begin_zone()
for sign in(-1,1):
 x=sign*1.85
 for dx in(-.24,.24):
  for y in(1.10,1.60):
   px=x+dx
   B('rear crown service-bay sole',(px,y,2.748),(.40,.40,.040),iron,bevel=.009)
   C('rear crown sealed thermal core',(px,y,2.796),.169,.060,steel)
   RZ('rear crown core retained collar',px,y,2.813,.193,.171,.045,bronze)
   for k in range(7):B('rear crown heat core slat',(px-.135+k*.045,y,2.848),(.020,.25,.045),bronze,bevel=.003)
   for xx in(-.155,.155):
    for yy in(-.155,.155):bolt('rear crown service-bay foot stud',(px+xx,y+yy,2.792),r=.015)
 for dx in(-.49,.49):B('rear crown protected bus duct',(x+dx,1.35,2.76),(.045,1.33,.060),steel)
 for k in range(9):
  y=.73+k*.155
  for dx in(-.49,.49):bolt('rear crown cornice retained rivet',(x+dx,y,2.806),r=.014)
 for k in range(7):
  xx=x-.43+k*.143
  for y in(.68,2.02):bolt('rear crown transverse cornice rivet',(xx,y,2.774),r=.014)
end_zone(before,'rear-crown-service-bays','Eight individually retained thermal service bays, narrow bus ducts and continuous cornice fastening cover both formerly plain rear roof caps.')
