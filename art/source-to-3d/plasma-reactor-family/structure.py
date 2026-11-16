"""Cast foundations, Gothic bracing, heat rejection banks and axial generators."""
from math import atan2, ceil, cos, pi, sin, sqrt
from forge import box, cyl, tube, mesh, group

TAU = 2*pi


class Fabricator:
    """Lay out the structure in chamber-radius units."""
    def __init__(self, r):
        self.r = r

    def p(self, point):
        return tuple(self.r*v for v in point)

    def box(self, name, center, size, mat, bevel=0):
        return box(name, self.p(center), self.p(size), mat, self.r*bevel)

    def cyl(self, name, start, end, rad, mat, sides=24, bevel=0):
        return cyl(name, self.p(start), self.p(end), self.r*rad, mat, sides, self.r*bevel)

    def tube(self, name, pts, rad, mat, sides=10, bend=0):
        return tube(name, [self.p(p) for p in pts], self.r*rad, mat, sides, self.r*bend)

    def mesh(self, name, points, faces, mat, smooth=False):
        return mesh(name, [self.p(p) for p in points], faces, mat, smooth)

    def rings(self, name, rings, mat, close=True):
        """Bridge equally sized profiles. Each profile faces along the sweep."""
        n = len(rings[0])
        indices = []
        for k in range(len(rings)-1):
            a, b = k*n, (k+1)*n
            for i in range(n):
                j = (i+1)%n
                indices.append((a+i, a+j, b+j, b+i))
        if close:
            indices.append(tuple(reversed(range(n))))
            indices.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
        return self.mesh(name, sum(rings, []), indices, mat)

    def xz(self, name, polygon, y_front, y_back, mat):
        poly = list(polygon)
        if sum(x*poly[(j+1)%len(poly)][1] - z*poly[(j+1)%len(poly)][0] for j,(x,z) in enumerate(poly))<0:
            poly.reverse()
        return self.rings(name,[[(x,y,z) for x,z in poly] for y in (y_back,y_front)],mat)

    def plate(self,name,levels,mat):
        rings=[]
        for xl,xh,yf,yb,ch,z in levels:
            rings.append([(x,y,z) for x,y in [(xl+ch,yf),(xh-ch,yf),(xh,yf+ch),(xh,yb-ch),(xh-ch,yb),(xl+ch,yb),(xl,yb-ch),(xl,yf+ch)]])
        return self.rings(name,rings,mat)

    def fasteners(self,name,points,radius,length,mat='brass',axis='y',sides=6):
        # Batch bolts and washers into one editable manufacturing part per row.
        vertices=[]; faces=[]
        for x,y,z in points:
            rings=[]
            for distance,rad in [(0,radius*.72),(length*.15,radius),(length*.83,radius),(length,radius*.80)]:
                ring=[]
                for i in range(sides):
                    a=TAU*i/sides+pi/6
                    co,si=cos(a)*rad,sin(a)*rad
                    if axis=='y': ring.append((x+co,y-distance,z+si))
                    elif axis=='z': ring.append((x+co,y+si,z+distance))
                    else: ring.append((x+distance,y+co,z+si))
                rings.append(ring)
            start=len(vertices); vertices.extend(sum(rings,[]))
            faces.append(tuple(start+k for k in reversed(range(sides))))
            for row in range(3):
                for i in range(sides):
                    j=(i+1)%sides
                    a=start+row*sides
                    faces.append((a+i,a+j,a+sides+j,a+sides+i))
            faces.append(tuple(start+sides*3+i for i in range(sides)))
        if vertices: self.mesh(name,vertices,faces,mat)


