"""Forged alternating oval links captured by pins in paired bored lugs."""
import math
from mathutils import Vector
from common import mesh, rod, box, swept
from proportions import point as fitted_point

def _lug(name, center, sign, material, half_spacing):
    # Profile of the two lugs in the YZ plane. Both have through bores on X.
    # The rear of each lug is drawn out into a mounting tang on the bolted pad.
    c=Vector(center); x=c.x+sign*half_spacing
    verts=[]; faces=[]; n=28
    for side in (-1,1):
        for inner in (False,True):
            for i in range(n):
                a=math.tau*i/n; co,si=math.cos(a),math.sin(a)
                r=.0147 if inner else .030
                y=r*co
                if not inner and co>0: y+=.094*co**2
                verts.append((x+side*.008,c.y+y,c.z+r*si))
    for i in range(n):
        j=(i+1)%n
        faces.extend(((i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),
                      (i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)))
    return mesh(name,verts,faces,material,.0018)

def _bracket(name,p,kind,side,top):
    p=Vector(p)
    metal='steel' if kind=='void' else 'bronze'
    # Positive Y goes into the structure. Upper pad keys into the inclined knee,
    # lower pad keys into the vertical face of the cast front shoe.
    rear=-.749 if top else -.812
    face=p.y+.073
    box(name+' | bolted backplate',(p.x,(rear+face)/2,p.z),(.108,rear-face,.093),metal,.009)
    for dz in (-.030,.030):
        a=(p.x,face-.008,p.z+dz); b=(p.x,face+.004,p.z+dz)
        rod(name+' | mount stud',a,b,.014,'steel',6)
    half_spacing=.043 if kind=='void' and top else .034
    for s in (-1,1):_lug(name+' | pierced fork ear',p,s,metal,half_spacing)
    rod(name+' | hardened cross pin',p+Vector((-.057,0,0)),p+Vector((.057,0,0)),.012,'steel',16)
    for x,r,m,rad in ((-.056,.014,'dark',20),(.053,.019,'brass',6)):
        a=p+Vector((x-.005,0,0));b=p+Vector((x+.005,0,0))
        rod(name+' | keeper',a,b,r,m,rad)
    return p

def _oval(name,center,tangent,width_axis,half,radius,stock,material):
    t=tangent.normalized(); w=width_axis.normalized(); c=Vector(center)
    pts=[]
    for end in (1,-1):
        for k in range(13):
            a=math.pi*k/12
            pts.append(c+end*(w*(radius*math.cos(a))+t*(half-radius+radius*math.sin(a))))
    ob=swept(name,pts,stock,material,True,10)
    ob['stock_radius']=stock;ob['link_inner_width']=2*(radius-stock)
    return ob

def build_chains(kind):
    height={'junior':.15,'intermediate':.12,'senior':.17,'planetary':.19,'void':.20}[kind]
    # Void's inspection-cover keeper occupies the top of the common riser.
    # Bolt its chain clevis to the casting immediately below the keeper.
    upper_height=.712 if kind=='void' else .765
    for side in (-1,1):
        prefix=('Port' if side<0 else 'Starboard')+' | tie chain'
        a=_bracket(prefix+' | upper knee', fitted_point((side*.789,-.878,upper_height),kind),kind,side,True)
        b=_bracket(prefix+' | anchor shoe',fitted_point((side*.944,-.983,height+.031),kind),kind,side,False)
        def route(t):
            # Very slight slack bows outward from the inclined armor, not into it.
            return a.lerp(b,t)+Vector((side*.011,-.033,-.002))*math.sin(math.pi*t)
        samples=200
        table=[(0.,route(0))]
        total=0.
        for j in range(1,samples+1):
            p=route(j/samples); total+=(p-table[-1][1]).length;table.append((total,p))
        def point(d):
            if d<=0:return a
            if d>=total:return b
            for j in range(1,len(table)):
                if table[j][0]>=d:
                    sd,p=table[j-1];ed,q=table[j];return p.lerp(q,(d-sd)/(ed-sd))
        count=11
        wire=.0088 if kind=='void' else .0082
        # Allow the curved, faceted returns to wrap past the contact point. A
        # pitch derived from straight, tangent cylinders clips on the curved span.
        joint_setback=2*wire+.0012
        pin_setback=wire+.012+.0016
        half=(total+(count-1)*joint_setback+2*pin_setback)/(2*count)
        pitch=2*half-joint_setback
        for j in range(count):
            d=half-pin_setback+pitch*j; mid=point(d)
            tangent=(point(d+.006)-point(d-.006)).normalized()
            # Terminal links face along the pin; alternate planes by exactly 90 degrees.
            pin=Vector((1,0,0));u=pin.cross(tangent).normalized();v=tangent.cross(u).normalized()
            direction=u if j%2==0 else v
            _oval(prefix+' | forged link %02d'%(j+1),mid,tangent,direction,half,.0245,wire,
                  'steel' if kind=='void' else ('brass' if j%3==1 else 'bronze'))
