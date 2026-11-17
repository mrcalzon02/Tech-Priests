import bpy,math
from mathutils import Vector
def cylinder_uv(o):
 """Primitive cylinders have interleaved lower/upper vertices in local Z."""
 vv=[v.co for v in o.data.vertices];radii=[math.hypot(v.x,v.y) for v in vv]
 if min(radii)<1e-6 or max(radii)-min(radii)>1e-5:return False
 zs=sorted(set(round(v.z,6) for v in vv))
 if len(zs)!=2:return False
 uv=o.data.uv_layers.active or o.data.uv_layers.new();scale=1.25;rx=max(radii)*abs(o.scale.x);ry=max(radii)*abs(o.scale.y)
 perimeter=math.pi*(3*(rx+ry)-math.sqrt((3*rx+ry)*(rx+3*ry)))
 for p in o.data.polygons:
  cap=max(vv[o.data.loops[i].vertex_index].z for i in p.loop_indices)-min(vv[o.data.loops[i].vertex_index].z for i in p.loop_indices)<1e-6
  angles=[(math.atan2(vv[o.data.loops[i].vertex_index].y,vv[o.data.loops[i].vertex_index].x)/math.tau)%1 for i in p.loop_indices];seam=max(angles)-min(angles)>.5
  for i,a in zip(p.loop_indices,angles):
   c=vv[o.data.loops[i].vertex_index]
   uv.data[i].uv=(c.x*abs(o.scale.x)*scale,c.y*abs(o.scale.y)*scale) if cap else (((a+1 if seam and a<.5 else a)*perimeter*scale),c.z*abs(o.scale.z)*scale)
 return True

def sweep_uv(o):
 """Retain the authored rings and unwrap by real centreline/circumference."""
 vv=[v.co for v in o.data.vertices];N=len(vv);n=None
 for candidate in (6,8,16,24,32,48,64):
  if N%candidate or N<candidate*2:continue
  normal=(vv[1]-vv[0]).cross(vv[2]-vv[0])
  if normal.length<1e-10:continue
  normal.normalize()
  if max(abs((v-vv[0]).dot(normal)) for v in vv[:candidate])<1e-5 and max(abs((v-vv[0]).dot(normal)) for v in vv[candidate:candidate+min(candidate,6)])>1e-5:n=candidate;break
 if n is None:return False
 hollow=bool(o.get('full_hollow_wall'));rings=N//n//(2 if hollow else 1)
 if rings<2:return False
 centers=[sum(vv[k*n:(k+1)*n],Vector())/n for k in range(rings)];radii=[]
 for k,c in enumerate(centers):radii.append(sum((v-c).length for v in vv[k*n:(k+1)*n])/n)
 # Reject accidental detection in a bevelled box or unrelated donor geometry.
 if any(max(abs((v-c).length-radii[k]) for v in vv[k*n:(k+1)*n])>max(.0001,radii[k]*.02) for k,c in enumerate(centers)):return False
 closed=not hollow and all(len(p.vertices)==3 for p in o.data.polygons) and ('winding' in o.name or 'drive belt' in o.name)
 lengths=[0.]
 for a,b in zip(centers,centers[1:]):lengths.append(lengths[-1]+(b-a).length)
 total=lengths[-1]+((centers[-1]-centers[0]).length if closed else 0)
 uv=o.data.uv_layers.active or o.data.uv_layers.new();scale=1.25
 for p in o.data.polygons:
  info=[]
  for i in p.loop_indices:
   idx=o.data.loops[i].vertex_index;layer=idx//(rings*n);ring,j=divmod(idx%(rings*n),n);info.append((i,layer,ring,j))
  cap=len(set(r for _,_,r,_ in info))==1
  if cap:
   r=info[0][2];c=centers[r];a=(vv[r*n]-c).normalized();t=(centers[min(r+1,rings-1)]-centers[max(r-1,0)]).normalized();b=t.cross(a).normalized()
   for i,layer,ring,j in info:
    q=vv[o.data.loops[i].vertex_index]-c;uv.data[i].uv=(q.dot(a)*scale,q.dot(b)*scale)
  else:
   seam=max(j for _,_,_,j in info)-min(j for _,_,_,j in info)>n/2;endseam=closed and max(r for _,_,r,_ in info)-min(r for _,_,r,_ in info)>rings/2
   for i,layer,r,j in info:
    radius=(vv[layer*rings*n+r*n+j]-centers[r]).length;u=(j+n if seam and j<n/2 else j)/n;v=total if endseam and r==0 else lengths[r];uv.data[i].uv=(u*math.tau*radius*scale,v*scale)
 return True

def panel_uv(o):
 uv=o.data.uv_layers.active or o.data.uv_layers.new()
 for p in o.data.polygons:
  axes=sorted(range(3),key=lambda k:abs(p.normal[k]))[:2]
  for i in p.loop_indices:
   c=o.data.vertices[o.data.loops[i].vertex_index].co;uv.data[i].uv=(c[axes[0]]*abs(o.scale[axes[0]])*1.25,c[axes[1]]*abs(o.scale[axes[1]])*1.25)