def foundry_base(s,tier,rear):
    group('01 | Cast chassis and anchor shoes')
    xl,xh,yf,yb=-1.43,1.70,-1.0,rear+.40
    def level(offset,z,ch):
        return xl+offset,xh-offset,yf+offset,yb-offset,ch,z
    # Chamfered casting sides shrink to a shadow relief before the deck lip.
    s.plate('Eight-sided foundation casting', [level(.035,0,.15),level(0,.045,.16),level(0,.100,.16),level(.028,.125,.16)], 'iron')
    s.plate('Continuous deck gasket',[level(.018,.122,.16),level(.018,.145,.16)],'black')
    s.plate('Rolled top deck with polished edge',[level(.022,.144,.16),level(0,.157,.16),level(0,.168,.16),level(.017,.18,.153)],'steel')
    for x in (xl+.19,xh-.19):
        for y in (yf+.16,yb-.16):
            s.box('Foundation hold-down lug',(x,y,.195),(.215,.14,.033),'iron',.012)
    s.fasteners('Hold-down studs',[(x,y,.209) for x in (xl+.13,xl+.25,xh-.25,xh-.13) for y in (yf+.16,yb-.16)],.025,.024,'brass',axis='z')
    # Perimeter tongues also break up the long forward and flank castings.
    for a,b in ((-.98,-.58),(-.42,.02),(.17,.54),(.70,1.12)):
        poly=[(a,.040),(b,.040),(b+.02,.061),(b+.02,.093),(a+.022,.093),(a,.075)]
        s.xz('Recessed frontal sill plate',poly,yf-.003,yf+.02,'black')
    for side in (xl,xh):
        for i in range(2+tier):
            y=yf+.32+(yb-yf-.62)*(i+.5)/(2+tier)
            s.box('Deck edge expansion joint',(side,y,.084),(.018,.028,.08),'edge',.003)
    # Cast rails under the generator and containment frame continue into the back.
    for x,width in [(-.82,.15),(.81,.15),(1.28,.20)]:
        s.box('Bolted longitudinal bed rail',(x,(yb+yf)/2,.198),(width,yb-yf-.26,.058),'iron',.012)
    s.fasteners('Bed rail bolt line',[(x,y,.226) for x in (-.82,.81,1.28) for y in (yf+.20,yb-.18)],.018,.014,'steel',axis='z')


def cathedral_pier(s,sign,y,h,strong=False,half=.12):
    """A cast tapered buttress with a proper pierced pointed window between ribs."""
    base_z=.18; span=h-base_z
    def at(u,z):
        f=(z-base_z)/span
        return (sign*(1.13-.34*f+u*(.76-.20*f)),z)
    def poly(shape): return [at(u,z) for u,z in shape]
    # Side legs and head are separate castings around a through opening.
    lo=base_z+.17; spring=base_z+.54*span; peak=base_z+.73*span
    outer=.195 if strong else .168
    inner=.082 if strong else .073
    s.xz('Gothic pier / outer jamb',poly([(-outer,base_z),(-inner+.01,base_z),(-inner,lo),(-inner,spring),(-inner*.56,spring+.48*(peak-spring)),(0,peak),(-outer,peak+.06)]),y-half,y+half,'red')
    s.xz('Gothic pier / inner jamb',poly([(inner-.01,base_z),(outer,base_z),(outer,peak+.06),(0,peak),(inner*.56,spring+.48*(peak-spring)),(inner,spring),(inner,lo)]),y-half,y+half,'red')
    s.xz('Arch keystone casting',poly([(-outer,peak+.055),(0,peak),(outer,peak+.055),(outer*.73,h-.02),(.055,h+.035),(-.09,h+.02),(-outer*.85,h-.07)]),y-half,y+half,'red_dark')
    s.xz('Foot block',poly([(-outer-.055,base_z), (outer+.055,base_z), (outer+.05,lo-.055),(outer+.017,lo+.015),(-outer-.017,lo+.015),(-outer-.05,lo-.055)]),y-half-.034,y+half+.03,'iron')
    s.xz('Architectural plinth molding',poly([(-outer-.045,lo-.065),(outer+.045,lo-.065),(outer+.045,lo-.03),(-outer-.045,lo-.03)]),y-half-.041,y+half+.038,'steel')
    # Bronze arrises follow the actual lancet, including its inclined centerline.
    for q in (-1,1):
        frame=[(q*(inner+.011),lo+.008),(q*(inner+.011),spring),(q*(inner*.60+.010),spring+.48*(peak-spring)),(q*.006,peak+.019)]
        s.tube('Cast lancet reveal',[(x,y-half-.008,z) for x,z in poly(frame)],.012 if strong else .009,'brass',8,.009)
        arris=[(q*(outer-.026),lo+.012),(q*(outer-.026),peak+.05),(q*(outer*.70),h-.065)]
        s.tube('Outer iron arris',[(x,y-half-.004,z) for x,z in poly(arris)],.014,'steel',8,.018)
    s.xz('Keystone face and crown',poly([(-.08,peak+.042),(.08,peak+.042),(.055,h-.035),(-.055,h-.035)]),y-half-.020,y-half,'red')
    pins=poly([(u,z) for u in (-outer+.04,outer-.04) for z in (lo-.085,lo+.09,spring-.03)]+[(0,h-.08)])
    s.fasteners('Architectural rivets',[(x,y-half-.042 if z<lo else y-half-.012,z) for x,z in pins],.019,.016,'brass')
    top_poly=poly([(-outer*.82,h-.075),(outer*.82,h-.075),(outer*.72,h-.015),(.05,h+.04),(-.065,h+.04),(-outer*.72,h-.015)])
    s.xz('Crown cap with chamfered shoulders',top_poly,y-half-.016,y+half+.015,'steel')


