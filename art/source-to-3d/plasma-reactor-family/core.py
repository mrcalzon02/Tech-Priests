"""Cast reactor drums, cut-through containment flanges and keyed plasma rotors."""
from math import atan2, cos, pi, sin
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
from forge import group, mesh

TAU = 2.0 * pi


class Surface:
    """Weld coincident points as a surface is assembled from adjacent patches."""
    def __init__(self):
        self.verts = []
        self.faces = []
        self.lookup = {}

    def face(self, points):
        indices = []
        for p in points:
            key = tuple(round(v, 7) for v in p)
            if key not in self.lookup:
                self.lookup[key] = len(self.verts)
                self.verts.append(p)
            i = self.lookup[key]
            if not indices or indices[-1] != i:
                indices.append(i)
        if len(indices) > 1 and indices[0] == indices[-1]:
            indices.pop()
        if len(indices) >= 3:
            self.faces.append(tuple(indices))

    def emit(self, name, material, radius):
        verts = [(x * radius, y * radius, (1.15 + z) * radius) for x, y, z in self.verts]
        if self.faces:
            mesh(name, verts, self.faces, material)


def pole(rad, ang, y):
    return (rad * cos(ang), y, rad * sin(ang))


def inlay(surface, front, depth):
    """Give a front-facing detail a closed return, including a buried rear face."""
    back = [(x,y+depth,z) for x,y,z in front]
    surface.face(front)
    surface.face(back[::-1])
    for j in range(len(front)):
        k=(j+1)%len(front)
        surface.face((front[k],front[j],back[j],back[k]))


def turn(surface, profile, lo=0, hi=TAU, steps=128):
    """Turn a cross-section in (radius, depth) around the drum shaft."""
    def ring(a):
        return [pole(r, a, y) for r, y in profile]

    old = ring(lo)
    for i in range(1, steps + 1):
        new = ring(lo + (hi - lo) * i / steps)
        for j in range(len(profile)):
            k = (j + 1) % len(profile)
            surface.face((old[j], old[k], new[k], new[j]))
        old = new
    if hi-lo < TAU-0.000001:
        surface.face(ring(lo)[::-1])
        surface.face(ring(hi))


def ring(name, profile, material, r):
    surf = Surface()
    turn(surf, profile)
    surf.emit(name, material, r)


def chamfer_ring(name, ri, ro, front, back, bevel, material, r):
    c = min(bevel, (ro - ri) * .45, (back - front) * .42)
    ring(name, [(ri+c,front),(ro-c,front),(ro,front+c),(ro,back-c),
                (ro-c,back),(ri+c,back),(ri,back-c),(ri,front+c)], material, r)


def bolt_field(name, points, size, material, r, front=True):
    """Join hexagonal screw heads within a single serviceable bolt circle."""
    surf = Surface()
    side = -1 if front else 1
    for x,y,z in points:
        ang = atan2(z, x) + pi/6
        back = [(x+size*cos(ang+i*TAU/6), y, z+size*sin(ang+i*TAU/6)) for i in range(6)]
        rim = [(x+size*cos(ang+i*TAU/6),y+side*.63*size,z+size*sin(ang+i*TAU/6)) for i in range(6)]
        top = [(x+.8*size*cos(ang+i*TAU/6),y+side*.83*size,z+.8*size*sin(ang+i*TAU/6)) for i in range(6)]
        surf.face(top if front else top[::-1])
        surf.face(back[::-1] if front else back)
        for a,b in ((back,rim),(rim,top)):
            for i in range(6):
                j = (i+1)%6
                f = (a[i],a[j],b[j],b[i])
                surf.face(f if front else f[::-1])
    surf.emit(name,material,r)


def bolts(name, rad, y, count, size, material, r, offset=0, front=True):
    bolt_field(name,[pole(rad,offset+TAU*i/count,y) for i in range(count)], size,material,r,front)


