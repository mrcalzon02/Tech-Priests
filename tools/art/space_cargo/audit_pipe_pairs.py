"""Conservative3D swept-tube separation for all new pump routes."""
from pathlib import Path
import math,json,hashlib
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';data=json.loads((O/'dense-detail-manifest.json').read_text());routes=data['hydraulic_routes']
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [x-y for x,y in zip(a,b)]
def distance(a,b,c,d):
 u=sub(b,a);v=sub(d,c);w=sub(a,c);A=dot(u,u);B=dot(u,v);C=dot(v,v);D=dot(u,w);E=dot(v,w);den=A*C-B*B;candidates=[]
 if den>1e-20:
  s=(B*E-C*D)/den;t=(A*E-B*D)/den
  if 0<=s<=1 and 0<=t<=1:candidates.append((s,t))
 for s in (0,1):candidates.append((s,max(0,min(1,(E+B*s)/C))))
 for t in (0,1):candidates.append((max(0,min(1,(B*t-D)/A)),t))
 return min(math.sqrt(sum((w[k]+s*u[k]-t*v[k])**2 for k in range(3))) for s,t in candidates)
def segments(route):
 p=route['request']['path']['points'];dist=[0]
 for a,b in zip(p,p[1:]):dist.append(dist[-1]+math.dist(a,b))
 return [(a,b,.030 if dist[k]<.045 or dist[-1]-dist[k+1]<.045 else .0175) for k,(a,b) in enumerate(zip(p,p[1:]))]
checks=[]
for i in range(len(routes)):
 for j in range(i):
  clearance=min(distance(a,b,c,d)-ra-rb for a,b,ra in segments(routes[i]) for c,d,rb in segments(routes[j]));checks.append(dict(a=routes[i]['request']['id'],b=routes[j]['request']['id'],minimum_conservative_clearance=clearance,passed=clearance>.002))
r=dict(passed=all(x['passed'] for x in checks),source_sha256=hashlib.sha256((O/'advanced-space-cargo-v01.blend').read_bytes()).hexdigest(),pairs=checks,scope='True3Dpolyline segment separation, conservative outer tube radii and enlarged terminal fitting envelope. Blender units only; no engineering gauge/pressure certification.')
(O/'pipe-pair-clearance.json').write_text(json.dumps(r,indent=2)+'\n');print('PUMP_ROUTE_PAIR_CLEARANCE',r['passed'],checks);assert r['passed']