def frames(s,tier,rear):
    group('02 | Pierced containment cradle')
    # Middle frames are substantial iron bearers; only end bays receive tracery.
    slots=[-.29,rear-.12] if tier<3 else [-.29,.36,rear-.075]
    for side in (-1,1):
        for i,y in enumerate(slots):
            h=([1.61,1.84,2.04][tier-1] if i==0 else [1.46,1.77,1.98][tier-1])
            cathedral_pier(s,side,y,h,strong=tier>=2,half=.082 if tier==1 else .10)
            if tier==3:
                # The diagonal flying stay joins the outboard footing to the main pier.
                a=side
                s.xz('Flying stay / pointed web',[(a*1.33,.38),(a*1.26,.42),(a*1.11,.85),(a*.97,1.34),(a*.92,1.59),(a*1.00,1.52),(a*1.16,1.04),(a*1.31,.69)],y-.048,y+.048,'red_dark')
                s.tube('Flying stay / gilded web edge',[(a*1.30,y-.054,.53),(a*1.12,y-.054,1.00),(a*.962,y-.054,1.51)],.014,'brass',8,.03)
    # Trussed dark cross-member at base supports the otherwise open center.
    for y in (slots[0],slots[-1]):
        s.box('Transverse bed casting',(0,y,.252),(2.21,.21,.149),'iron',.027)
        s.box('Finishing strip along bed casting',(0,y-.091,.302),(2.08,.031,.035),'steel',.007)
    if tier>=2:
        for side in (-1,1):
            ymid=(slots[0]+slots[-1])/2
            s.box('Spandrel longitudinal tie',(side*.924,ymid,1.30),(.083,slots[-1]-slots[0],.08),'red_dark',.014)
            s.box('Rolled tie flange',(side*.925,ymid,1.343),(.111,slots[-1]-slots[0]+.04,.028),'steel',.004)