def perforated_flange(tier,r):
    n = (10,12,16)[tier-1]
    mid,inner,outer = .812,.698,.925
    dy = -.536
    back = -.467
    step = TAU/n
    rad = .037
    half_angle = .311*step
    body = Surface()
    front_y = dy
    for k in range(n):
        c = (k+.5)*step
        tip = rad/mid
        straight = half_angle-tip
        # Distribute topology along the two rounded ends and the circular slot sides.
        hole = [(-straight-tip*cos(i*pi/12),rad*sin(i*pi/12)) for i in range(7)]
        hole.extend([(-straight+2*straight*i/8, rad) for i in range(1,9)])
        hole.extend([(straight+tip*sin(i*pi/12), rad*cos(i*pi/12)) for i in range(1,7)])
        samples = [(-.5*step,0)] + hole + [(.5*step,0)]
        for j,((a,h),(b,g)) in enumerate(zip(samples,samples[1:])):
            a += c
            b += c
            spans = [(inner,mid-h,inner,mid-g),(mid+h,outer,mid+g,outer)]
            for ra,rb,rc,rd in spans:
                for y in (front_y,back):
                    f = [pole(ra,a,y),pole(rb,a,y),pole(rd,b,y),pole(rc,b,y)]
                    body.face(f if y==front_y else f[::-1])
            for rs0,rs1,flip in ((outer,outer,False),(inner,inner,True)):
                f = [pole(rs0,a,front_y),pole(rs0,a,back),pole(rs1,b,back),pole(rs1,b,front_y)]
                body.face(f[::-1] if flip else f)
            if j!=0 and j!=len(samples)-2:
                for sign in (-1,1):
                    f = [pole(mid+sign*h,a,front_y),pole(mid+sign*g,b,front_y),
                         pole(mid+sign*g,b,back),pole(mid+sign*h,a,back)]
                    body.face(f if sign==1 else f[::-1])
    body.emit("Machined face casting • open arc ports", "steel", r)
    chamfer_ring("Turned exterior witness edge", .919,.948,-.54,-.453,.007,"edge",r)
    chamfer_ring("Inner machined reveal", .668,.702,-.545,-.451,.009,"edge",r)
    chamfer_ring("Bolt race / inner seal", .637,.671,-.51,-.444,.008,"black",r)
    chamfer_ring("Energized annular jacket",.757,.868,-.452,-.423,.014,"plasma",r)
    bolts("Casing lock studs",mid,-.537,n,.021,"brass",r)
    # Index scores are engraved in the wide margin and aligned with the studs.
    marks = Surface()
    for i in range(n):
        a = TAU*i/n
        for delta,length in ((-.026,.016),(0,.027),(.026,.016)):
            t = a+delta
            inlay(marks,[pole(.872,t-.0025,-.537),pole(.872+length,t-.0025,-.537),
                         pole(.872+length,t+.0025,-.537),pole(.872,t+.0025,-.537)],.003)
    marks.emit("Casing witness graduations","black",r)



def face_clamps(tier,r):
    """Keyed dogs bridge the forward seal flange and the stave compression hoop."""
    clips=Surface()
    noses=Surface()
    screws=Surface()
    inner=Surface()
    count=(6,8,10)[tier-1]
    width=(.065,.063,.056)[tier-1]
    for i in range(count):
        a=pi/2 + (i+.5)*TAU/count
        turn(clips,[(.914,-.552),(.984,-.552),(1.023,-.510),(1.023,-.320),
             (1.004,-.286),(.978,-.286),(.978,-.382),(.962,-.402),(.952,-.488),
             (.914,-.512)],a-width,a+width,7)
        turn(noses,[(.917,-.557),(.972,-.557),(.983,-.548),(.976,-.541),
             (.918,-.541)],a-width+.004,a+width-.004,6)
        for y in [-.464,-.347]:
            base=1.023
            def cap(rad,h,angle):
                dx=cos(a)
                dz=sin(a)
                v=rad*sin(angle)
                return ((base+h)*dx-v*dz,y+rad*cos(angle),(base+h)*dz+v*dx)
            for surf,r0,r1,h0,h1,steps in [(inner,.021,.021,-.002,.004,12),(screws,.017,.014,.004,.014,6)]:
                top=[cap(r1,h1,j*TAU/steps) for j in range(steps)]
                bottom=[cap(r0,h0,j*TAU/steps) for j in range(steps)]
                surf.face(top)
                surf.face(bottom[::-1])
                for j in range(steps):
                    k=(j+1)%steps
                    surf.face([bottom[j],bottom[k],top[k],top[j]])
    clips.emit("Forged stave retention dogs","iron",r)
    noses.emit("Machined clamp noses","steel",r)
    inner.emit("Clamp-head sockets","black",r)
    screws.emit("Radial clamp screws","brass",r)

