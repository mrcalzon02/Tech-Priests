"""Coolant galleries, induction jackets, and caged thermic regulators."""
from math import cos, sin, pi, sqrt
from forge import box, cyl, tube, mesh, group

TAU = 2*pi


class Gallery:
    def __init__(self, tier, radius):
        self.tier = tier
        self.r = radius

    def p(self, value):
        return tuple(v*self.r for v in value)

    def block(self, label, pos, dim, mat, chamfer=0):
        return box(label, self.p(pos), self.p(dim), mat, chamfer*self.r)

    def cylinder(self, label, start, end, rad, material, sides=32):
        return cyl(label, self.p(start), self.p(end), rad*self.r, material, sides=sides)

    def route(self, name, pts, rad, mat, fillet):
        return tube(name, [self.p(p) for p in pts], rad*self.r, mat, sides=16 if rad>.03 else 10, bend=fillet*self.r)

    def section(self, label, axis, center, profile, mat, sides=32, phase=0):
        self.profiles(label, axis, [(center, profile)], mat, sides, phase)

    def profiles(self, label, axis, instances, mat, sides=32, phase=0):
        # All profiles run in increasing axial order and close at both ends.
        # Parallel/perpendicular vectors form a right-handed coordinate system.
        verts, faces = [], []
        for center, rings in instances:
            cx,cy,cz = center
            begin=len(verts)
            for length,radius in rings:
                for k in range(sides):
                    a = phase + TAU*k/sides
                    u,v = radius*cos(a), radius*sin(a)
                    if axis=="z": p=(cx+u,cy+v,cz+length)
                    elif axis=="x": p=(cx+length,cy+u,cz+v)
                    else: p=(cx+v,cy+length,cz+u)
                    verts.append(self.p(p))
            for j in range(len(rings)-1):
                lo=begin+j*sides
                hi=lo+sides
                for k in range(sides):
                    n=(k+1)%sides
                    faces.append((lo+k,lo+n,hi+n,hi+k))
            end=begin+(len(rings)-1)*sides
            faces.append(tuple(begin+k for k in reversed(range(sides))))
            faces.append(tuple(end+k for k in range(sides)))
        mesh(label, verts, faces, mat)

    def flange(self, axis, c, rad, label, finish="steel", bolts=True):
        d=rad*.23
        self.section(label+" forged flange",axis,c,[
            (-d*1.25,rad*.77),(-d,rad*.90),(-d*.70,rad),(d*.66,rad),(d,rad*.94),(d,rad*.78)],
            finish)
        self.section(label+" parting line",axis,c,[(-d*.10,rad*1.004),(d*.11,rad*1.004)],"black")
        if not bolts: return
        instances=[]
        for n in range(8):
            a=TAU*(n+.5)/8
            u,v=rad*.815*cos(a),rad*.815*sin(a)
            if axis=="z": base=(c[0]+u,c[1]+v,c[2])
            elif axis=="x": base=(c[0],c[1]+u,c[2]+v)
            else: base=(c[0]+v,c[1],c[2]+u)
            size=rad*.098
            for sign in (-1,1):
                p=sorted([(sign*d*.79,size*.85),(sign*d*.97,size),
                          (sign*d*1.32,size),(sign*d*1.43,size*.79)])
                instances.append((base,p))
        self.profiles(label+" flange nuts",axis,instances,"brass",6,pi/6)

    def sleeve(self, y, z, a, b, rad):
        w=b-a
        self.section("Removable cast pipe jacket","x",(a,y,z),[
            (0,rad*.93),(w*.035,rad*1.04),(w*.095,rad*1.12),
            (w*.115,rad*1.12),(w*.14,rad*1.025),(w*.84,rad*1.025),
            (w*.905,rad*1.11),(w*.94,rad*1.11),(w,rad*.97)],"iron",40)
        for sign in (-1,1):
            v=sign*.74*rad
            h=.70*rad
            self.cylinder("Cast sleeve reinforcing bead",(a+w*.16,y+v,z+h),(b-w*.16,y+v,z+h),rad*.050,"steel",8)

    def pulse_window(self, y, z, a, b, rad):
        c=(a,y,z)
        w=b-a
        self.section("Corrugated plasma conduit","x",c,[(0,rad*.95),(.028,rad),(w-.028,rad),(w,rad*.95)],"plasma_dim",40)
        ribs=[]
        count=max(5,round(w/.058))
        pitch=(w-.034)/count
        for i in range(count):
            p=.017+(i+.5)*pitch
            ribs.append((c,[(p-pitch*.41,rad*.99),(p-pitch*.32,rad*1.09),
                            (p-pitch*.19,rad*1.16),(p+pitch*.16,rad*1.16),
                            (p+pitch*.33,rad*1.105),(p+pitch*.41,rad*.99)]))
        self.profiles("Luminous induction ribs","x",ribs,"plasma",40)
        for x in (a-.010,b+.010):
            self.flange("x",(x,y,z),rad*1.40,"Inductor clamp",bolts=True)
        # Two narrow, off-axis rails protect the exposed bellows.
        for angle in (pi*.25,pi*1.23):
            v=cos(angle)*rad*1.22
            h=sin(angle)*rad*1.22
            self.cylinder("External bellows tie rod",(a,y+v,z+h),(b,y+v,z+h),.009,"edge",8)

    def saddle(self, x, y, z, rad):
        # Foot matches the curvature of the core barrel where this casting seats.
        bottom=1.15+sqrt(max(.04,1-x*x))-.055
        top=z-rad*.52
        gap=top-bottom
        if gap < .13: return
        self.block("Machined saddle foot",(x,y,bottom+.02),(.24,.21,.064),"steel",.014)
        # Continuous raked pair of gussets; the open triangular bay reads in profile.
        for sx in (-1,1):
            xx=sx
            coords=[
                (x+xx*.124,bottom+.032),(x+xx*.069,bottom+.032),
                (x+xx*.016,top-.038),(x+xx*.036,top),
                (x+xx*.081,top-.012)]
            verts=[self.p((a,y+depth,b)) for depth in (-.045,.045) for a,b in coords]
            n=len(coords)
            face=[tuple(reversed(range(n))),tuple(range(n,2*n))]
            face.extend((k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n))
            # The mirrored side uses the opposite winding.
            if sx<0: face=[tuple(reversed(f)) for f in face]
            mesh("Raked saddle casting",verts,face,"red_dark")
        self.flange("x",(x,y,z),rad*1.26,"Saddle strap","steel",False)
        if gap>.44:
            self.cylinder("Saddle stiffening web",(x-.072,y,bottom+.09),(x+.046,y,top-.09),.019,"steel",8)

    def regulator(self, x,y, top, index):
        group("Thermic regulator %s"%(index+1))
        c=(x,y,0)
        w=(.207,.211,.214)[self.tier-1]
        lo=.57
        hi=top-.26
        # Gusseted gland and crisp shoulder transitions on the axial castings.
        self.section("Octagonal footplate","z",c,[(.16,w*1.08),(.18,w*1.26),(.235,w*1.26),(.26,w*1.12)],"red_dark",8,pi/8)
        self.section("Return plenum and lower gland","z",c,[
            (.233,w*.96),(.26,w*1.02),(.29,w*1.03),
            (.315,w*.86),(.403,w*.86),(.46,w*1.02),(.51,w*1.035),(.53,w*.86),(.596,w*.85)],"iron",40)
        self.flange("z",(x,y,.52),w*1.055,"Lower gland")
        self.section("Shielded thermic core","z",c,[(lo-.04,w*.73),(lo,w*.76),(hi,w*.76),(hi+.045,w*.73)],"plasma_dim",48)
        pitch_nom=.105 if self.tier==1 else .100
        rings=max(7,round((hi-lo)/pitch_nom))
        pitch=(hi-lo)/rings
        ribs, lips = [], []
        for k in range(rings):
            z=lo+(k+.5)*pitch
            ribs.append((c,[
                (z-pitch*.405,w*.76),(z-pitch*.34,w*.82),(z-pitch*.21,w*.93),
                (z+pitch*.08,w*.94),(z+pitch*.25,w*.88),(z+pitch*.40,w*.77)]))
            if k in (1,rings-2):
                lips.append((c,[(z-pitch*.055,w*.945),(z+pitch*.040,w*.945)]))
        self.profiles("Glowing thermic expansion bellows","z",ribs,"plasma",48)
        self.profiles("Hot bellows crests","z",lips,"plasma_hot",48)
        self.section("Cast regulator bonnet","z",c,[
            (hi-.035,w*.86),(hi+.008,w*1.035),(hi+.035,w*1.145),(hi+.114,w*1.145),
            (hi+.135,w*.95),(hi+.175,w*.90),(hi+.191,w*.65),(top,w*.61)],"iron",40)
        self.flange("z",(x,y,hi+.037),w*1.13,"Bonnet")
        self.section("Inspection bonnet knuckle","z",c,[(top-.094,w*.67),(top-.072,w*.76),(top-.035,w*.76),(top,w*.62)],"steel",12,pi/12)
        # Narrow structural cage ribs stop against extruded feet and bolted crown.
        # Deliberately keep the near-right opening wide enough to see the plasma.
        for k in range(4):
            a=(k+.18)*TAU/4
            ux,uy=cos(a),sin(a)
            t=(-uy,ux)
            x0,y0=x+w*.998*ux,y+w*.998*uy
            self.route("Thermic cage stile",[
                (x+w*.91*ux,y+w*.91*uy,lo-.055),(x0,y0,lo+.105),
                (x0,y0,hi-.095),(x+w*1.035*ux,y+w*1.035*uy,hi+.06)],.014,"steel",.022)
            for z in (lo-.024,hi+.042):
                self.cylinder("Stile anchor lug",(x0-.022*t[0],y0-.022*t[1],z),(x0+.022*t[0],y0+.022*t[1],z),.027,"brass",8)
        # One copper takeoff from the front of each lower plenum into the shared return.
        self.route("Coolant condensate takeoff",[(x,y,.36),(x+.24,y,.36),(x+.24,y,.267),(x+.284,y,.267)],.039,"copper",.048)
        self.flange("x",(x+.197,y,.36),.056,"Takeoff union","steel",False)
        # Small inclined relief valve separates the bonnet silhouette from the feed pipe.
        vx=x+w*.15; vy=y-w*.84
        self.section("Bonnet pressure relief","z",(vx,vy,0),[(hi+.097,.036),(hi+.132,.044),(hi+.166,.043),(hi+.171,.030),(hi+.206,.030),(hi+.214,.012)],"brass",10)

    def line(self,index,y,z,top,xright):
        group("Plasma transfer gallery %s"%(index+1))
        left= -1.18 if index%2==0 else -1.23
        rad=(.096,.108,.117)[self.tier-1]
        zfeed=(.93,1.54,1.59)[self.tier-1]+.025*(index%2)
        rear=(.47,.78,1.10)[self.tier-1]
        if y>rear:
            socket_y=rear-.10
            points=[(-.88,socket_y,zfeed),(left,socket_y,zfeed),(left,y,zfeed),
                    (left,y,z),(xright,y,z),(xright,y,top-.048)]
        else:
            socket_y=y
            points=[(-.88,y,zfeed),(left,y,zfeed),(left,y,z),(xright,y,z),(xright,y,top-.048)]
        self.route("Continuous pressure pipe with swept elbows",points,rad,"iron",.19)
        self.flange("x",(-.974,socket_y,zfeed),rad*1.39,"Reactor pickup","red_dark")
        lower_coupling=zfeed+.27
        for h in (lower_coupling,z-.30):
            self.flange("z",(left,y,h),rad*1.29,"Riser coupling")
        self.flange("z",(xright,y,top-.011),rad*1.42,"Top entry union","steel")
        if z-top>.45:
            self.flange("z",(xright,y,z-.225),rad*1.22,"Overhead downcomer","steel",False)
        # Different modules expose different lengths of the transfer trunk.
        ranges=([(-.24,.23)] if self.tier==1 else
                ([(-.33,.14)] if self.tier==2 and index==0 else
                 ([(-.60,-.27),(.27,.60)] if index%2==0 else [(-.34,.24)])))
        start=left+.19
        stop=xright-.19
        for a,b in ranges:
            self.sleeve(y,z,start,a-.030,rad)
            self.pulse_window(y,z,a,b,rad)
            start=b+.030
        self.sleeve(y,z,start,stop,rad)
        self.flange("x",(left+.24,y,z),rad*1.30,"Elbow socket","red_dark")
        self.flange("x",(xright-.235,y,z),rad*1.30,"Elbow socket","red_dark")
        for x in (-.74,.76):
            if y>rear:
                seat=1.15+sqrt(1-x*x)-.055
                span=y-rear+.27
                self.block("Cantilever saddle bed",(x,y-span*.5+.035,seat),(.245,span,.081),"red_dark",.022)
                self.route("Raked gallery bracket",[(x,rear-.10,seat-.14),(x,y+.041,seat-.035)],.041,"steel",.012)
            self.saddle(x,y,z,rad)
        # A traced instrument loop leaves one gland and returns to the same riser.
        self.route("Riser pressure sample loop",[
            (left,y-.043,lower_coupling),(left-.088,y-.097,lower_coupling),
            (left-.112,y-.101,lower_coupling+.062),(left-.112,y-.101,z-.365),
            (left-.08,y-.096,z-.30),(left,y-.042,z-.30)],.016,"copper",.025)
        for h in (lower_coupling,z-.30):
            self.cylinder("Sample union",(left-.060,y-.057,h),(left-.119,y-.093,h),.025,"brass",6)

    def bypasses(self, rows):
        group("Left-bank bypass and equalizer lines")
        # Two smaller pipes carry different services up the outside of the bank.
        left=-1.18
        y=rows[0][0]
        low=(1.54,1.72,1.80)[self.tier-1]
        for j,(z,radius,mat) in enumerate(((low,.048,"copper"),(low+.14,.031,"steel"))):
            # Socket reaches the curved shell, then the bypass turns around the front
            # pier and meets its corresponding riser with a T-flange.
            xv=-1.28-.072*j
            yf=-.32-.090*j
            self.route("Jacket water bypass",[
                (-.56,yf,z),(xv,yf,z),(xv,y-.08,z),(xv,y,z+.08),(left,y,z+.08)],radius,mat,.073)
            self.flange("x",(-1.015,yf,z),radius*1.46,"Bypass socket","steel",False)
            self.flange("y",(xv,(yf+y)/2,z),radius*1.35,"Bypass coupling","brass",False)
        if len(rows)>1:
            z=1.96
            self.cylinder("Common riser equalizer",(-1.29,rows[0][0]-.042,z),
                          (-1.29,rows[-1][0]+.044,z),.041,"iron")
            for i,(yc,_,_) in enumerate(rows):
                valve_x=-1.18 if i%2==0 else -1.23
                self.cylinder("Equalizer branch",(valve_x,yc,z),(-1.29,yc,z),.036,"steel")
                self.flange("y",(-1.29,yc,z),.060,"Equalizer gland","steel",False)

    def utility_header(self, ys, x):
        group("Coolant return main")
        if len(ys)>1:
            front=ys[0]-.11; rear=ys[-1]+.14
            self.cylinder("Shared regulator return", (x+.276,front,.267),(x+.276,rear,.267),.055,"copper",24)
            for y in [front,rear]+[(a+b)*.5 for a,b in zip(ys,ys[1:])]:
                self.flange("y",(x+.276,y,.267),.071,"Header coupling","steel",False)
            # At both ends the header turns inboard and reaches the service deck.
            for y in (front,rear):
                self.route("Return to deck collector",[(x+.276,y,.267),(x+.276,y,.193),(x+.145,y,.193)],.043,"steel",.043)
        else:
            self.route("Return to deck collector",[(x+.278,ys[0],.267),(x+.315,ys[0],.267),(x+.315,ys[0],.18)],.047,"steel",.029)


def build(tier, r):
    g=Gallery(tier,r)
    # Taller galleries are stepped toward the back; growing the reactor unlocks
    # new paths and a longer return header while retaining the same fittings.
    x=(1.274,1.287,1.295)[tier-1]
    layouts={
        1:[(.31,2.31,1.69)],
        2:[(.245,2.31,1.69),(.765,2.53,1.83)],
        3:[(.242,2.33,1.67),(.755,2.63,1.87),(1.263,2.81,2.00)]
    }
    rows=layouts[tier]
    for i,(y,z,cap) in enumerate(rows):
        g.regulator(x,y,cap,i)
        g.line(i,y,z,cap,x)
    g.bypasses(rows)
    g.utility_header([p[0] for p in rows],x)