def exchanger(s,tier,rear):
    group('03 | Heat exchangers and cagework')
    # The low left-fore rack supplies a secondary louvred silhouette; actual spaces
    # between fins, rails and uprights give the cage depth under a grazing light.
    cx=-1.095; y=-.768; width=.49; dep=.28; z0=.214; height=[.39,.50,.62][tier-1]; z1=z0+height
    s.box('Heat exchanger / sump',(cx,y,z0+.035),(width+.066,dep+.049,.069),'iron',.015)
    s.box('Heat exchanger / condenser matrix',(cx,y+.045,z0+.52*height),(width-.055,dep*.66,height-.104),'black',.022)
    for i in range(tier+5):
        zz=z0+.10+(height-.17)*(i/(tier+4))
        s.box('Spaced folded exchanger fins',(cx,y-.029,zz),(width-.016,dep-.03,.015),'steel',.004)
        s.tube('Folded copper core return',[(cx-width*.33,y+.056,zz+.003),(cx-width*.33,y-.04,zz+.003),(cx+width*.33,y-.04,zz+.003),(cx+width*.33,y+.056,zz+.003)],.009,'copper',8,.017)
    for xx in (cx-width/2,cx+width/2):
        for yy in (y-dep/2,y+dep/2):
            s.box('Right-angle cage upright',(xx,yy,(z0+z1)/2),(.043,.043,height),'red_dark',.006)
    for j in range(1,5+tier):
        xx=cx-width/2+j*width/(5+tier)
        s.box('Frontal protective cage bars',(xx,y-dep/2-.003,(z0+z1)/2),(.023,.026,height-.075),'iron',.005)
    for zz in (z0+.075,z1-.075):
        s.box('Cage spreader',(cx,y-dep/2-.019,zz),(width+.009,.023,.025),'brass',.004)
    s.box('Racked exchanger crown',(cx,y,z1),(width+.052,dep+.052,.069),'red',.010)
    for j in range(6+tier):
        xx=cx-width*.40+j*width*.8/(5+tier)
        s.box('Punched crown aperture',(xx,y,z1+.036),(.020,dep*.72,.008),'black',.003)
    s.fasteners('Heat exchanger face screws',[(x,y-dep/2-.022,z) for x in (cx-width/2,cx+width/2) for z in (z0+.075,z1-.075)],.014,.012,'brass')
    # Long outboard ventilation access. Integrated behind the starboard base lip.
    if tier>=2:
        x=1.608; yf=.16; yb=rear+.22; top=.48 if tier==2 else .59
        s.box('Starboard exhaust trench outer shell',(x-.034,(yf+yb)/2,(top+.19)/2),(.095,yb-yf,top-.19),'black',.023)
        for z in (.21,top):
            s.box('Outboard vent top and sill',(x,(yf+yb)/2,z),(.13,yb-yf+.025,.040),'steel',.007)
        bays=tier
        for i in range(bays+1):
            yy=yf+(yb-yf)*i/bays
            s.box('Armoured vent dividers',(x+.028,yy,(top+.21)/2),(.109,.046,top-.18),'red',.007)
        for i in range(5 if tier==2 else 7):
            z=.245+i*(top-.29)/(4 if tier==2 else 6)
            s.box('Stacked outboard louvres',(x+.027,(yf+yb)/2,z),(.045,yb-yf-.026,.015),'edge',.003)
        s.fasteners('Vent jamb studs',[(x+.085,yf+(yb-yf)*i/bays,z) for i in range(bays+1) for z in (.234,top-.035)],.012,.010,'brass',axis='x')
    # Catwalk along the unoccupied left flank, with real cross-treads and rails.
    if tier>=2:
        group('04 | Inspection walk and rail')
        outer=-1.39; inner=-1.10; yf=.033; yb=rear+.20; zz=.83 if tier==2 else .98
        for x in (outer,inner):
            s.box('Gallery I-beam web',(x,(yf+yb)/2,zz-.035),(.029,yb-yf,.09),'iron',.004)
            s.box('Gallery I-beam flange',(x,(yf+yb)/2,zz+.005),(.056,yb-yf+.020,.019),'edge',.003)
        n=ceil((yb-yf)/.055)
        for i in range(n):
            yy=yf+(i+.5)*(yb-yf)/n
            s.box('Open grating tread',((outer+inner)/2,yy,zz+.012),(inner-outer,.024,.022),'steel',.001)
        posts=3 if tier==2 else 4
        for i in range(posts):
            yy=yf+(yb-yf)*i/(posts-1)
            s.tube('Triangular gallery bracket',[(inner+.03,yy,zz-.35),(outer,yy,zz-.055),(inner+.03,yy,zz-.055)],.027,'iron',8)
            s.cyl('Gallery stanchion',(outer,yy,zz+.013),(outer,yy,zz+.265),.014,'brass',10)
        for z in (zz+.142,zz+.265):
            s.tube('Bent handrail',[(inner,yf,z),(outer,yf,z),(outer,yb,z),(inner,yb,z)],.012 if z<zz+.2 else .017,'brass',10,.035)
        s.box('Walkway toe plate',(outer,(yf+yb)/2,zz+.051),(.023,yb-yf,.055),'red_dark',.003)