def chamber_shell(tier, r, end):
    n = (12,14,16)[tier-1]
    group("Pressure vessel")
    ring("Spun inner jacket",[(.608,-.428),(.904,-.428),(.933,-.386),(.933,end-.028),
         (.905,end),(.608,end),(.608,end-.052),(.628,end-.087),(.628,-.392)],"iron",r)
    chamfer_ring("Face gasket / furnace black",.668,.964,-.444,-.403,.013,"black",r)
    group("Vermilion barrel armor")
    # Each stave is a continuous cast arc. Wide armor belts are interrupted by compressed seams.
    spans = ([( -.39,end-.045)] if tier==1 else
             [(-.39,.20),(.241,end-.055)] if tier==2 else
             [(-.39,.115),(.157,.571),(.615,end-.053)])
    plates = {"red":Surface(),"red_dark":Surface()}
    cap = Surface()
    for b,(f,h) in enumerate(spans):
        for j in range(n):
            a = TAU*j/n+pi/n
            gap = (.015 if tier==1 else .012)
            lo,hi = a-pi/n+gap,a+pi/n-gap
            color = "red_dark" if (j+2*b)%5 in (0,3) else "red"
            turn(plates[color],[(.926,f),(.960,f),(.984,f+.029),(.984,h-.025),(.960,h),(.926,h)],lo,hi,8)
            # Narrow cast chamfers on both forward side corners catch highlights.
            turn(cap,[(.959,f-.003),(.969,f+.006),(.978,f+.018),(.974,f+.021),(.958,f+.01)],
                 lo+.013,hi-.013,7)
    for color,s in plates.items():
        s.emit("Interlocked stove-enamel casing • "+color,color,r)
    cap.emit("Stave nosing • worn iron", "steel",r)
    hoop_positions = [(-.440,-.376),(end-.070,end-.004)]
    hoop_positions.extend([(.194,.248)] if tier==2 else [(.108,.165),(.564,.623)] if tier==3 else [])
    for i,(f,b) in enumerate(hoop_positions):
        chamfer_ring("Compression hoop "+str(i+1),.921,1.000,f,b,.013,"iron",r)
        chamfer_ring("Hoop milled crest "+str(i+1),.993,1.003,f+.018,b-.017,.003,"steel",r)
    group("Rear service bulkhead")
    ring("Recessed backhead",[(.002,end-.069),(.667,end-.069),(.715,end-.026),(.942,end-.026),
         (.955,end-.01),(.955,end+.03),(.930,end+.055),(.747,end+.055),(.693,end+.015),(.002,end+.015)],"iron",r)
    chamfer_ring("Rear split-flange silver band",.781,.906,end+.048,end+.072,.006,"steel",r)
    bolts("Rear flange stud circle",.849,end+.072,n,.023,"edge",r,pi/n,False)
    chamfer_ring("Terminal ceramic gasket",.373,.420,end+.015,end+.046,.008,"ceramic",r)
    chamfer_ring("Rear service door boss",.015,.390,end+.025,end+.095,.020,"red_dark",r)
    chamfer_ring("Inspection plate rim",.182,.245,end+.085,end+.118,.008,"brass",r)
    bolts("Inspection plate fixings",.214,end+.118,8,.013,"edge",r,pi/8,False)
    blades = Surface()
    for i in range(14):
        a = TAU*i/14
        turn(blades,[(.438,end+.015),(.669,end+.015),(.661,end+.048),(.445,end+.067)],a-.036,a+.036,3)
    blades.emit("Radial service-door reinforcement","steel",r)


