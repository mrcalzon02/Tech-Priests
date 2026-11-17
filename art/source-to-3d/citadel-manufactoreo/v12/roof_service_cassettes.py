"""Supported cylindrical service cassettes add a second mechanical roof layer."""
before=begin_zone();modules=[o for o in col.objects if o.name.startswith('CITADEL | roof heat-exchanger mount')]
assert len(modules)==10
for index,parent in enumerate(modules):
 for y in(-.12,.12):
  C('roof cassette sealed service body',(0,y,.75),.060,.54,bronze if index%2 else steel,'X',parent,32)
  for x in(-.25,.25):
   route('roof cassette split cylindrical cradle',[(x-.0225,y,.75),(x+.0225,y,.75)],.080,iron,.061,parent,32)
   C('roof cassette closed end cap',(math.copysign(.278,x),y,.75),.064,.016,bronze,'X',parent,32)
   B('cassette thermal-core founded post',(math.copysign(.3325,x),y,.495),(.045,.045,.37),iron,parent,bevel=.006)
   B('cassette fitted cradle bridge',(math.copysign(.30,x),y,.665),(.14,.055,.040),steel,parent,bevel=.005)
   for k in range(6):
    a=math.tau*k/6;C('cassette cap retained fastener',(math.copysign(.293,x),y+.051*math.cos(a),.75+.051*math.sin(a)),.010,.018,bronze,'X',parent,6)
  # The return sits between existing fin rows, entering the sealed thermal core.
  route('cassette terminated thermal return',[(.1425,y,.735),(.1425,y,.32)],.018,bronze,parent=parent,seg=16)
  RZ('cassette return service union',.1425,y,.58,.025,.019,.045,steel,parent)
end_zone(before,'supported-roof-service-cassettes','Twenty capped service cylinders and retained cradles sit on posts founded in their thermal cores. Their return lines fit between existing fin rows. The added roof layer is attached, closed, and entirely exterior; no manufacturing interior or native fluid connection is exposed.')