def dynamo(s,tier):
    group('05 | Extraction turbine and scroll casing')
    # Local u,v are right/up in the intake plane. t grows toward the viewer.
    radius=[.275,.314,.348][tier-1]; length=[.54,.62,.69][tier-1]
    dx,dy=.470,-.882666200; hx,hy=.882666200,.470
    cx,cy=1.235,-.452; cz=.25+radius
    def p(u,v,t): return (cx+hx*u+dx*t, cy+hy*u+dy*t,cz+v)
    def polar(rad,theta,t): return p(rad*cos(theta),rad*sin(theta),t)
    def profile(name,rt,mat,n=52):
        vertices=[]; faces=[]
        for rad,t in rt:
            vertices.extend(polar(rad,i*TAU/n,t) for i in range(n))
        for h in range(len(rt)):
            nh=(h+1)%len(rt)
            for i in range(n):
                j=(i+1)%n
                faces.append((h*n+i,h*n+j,nh*n+j,nh*n+i))
        s.mesh(name,vertices,faces,mat)
    def barrel(name,a,b,rad,material,sides=40,bevel=.004):
        s.cyl(name,p(0,0,a),p(0,0,b),rad,material,sides,bevel)
    def sector(name,lo,hi,a,b,theta,span,mat,steps=7):
        rows=[]
        for i in range(steps+1):
            angle=theta-span/2+i*span/steps
            rows.append([polar(rad,angle,t) for rad,t in [(lo,a),(lo,b),(hi,b),(hi,a)]])
        s.rings(name,rows,mat)
    rear=-length*.52; fore=length*.48
    # A true U-shaped iron saddle; cast webs rise from the feet and meet the body.
    for t in (rear+.09,fore-.07):
        poly=[(-radius*.98,-radius-.055),(radius*.98,-radius-.055),(radius*.98,-radius*.60),(radius*.85,-radius*.26),(radius*.74,-radius*.22),(radius*.53,-radius*.69),(-radius*.53,-radius*.69),(-radius*.74,-radius*.22),(-radius*.85,-radius*.26),(-radius*.98,-radius*.60)]
        s.rings('Flared saddle and mounting tongue',[[p(u,v,tt) for u,v in poly] for tt in (t-.043,t+.043)],'iron')
        for u in (-radius*.78,radius*.78):
            x,y,z=p(u,-radius-.028,t)
            s.box('Generator anchor foot',(x,y,.228),(.13,.15,.079),'red_dark',.014)
            s.fasteners('Saddle hold-down stud',[(x,y,.267)],.019,.016,'brass',axis='z')
    barrel('Dynamo lamination stack',rear,fore-.025,radius*.876,'black',52,.01)
    # Short ring sectors resemble bolted armor castings, with fine axial heat fins
    # visible through their side gaps.
    start=rear+.08; end=fore-.079
    for i in range(9+tier):
        t=start+i*(end-start)/(8+tier)
        profile('Cylindrical heat rejecting fin',[(radius*.83,t-.006),(radius*.932,t-.006),(radius*.953,t),(radius*.93,t+.007),(radius*.83,t+.007)],'steel',44)
    for i in range(7):
        theta=TAU*i/7
        sector('Armoured alternator pole shoe',radius*.93,radius*.994,start+.007,end-.005,theta,.42,'red_dark')
        sector('Pole shoe centerline',radius*.992,radius*1.006,start+.064,end-.058,theta,.07,'red')
    for t,mat in ((rear+.052,'iron'),(fore-.078,'steel')):
        profile('Machined bell-housing strap',[(radius*.86,t-.038),(radius*.973,t-.038),(radius*1.034,t-.020),(radius*1.034,t+.02),(radius*.973,t+.038),(radius*.86,t+.038)],mat,48)
    barrel('Rear conical bearing cap',rear-.034,rear+.038,radius*.79,'steel',32,.023)
    barrel('Rear bearing cap boss',rear-.075,rear-.022,radius*.42,'brass',30,.012)
    # Rounded adapter and cable entry physically join the barrel-side bearing.
    x,y,z=p(0,0,rear-.072)
    s.tube('Turbine power trunk into port side flange',[(x,y,z),(x-.07,y+.13,z),(x-.21,y+.16,z),(x-.30,y+.16,z+.15)],.092,'iron',16,.07)
    # Actual open metal inlet ring, rolled around its lip. The axial fan is
    # recessed within this throat with its roots connected to the hub.
    profile('Rolled turbine intake cowl',[(radius*.77,fore-.098),(radius*.94,fore-.11),(radius*1.025,fore-.033),(radius*1.035,fore+.014),(radius*.987,fore+.040),(radius*.864,fore+.04),(radius*.816,fore+.016),(radius*.787,fore-.025)],'steel',64)
    profile('Brass throat bevel',[(radius*.792,fore-.010),(radius*.837,fore+.014),(radius*.862,fore+.038),(radius*.858,fore+.044),(radius*.831,fore+.040),(radius*.790,fore+.007)],'brass',64)
    barrel('Dark recessed turbine well',fore-.071,fore-.058,radius*.79,'black',48,.002)
    blade_count=9+tier
    group('06 | Turbine runner, shaft and inlet ring')
    for k in range(blade_count):
        initial=TAU*k/blade_count; rows=[]
        # Twisted blades thicken at the root and narrow around the inlet wall.
        spine=[]
        for rr,shift,chord,sweep in [(.235,-.16,.365,.019),(.39,-.066,.425,.024),(.60,.050,.35,.026),(.77,.178,.242,.022),(.796,.207,.214,.016)]:
            rad=radius*rr; ang=initial+shift
            lead_t=fore+.004+sweep; trail_t=fore-.017
            rows.append([polar(rad,ang-chord/2,lead_t-.011),polar(rad,ang+chord/2,trail_t-.009),polar(rad,ang+chord/2,trail_t),polar(rad,ang-chord/2,lead_t)])
            spine.append(polar(rad,ang-chord/2,lead_t))
        s.rings('Twisted compressor blade',rows,'steel' if k%2 else 'edge')
        s.tube('Blade leading edge',spine,.0045,'edge',6,.004)
    barrel('Impeller shaft',fore-.059,fore+.043,radius*.251,'iron',40,.006)
    barrel('Hub band',fore+.032,fore+.056,radius*.246,'brass',40,.005)
    barrel('Stepped hub / boss',fore+.053,fore+.084,radius*.196,'steel',24,.011)
    barrel('Retaining nut',fore+.081,fore+.096,radius*.105,'brass',8,.004)
    for i in range(12):
        theta=i*TAU/12
        s.cyl('Cowl studs',polar(radius*.927,theta,fore+.038),polar(radius*.927,theta,fore+.053),radius*.043,'iron',6,.001)
    # Three tooth-shaped ochre indexing tabs on the cowl give a visible
    # manufactured datum around the indexed rotor.
    for i in range(3):
        sector('Cowl indexing key',radius*.923,radius*.983,fore+.041,fore+.049,.73+i*.145,.080,'brass',3)