def rotor(tier,r):
    group("Magnetic throat")
    ring("Concentric throat liner",[(.567,-.387),(.594,-.446),(.636,-.464),(.655,-.446),(.655,-.094),
         (.541,-.094),(.541,-.174),(.566,-.221)],"black",r)
    for i in range(3):
        y = -.408+i*.066
        chamfer_ring("Toroidal field winding "+str(i+1),.567+i*.005,.626,y,y+.028,.008,
                     "copper" if i==0 else "plasma_dim",r)
    teeth = Surface()
    for i in range(30+6*tier):
        a=i*TAU/(30+6*tier)
        turn(teeth,[(.594,-.438),(.626,-.455),(.630,-.452),(.629,-.421),(.605,-.404),(.592,-.410)],a-.033,a+.033,3)
    teeth.emit("Slotted field pole shoes","steel",r)
    group("Helical plasma impeller")
    ring("Recessed impeller shroud",[(.035,-.147),(.596,-.147),(.596,-.104),(.035,-.104)],"plasma_dim",r)
    # Broad vanes accelerate around the shaft. Each vane has a hot trailing fillet
    # and a darker turned-under lip, with the underlying shroud visible between vanes.
    count=(8,9,11)[tier-1]
    materials = [("plasma_hot",.00,.082),("plasma",.082,.72),("plasma_dim",.72,1)]
    pitch = TAU/count
    for mat,lo,hi in materials:
        surf = Surface()
        for i in range(count):
            def p(t,w):
                rad = .121 + .448*t
                ang = pitch*i + .90*t**.87 + pitch*w*(.83-.15*t)
                y = -.283+.109*t-.044*sin(w*pi)*(1-.30*t)
                return pole(rad,ang,y)
            for j in range(20):
                t0,t1 = j/20,(j+1)/20
                for s in range(3):
                    w0,w1=lo+(hi-lo)*s/3,lo+(hi-lo)*(s+1)/3
                    front=[p(t0,w0),p(t1,w0),p(t1,w1),p(t0,w1)]
                    back=[(x,y+.019,z) for x,y,z in front]
                    surf.face(front)
                    surf.face(back[::-1])
                    for edge,outer in enumerate((s==0,j==19,s==2,j==0)):
                        if outer:
                            nxt=(edge+1)%4
                            surf.face((front[nxt],front[edge],back[edge],back[nxt]))
        surf.emit("Fluted plasma blades • "+mat, mat,r)
    chamfer_ring("Pocketed shaft bearing",.047,.246,-.408,-.236,.030,"iron",r)
    chamfer_ring("Thrust bearing brass race",.135,.216,-.456,-.394,.014,"copper",r)
    chamfer_ring("Seal stem",.047,.143,-.604,-.442,.015,"black",r)
    for i in range(3):
        y=-.463-i*.042
        chamfer_ring("Shaft oil labyrinth "+str(i+1),.126,.159,y-.022,y,.005,"steel",r)


