"""Model-specific cast trace fields cover the remaining crown hip cheeks."""
before=begin_zone();trace_cells=[]
for sign in(-1,1):
 x=sign*1.85
 for side in(-1,1):
  normal=Vector((side,0,1)).normalized();tx=Vector((normal.z,0,-normal.x));ty=Vector((0,1,0))
  rotation=Matrix((tx,ty,normal)).transposed().to_euler()
  for dx in(.105,.24,.375,.51):
   for j in range(13):
    y=-1.70+j*.15
    # Tile corners must lie wholly within the actual quadrilateral hip face.
    if 3.85-dx+.040>min(3.29+.56*(y-.05+1.92)/.52,3.29+.56*(.32-y-.05)/.52):continue
    # Existing heat cassettes and maintenance-pad fasteners retain their space.
    if abs(dx-.32)<.18 and any(abs(y-v)<.27 for v in(-1.08,-.48)):continue
    if abs(dx-.34)<.10 and any(abs(y-v)<.115 for v in(-1.68,-1.08,-.48,.12)):continue
    f=E('crown cheek seated cast trace field',Vector((x+side*dx,y,3.85-dx))+normal*.012);f.rotation_euler=rotation
    B('crown cheek protected trace tablet',(0,0,.008),(.130,.105,.024),iron,f,bevel=.004)
    for xx in(-.045,.045):B('crown cheek raised trace rail',(xx,0,.026),(.012,.080,.012),bronze,f,bevel=.002)
    for yy in(-.032,.032):B('crown cheek branching trace bar',(0,yy,.026),(.085,.012,.012),steel,f,bevel=.002)
    C('crown cheek seated keyed trace seal',(0,0,.034),.020,.016,bronze,parent=f,seg=6)
    trace_cells.append([sign,side,dx,y])
end_zone(before,'crown-cheek-cast-trace-fields','Seated cast trace tablets, keyed seals and raised branch rails fill the remaining tower cheek fields. Tile-corner tests keep them within the actual sloping hip, outside existing thermal cassettes and maintenance pads. No additional manufacturing gameplay or visible interior is introduced.')
(O/'crown-cheek-placement.json').write_text(json.dumps({'cells':trace_cells,'count':len(trace_cells),'physical_plane_seating':True,'thermal_cassette_keepouts':True,'clearance_review_pending':True},indent=2)+'\n')