def ventilation_crown(s,tier):
    if tier==1:
        return
    group('07 | Vaulted roof exhaust')
    # The exhaust saddle follows the continuous curved boiler roof. Housed
    # above it, individual lancets really open through the frontal arcade.
    count=3 if tier==2 else 5
    half=.335 if tier==2 else .492
    yf=-.402; yb=-.015
    def sole(x):
        return 1.15+sqrt(1-x*x)*.987-.016
    def crest(x):
        return (2.34 if tier==2 else 2.425)-abs(x)*(.36 if tier==2 else .52)
    grid=[-half+i*(2*half)/count for i in range(count+1)]
    def strip(name,low,high,front,back,mat):
        # Individual trapezoids avoid a coplanar n-gon across a curved sill.
        roof_grid=sorted(set(grid+[0.0]))
        for a,b in zip(roof_grid,roof_grid[1:]):
            s.xz(name,[(a,low(a)),(b,low(b)),(b,high(b)),(a,high(a))],front,back,mat)
    strip('Exhaust saddle foot',lambda x:sole(x)-.039,lambda x:sole(x)+.031,yf-.012,yb+.018,'iron')
    strip('Arcade recessed inlet',lambda x:sole(x)+.025,lambda x:crest(x)-.020,yf+.060,yb,'black')
    strip('Coped arcade roof sheet',lambda x:crest(x)-.024,lambda x:crest(x)+.008,yf-.018,yb+.018,'red')
    strip('Metallic drip molding',lambda x:crest(x)-.001,lambda x:crest(x)+.012,yf-.026,yf-.012,'steel')
    for i in range(count):
        a,b=grid[i],grid[i+1]; x=(a+b)/2; floor=sole(x)+.042
        width=(b-a)*.40; apex=crest(x)-.033
        spring=apex-(b-a)*.54
        profile=[(x-width,floor),(x-width,spring),(x-width*.56,spring+(apex-spring)*.56),(x,apex),(x+width*.56,spring+(apex-spring)*.56),(x+width,spring),(x+width,floor)]
        # Infill stops at the pitched reveal. The blades are set back inside it.
        for row in range(4):
            z=floor+(spring+.029-floor)*(row+.25)/4
            limit=width*(1-.54*max(0,(z-spring)/(apex-spring)))
            s.box('Roof exhaust angled louvre',(x,yf+.042,z),(2*limit,.036,.013),'steel',.003)
        s.tube('Continuous pointed arch reveal',[(xx,yf-.011,zz) for xx,zz in profile],.012,'brass',8,.007)
        for sign in (-1,1):
            edge=a if sign==-1 else b
            s.xz('Lateral hood and spandrel',[(edge,sole(edge)+.023),(x+sign*width,floor),(x+sign*width,spring),(x+sign*width*.56,spring+(apex-spring)*.56),(x,apex),(x,crest(x)-.010),(edge,crest(edge)-.010)],yf,yf+.061,'red_dark')
        s.cyl('Arcade keystone medallion',(x,yf-.012,apex+.014),(x,yf-.026,apex+.014),.014,'brass',8,.002)
    for x in (-half,half):
        s.box('Roof exhaust side plate',(x,(yb+yf)/2,(sole(x)+crest(x))/2),(.030,yb-yf,crest(x)-sole(x)),'iron',.005)
    s.tube('Axial ridge trim',[(0,yf-.024,crest(0)+.01),(0,yb+.025,crest(0)+.01)],.025,'brass',8)