def skull(name,r):
    """A pierced die-cast skull; eye sockets and nasal aperture penetrate the relief."""
    outline=[(0,1),(.40,.95),(.67,.75),(.81,.43),(.82,.11),(.70,-.18),(.75,-.34),
             (.57,-.47),(.42,-.41),(.39,-.81),(.24,-.91),(0,-.95),(-.26,-.91),
             (-.40,-.81),(-.42,-.41),(-.57,-.47),(-.75,-.34),(-.70,-.18),(-.82,.11),
             (-.81,.43),(-.67,.75),(-.40,.95)]
    eye=[(.135,.14),(.29,.19),(.615,.265),(.637,.092),(.54,-.078),(.359,-.141),(.186,-.083)]
    nose=[(0,-.097),(.149,-.384),(.035,-.367),(0,-.339),(-.035,-.367),(-.149,-.384)]
    rings=[outline,eye,[(-x,z) for x,z in eye],nose]
    coords=[]
    edges=[]
    for poly in rings:
        start=len(coords)
        coords.extend([Vector(p) for p in poly])
        edges.extend([(start+i,start+(i+1)%len(poly)) for i in range(len(poly))])
    xy,_,faces,*_ = delaunay_2d_cdt(coords,edges,[],0,1e-6)
    def inside(x,z,poly):
        state=False
        for (a,b),(c,d) in zip(poly,poly[1:]+poly[:1]):
            if (b>z)!=(d>z) and x < a+(c-a)*(z-b)/(d-b):
                state=not state
        return state
    side=.152
    def facep(x,z,back=False):
        relief = .022*(1-min(1,abs(x)))+.013*(z+.2)
        return (x*side,-.647 if back else -.675-relief,z*side+.009)
    surf=Surface()
    for face in faces:
        x=sum(xy[i].x for i in face)/len(face)
        z=sum(xy[i].y for i in face)/len(face)
        if inside(x,z,outline) and not any(inside(x,z,poly) for poly in rings[1:]):
            surf.face([facep(*xy[i]) for i in face])
            surf.face([facep(*xy[i],back=True) for i in face[::-1]])
    for index,poly in enumerate(rings):
        area=sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(poly,poly[1:]+poly[:1]))
        order=poly if (area>0)==(index==0) else poly[::-1]
        for a,b in zip(order,order[1:]+order[:1]):
            surf.face([facep(*a),facep(*a,back=True),facep(*b,back=True),facep(*b)])
    surf.emit(name,"ivory",r)
    teeth=Surface()
    for x in [-.26,-.09,.09,.26]:
        shape=[(x-.052,-.526),(x+.053,-.520),(x+.042,-.78),(x-.04,-.80)]
        inlay(teeth,[(xx*side,facep(xx,zz)[1]-.0029,zz*side+.009) for xx,zz in shape[::-1]],.004)
    teeth.emit("Engraved teeth on skull die","brass",r)


def seal(tier,r):
    group("Cog-and-skull spindle seal")
    teeth=(13,15,17)[tier-1]
    part=Surface()
    outline=[]
    for i in range(teeth):
        for f,rad in [(0,.209),(.16,.209),(.20,.239),(.58,.239),(.63,.209)]:
            outline.append((TAU*(i+f)/teeth,rad))
    for j,(a,ra) in enumerate(outline):
        b,rb=outline[(j+1)%len(outline)]
        T=lambda rad,t,y:pole(rad,t,y)
        part.face([T(.122,a,-.636),T(ra-.004,a,-.636),T(rb-.004,b,-.636),T(.122,b,-.636)])
        part.face([T(ra-.004,a,-.636),T(ra,a,-.630),T(rb,b,-.630),T(rb-.004,b,-.636)])
        part.face([T(ra,a,-.630),T(ra,a,-.586),T(rb,b,-.586),T(rb,b,-.630)])
        part.face([T(.122,b,-.586),T(rb,b,-.586),T(ra,a,-.586),T(.122,a,-.586)])
        part.face([T(.122,a,-.636),T(.122,b,-.636),T(.122,b,-.586),T(.122,a,-.586)])
    part.emit("Induction-spindle brass cog","brass",r)
    chamfer_ring("Ebon enamel spindle medallion",.001,.190,-.652,-.618,.008,"black",r)
    chamfer_ring("Beaded edge of seal",.169,.182,-.658,-.649,.0025,"brass",r)
    skull("Pierced shrine-maker's skull",r)
    bolts("Medallion retaining rivets",.158,-.652,4,.007,"brass",r,pi/4)


def build(tier,r):
    end=(.47,.78,1.10)[tier-1]
    chamber_shell(tier,r,end)
    group("Perforated containment flange")
    perforated_flange(tier,r)
    face_clamps(tier,r)
    rotor(tier,r)
    seal(tier,r)
