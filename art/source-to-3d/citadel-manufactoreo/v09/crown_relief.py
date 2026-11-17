"""Seated cast relief fills crown fields; no loose machinery or hidden factory."""
before=begin_zone()
for sign in(-1,1):
 x=sign*1.85
 for front in(True,False):
  normal=Vector((0,-.56/.52 if front else .56/.52,1)).normalized()
  tx=Vector((1,0,0));ty=normal.cross(tx)
  rotation=Matrix((tx,ty,normal)).transposed().to_euler()
  # Relief sits in the gaps between the existing transverse heat louvres.
  # Every tile and captive fastening follows the actual triangular hip plane.
  for row in range(6):
   y=(-1.88+row*.08)if front else(.28-row*.08)
   height=.56*((y+1.92)if front else(.32-y))/.52
   half=.56-height
   count=max(1,int((2*half-.08)/.11))
   for k in range(count):
    dx=(k-(count-1)/2)*.11
    if abs(dx)+.048>half-.018:continue
    mount=E('crown cast rite seated tile',(x+dx,y,3.29+height));mount.rotation_euler=rotation
    B('crown cast stepped service tablet',(0,0,.014),(.087,.046,.028),iron,mount,bevel=.004)
    for xx in(-.027,.027):
     B('crown tablet twin embossed trace',(xx,0,.034),(.013,.034,.012),bronze,mount,bevel=.002)
    bolt('crown tablet captive hex pin',(0,0,.040),r=.011,parent=mount)
  # Continuous retained edge mouldings seat into the sloping hip, leaving
  # the roof louvres and existing crown cartridges unobstructed.
  for side in(-1,1):
   a=Vector((x+side*.53,-1.892 if front else .292,3.320))
   b=Vector((x+side*.025,-1.423 if front else -.177,3.825))
   a+=normal*.015;b+=normal*.015
   beam('crown triangular cast edge moulding',a,b,.024,.025,iron)
   for k in range(7):
    point=a.lerp(b,(k+.5)/7)
    pad=E('crown edge moulding captive seat',point);pad.rotation_euler=rotation
    B('crown edge cast retaining shoe',(0,0,0),(.040,.036,.024),bronze,pad,bevel=.004)
    bolt('crown edge moulding retained rivet',(0,0,.022),r=.012,parent=pad)
end_zone(before,'crown-cast-rite-relief-and-retained-mouldings','Cast stepped trace tablets fill the triangular hip fields between the existing louvres; retained edge mouldings and seated pins follow the real roof planes. Roof service arches now land on the actual capped cartridges at Y -1.34 and -.26, replacing the disconnected V06 rear arch endpoints.')
