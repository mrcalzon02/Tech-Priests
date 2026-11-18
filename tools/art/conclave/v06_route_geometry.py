"""Constrained, inspectable service curves with exact socket tangents."""
import math
from mathutils import Vector,Matrix

def cubic(p0,p1,p2,p3,t):return p0*(1-t)**3+p1*(3*(1-t)**2*t)+p2*(3*(1-t)*t*t)+p3*t**3
def radius(p0,p1,p2,p3,t):
 v=(p1-p0)*(3*(1-t)**2)+(p2-p1)*(6*(1-t)*t)+(p3-p2)*(3*t*t);a=(p2-2*p1+p0)*(6*(1-t))+(p3-2*p2+p1)*(6*t);cross=v.cross(a).length
 if v.length<1e-7:return 0
 return v.length**3/cross if cross>1e-10 else 1000.
def segment(p,q,ns,nt,minimum,D):
 chord=(q-p).length;best=None
 for fa in (.15,.23,.33,.45,.6,.8,1.,1.3):
  for fb in (.15,.23,.33,.45,.6,.8,1.,1.3):
   a,b=max(.018,chord*fa),max(.018,chord*fb);p1=p+ns*a;p2=q-nt*b;rr=min(radius(p,p1,p2,q,j/24) for j in range(25));curve=[cubic(p,p1,p2,q,j/32) for j in range(33)];extent=max(max(abs(v.x)+D*.62-1,abs(v.y)+D*.62-.86,0) for v in curve);penalty=max(0,minimum*1.08-rr)*500+extent*10000;length=sum((v-u).length for u,v in zip(curve,curve[1:]));score=penalty+length+a*.04+b*.04
   if best is None or score<best[0]:best=(score,(p,p1,p2,q),rr,extent)
 control=best[1];rr=min(radius(*control,j/128) for j in range(129));return [cubic(*control,j/32) for j in range(33)],rr,best[3]
def discrete_radius(points):
 result=1000.
 for a,b,c in zip(points,points[1:],points[2:]):
  u,v=b-a,c-b;cross=u.cross(v).length
  if cross>1e-10:result=min(result,u.length*v.length*(c-a).length/(2*cross))
 return result
def plan_centerline(req,p,ns,q,ne,groupD,stations):
 p,q,ns,ne=map(Vector,(p,q,ns,ne));D=req['size']['outer_diameter'];rid=req['id'];family=req['family'];minimum=(2.5*groupD if family=='flex_hose' or 'hose-wire-core' in rid or 'sleeve-signal-core' in rid else max(.025,D*(1.5 if family=='segmented_conduit' else 2.0)));lead=.012 if family=='flex_hose' or 'hose-wire-core' in rid or 'sleeve-signal-core' in rid else max(.016,D*.55);a=p+ns*lead;b=q+ne*lead
 if 'protective-sleeve-' in rid or 'sleeve-signal-core-' in rid or 'flank-protective-hose-' in rid or 'flank-hose-wire-core-' in rid:
  delta=a-b;R=delta.z/2;assert abs(delta.x)<1e-4 and abs(delta.y)<1e-4 and ns.dot(ne)>.999,'Hose receiving mouths must share a vertical plane and outward axis';center=a-Vector((0,0,R));curve=[center+ns*(R*math.sin(j*math.pi/64))+Vector((0,0,R*math.cos(j*math.pi/64))) for j in range(65)];points=[p,(p+a)/2]+curve+[(b+q)/2,q];rr=R;method='one planar hanging semicircle, no compound hooks'
 elif 'conclave-v03-armored-return-' in rid:
  sign=-1 if '--1' in rid else 1;outer=.965;start=a;R0=outer-sign*start.x;R1=minimum;cx=outer-R1;last_u=cx-R1/math.sqrt(2);L=(last_u-sign*q.x)/abs(ne.x);assert R0>=minimum and L>=lead,'Armored return needs space for its true swept elbows';end_y=q.y-abs(ne.y)*L;turn_y=end_y+R1/math.sqrt(2)
  first=[Vector((sign*(sign*start.x+R0*math.sin(j*math.pi/64)),start.y-R0*(1-math.cos(j*math.pi/64)),start.z)) for j in range(33)];v0=first[-1];v1=Vector((sign*outer,turn_y,q.z));span=v0.y-v1.y;middle=[cubic(v0,v0+Vector((0,-span/3,0)),v1+Vector((0,span/3,0)),v1,j/32) for j in range(33)];turn=[Vector((sign*(cx+R1*math.cos(j*3*math.pi/128)),turn_y-R1*math.sin(j*3*math.pi/128),q.z)) for j in range(33)];points=[p,(p+a)/2]+first+middle[1:]+turn[1:]+[q];rr=min(R0,R1,min(radius(v0,v0+Vector((0,-span/3,0)),v1+Vector((0,span/3,0)),v1,j/64) for j in range(65)));method='straight gland entry, quarter elbow, straight flank, broad 135-degree return elbow'
 elif 'curved-arch-raceway' in rid:
  R=abs(a.x)/math.sqrt(.5);center=Vector((0,a.y,a.z-R*math.sqrt(.5)));curve=[center+Vector((R*math.cos(math.radians(135-90*j/64)),0,R*math.sin(math.radians(135-90*j/64)))) for j in range(65)];points=[p,(p+a)/2]+curve+[(b+q)/2,q];rr=R;method='one circular crown raceway tangent to its receiving socket frames'
 elif (q-p).normalized().dot(ns)>.999 and (q-p).normalized().dot(-ne)>.999:
  points=[p,p.lerp(q,.33),p.lerp(q,.66),q];rr=1000.;method='straight coaxial interconnect'
 else:
  guides=[]
  if 'upper-service-conduit-' in rid or 'upper-service-wire-core-' in rid:
   sign=-1 if '(-1,' in rid else 1
   guides=[] if ', 0)' in rid else [Vector((sign*.83,.44,1.49)),Vector((sign*.60,.79,1.45))]
  nodes=[a]+guides+[b];tangents=[ns]
  for j in range(1,len(nodes)-1):tangents.append((nodes[j+1]-nodes[j-1]).normalized())
  if 'conclave-v03-armored-return-' in rid:tangents[1]=Vector((0,1,0))
  tangents.append(-ne);curve=[];radii=[]
  for j in range(len(nodes)-1):
   part,r,extent=segment(nodes[j],nodes[j+1],tangents[j],tangents[j+1],minimum,D);curve.extend(part if not curve else part[1:]);radii.append(r)
  points=[p,(p+a)/2]+curve+[(b+q)/2,q];rr=min(radii);method='socket-straight tails and curvature-bounded cubic sweeps'
 # Remove numerical duplicates while retaining actual straight socket leads.
 clean=[]
 for point in points:
  if not clean or (point-clean[-1]).length>1e-6:clean.append(point)
 sampled=discrete_radius(clean);extent=max(max(abs(v.x)+D*.62-1,abs(v.y)+D*.62-.86,0) for v in clean);passed=rr>=minimum*.995 and sampled>=minimum*.90 and extent<1e-5
 record=dict(route=rid,method=method,diameter=D,required_minimum_radius=minimum,analytic_sampled_minimum_radius=rr,actual_polyline_circumradius=sampled,expanded_footprint_excess=extent,passed=passed,first_axis_error=(clean[1]-clean[0]).normalized().angle(ns),last_axis_error=(clean[-2]-clean[-1]).normalized().angle(ne))
 return [list(v) for v in clean],record