def riser_cage(s,tier):
    if tier!=3:
        return
    from mathutils import Vector
    group('08 | Processional riser guard cage')
    def member(name,a,b,normal,depth,width,mat):
        a,b=Vector(a),Vector(b); path=(b-a).normalized()
        n=Vector(normal); n=(n-path*n.dot(path)).normalized(); lateral=path.cross(n)
        d,w=depth/2,width/2; c=min(d,w)*.38
        outline=[(-d+c,-w),(d-c,-w),(d,-w+c),(d,w-c),(d-c,w),(-d+c,w),(-d,w-c),(-d,-w+c)]
        s.rings(name,[[tuple(end+n*u+lateral*v) for u,v in outline] for end in (a,b)],mat)
    # Wrap the after pair of risers; the open inner side gives their unions
    # access to the headers. Clipped return corners are well clear of couplings.
    path=[(-.975,.488),(-1.392,.488),(-1.543,.598),(-1.543,.994),(-1.543,1.399),(-1.427,1.499),(-.975,1.499)]
    low=1.18
    def upper(y): return 2.17+.31*(y-.49)
    for k,((x1,y1),(x2,y2)) in enumerate(zip(path,path[1:])):
        dx,dy=x2-x1,y2-y1
        side=Vector((-dy,dx,0)).normalized()
        def at(t,z,off=0): return (x1+t*dx+side.x*off,y1+t*dy+side.y*off,z)
        h1,h2=upper(y1),upper(y2); hm=(h1+h2)/2
        for a,b,ww,mm in [(low,low,.075,'iron'),(low+.043,low+.043,.024,'steel'),(h1,h2,.092,'red_dark'),(h1+.043,h2+.043,.028,'steel')]:
            member('Clipped guard perimeter frame',at(0,a),at(1,b),side,.075,ww,mm)
        if k in (0,2,3,5):
            # Each full bay is an open, shouldered lancet. A central tip locks
            # into the upper lintel; water and wiring remain visible behind it.
            for a,dr in [(0,1),(1,-1)]:
                zs=(h1 if a==0 else h2)-.36
                bent=[at(a+.115*dr,low+.047),at(a+.115*dr,zs),at(a+.225*dr,zs+.15),at(.50,hm-.043)]
                for a1,b1 in zip(bent,bent[1:]):
                    member('Deep lance-shaped guard casting',a1,b1,side,.052,.037,'steel')
            member('Lancet central boss',at(.5,hm-.06),at(.5,hm+.018),side,.092,.067,'brass')
            # A second low spreader keeps the grille from buckling under impact.
            member('Lower cage spreader',at(0,low+.26),at(1,low+.26),side,.039,.027,'iron')
    # Heavy jambs pierce the lower frame and are carried by an inboard knee or
    # masonry deck stud at each landing. Nothing is balanced on a handrail.
    for i,(x,y) in enumerate(path):
        hh=upper(y)
        if i in (2,3,4):
            base=(-1.345,y,.194)
            member('Outrigger knee from deck',(base[0],y,.22),(x,y,low+.015),(0,1,0),.081,.083,'red_dark')
            s.box('Riser guard heel casting',base,(.162,.135,.051),'iron',.009)
            s.fasteners('Cage heel bolts z',[(base[0]-.048,y,.220),(base[0]+.048,y,.220)],.017,.014,'brass',axis='z')
        elif i in (0,6):
            member('Inboard load post',(x,y,.228),(x,y,low+.015),(1,0,0),.064,.068,'iron')
            s.box('Inboard cage foot',(x,y,.205),(.126,.108,.055),'steel',.008)
        side=(1,0,0) if i in (2,3,4) else (0,1,0)
        member('Full height cage jamb',(x,y,low-.014),(x,y,hh+.046),side,.064,.076,'iron')
        for z in (low+.028,hh-.050):
            s.box('Guard frame keeper',(x,y,z),(.092,.099,.057),'red',.008)

def build(tier,r):
    s=Fabricator(r)
    rear=(.47,.78,1.10)[tier-1]
    foundry_base(s,tier,rear)
    frames(s,tier,rear)
    exchanger(s,tier,rear)
    dynamo(s,tier)
    ventilation_crown(s,tier)
    riser_cage(s,tier)
