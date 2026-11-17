"""Small cast service/ritual relief fills exposed wall fields, never machinery interiors."""
before=begin_zone();cast_cells=[]
def top(w,spring,x):return spring+math.sqrt(max(0,(2*w)**2-(abs(x)+w)**2))if abs(x)<=w else-1
def front_wall(x,z):
 ax=abs(x)
 if ax<=1.34:
  if z<.36 or z>4.10-1.25*ax/1.35-.06:return None
  if ax<.99 and z<top(.99,1.10,x)+.07:return None
  if ax<.53 and z>2.74 and z<top(.53,3.02,x)+.06:return None
  if abs(ax-1.17)<.17 and z<2.79:return None
  if ax<.18 and z>3.68:return None
  return-1.90
 if abs(ax-1.85)<=.48:
  dx=x-math.copysign(1.85,x)
  if z<.44 or z>3.16:return None
  if dx*dx+(z-2.67)**2<.425**2:return None
  if abs(dx)<.40 and z>1.24 and z<top(.40,1.60,dx)+.055:return None
  if x<0 and z<1.24:return None  # Existing FMPL console stays unobstructed.
  if x>0 and dx*dx+(z-.84)**2<.225**2:return None
  if min(abs(dx-v)for v in(-.47,-.405,.405,.47))<.035:return None
  return-1.875
 return None
for ix in range(27):
 x=-2.21+ix*.17
 for iz in range(21):
  z=.52+iz*.16
  faces=[front_wall(x+dx,z+dz)for dx in(-.058,.058)for dz in(-.058,.058)]
  if any(y is None for y in faces)or max(faces)-min(faces)>.001:continue
  wall=faces[0];y=wall-.025;mode=(ix*7+iz*11)%4
  B('cast service-rite relief tablet',(x,y,z),(.125,.06,.125),iron,bevel=.005)
  if mode==0:
   for dx in(-.043,.043):B('tablet protected signal trace',(x+dx,y-.042,z),(.012,.032,.100),bronze,bevel=.002)
   for dz in(-.045,.045):B('tablet signal trace terminal',(x,y-.042,z+dz),(.086,.032,.012),steel,bevel=.002)
  elif mode==1:
   C('tablet hexagonal tamper seal',(x,y-.053,z),.046,.035,bronze,'Y',seg=6)
   C('tamper seal recessed pin',(x,y-.076,z),.020,.017,steel,'Y',seg=8)
  elif mode==2:
   for dz in(-.037,0,.037):B('tablet blind cooling slit',(x,y-.047,z+dz),(.098,.035,.014),bronze,bevel=.002)
  else:
   beam('tablet cast consecration slash',(x-.037,y-.050,z-.044),(x+.037,y-.050,z+.044),.016,.028,steel)
   for dx in(-.041,.041):bolt('tablet corner retention',(x+dx,y-.060,z-dx),'Y',.011)
  cast_cells.append({'x':x,'z':z,'supporting_wall_y':wall,'type':['protected-signal-trace','hex-tamper-seal','blind-cooling-slots','cast-consecration-mark'][mode]})
end_zone(before,'dense-facade-cast-service-relief','Cast protected trace covers, tamper seals, blind cooling slits and machine-rite identifiers fill exposed nave/tower wall fields. Every tablet seats on the measured opaque facade and avoids windows, doors, console, gauge, service columns and fan envelopes.')
(O/'facade-relief-placement.json').write_text(json.dumps({'cells':cast_cells,'count':len(cast_cells),'factory_interior_visible':False,'fan_and_operator_keepouts_preserved':True},indent=2)+'\n')
