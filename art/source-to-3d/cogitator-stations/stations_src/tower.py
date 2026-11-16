"""Open-angle electrical gantries, cast crossheads and crown switchgear."""
import math
from mathutils import Vector
from common import box, rod, path, mesh, torus, part_snapshot, preserve_round_parts
from pipette.library_geometry import tube as pipette_tube


def _section(name, a, b, width, depth, material, face=(0, -1, 0), channel=True):
    """Rolled steel section, with an actual open channel between its flanges."""
    start, end = Vector(a), Vector(b)
    direction = (end - start).normalized()
    front = Vector(face)
    front = (front - front.dot(direction) * direction).normalized()
    across = front.cross(direction).normalized()
    half = width / 2
    lip = min(width * .145, depth * .23)
    if channel:
        profile = [(-half, -depth/2), (half, -depth/2),
                   (half, depth/2), (half-lip, depth/2),
                   (half-lip, -depth/2+lip), (-half+lip, -depth/2+lip),
                   (-half+lip, depth/2), (-half, depth/2)]
    else:
        profile = [(-half, -depth/2), (half, -depth/2),
                   (half, -depth/2+lip), (-half+lip, -depth/2+lip),
                   (-half+lip, depth/2), (-half, depth/2)]
    n = len(profile)
    coords = [tuple(pos + x*across + y*front) for pos in (start,end)
              for x,y in profile]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh(name, coords, faces, material, min(.004, lip*.25))


def _spun(name, base, axis, profile, material, segments=24):
    """A turned fitting. Every ridge follows the local terminal axis."""
    start = Vector(base)
    up = Vector(axis).normalized()
    right = up.cross(Vector((0,1,0)))
    if right.length < .01:
        right = up.cross(Vector((1,0,0)))
    right.normalize()
    back = up.cross(right).normalized()
    verts=[]
    for z, r in profile:
        for i in range(segments):
            theta = 2*math.pi*i/segments
            verts.append(tuple(start + z*up + r*(math.cos(theta)*right + math.sin(theta)*back)))
    faces = [tuple(range(segments-1,-1,-1))]
    for k in range(len(profile)-1):
        for i in range(segments):
            j=(i+1)%segments
            a=k*segments
            faces.append((a+i,a+j,a+segments+j,a+segments+i))
    faces.append(tuple(range(len(verts)-segments,len(verts))))
    obj = mesh(name, verts, faces, material)
    if obj is not None and getattr(obj, 'type', None) == 'MESH':
        for f in obj.data.polygons[1:-1]:
            f.use_smooth=True


def _bolt(name, x, y, z, radius, material):
    rod(name,(x,y,z),(x,y-.014,z),radius,material,6)


def _gusset(name,x,y,z,width,height,material, cap="steel"):
    wx,hz=width/2,height/2
    chamfer=min(wx*.40,hz*.50)
    pts=[(-wx+chamfer,-hz),(wx-chamfer,-hz),(wx,-hz+chamfer),
         (wx,hz-chamfer),(wx-chamfer,hz),(-wx+chamfer,hz),
         (-wx,hz-chamfer),(-wx,-hz+chamfer)]
    v=[(x+u,y+vdepth,z+w) for vdepth in (.012,-.015) for u,w in pts]
    faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]
    faces += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh(name+" | chamfered strap", v,faces,material,.004)
    for dx in (-.25*width,.25*width):
        _bolt(name+" | fastener",x+dx,y-.015,z,.013,cap)


def _bushing(name, base, axis, scale, metal, ribcount=4):
    # The porcelain skirt is continuous, including the narrow necks under each umbrella.
    p=Vector(base)
    axis=Vector(axis).normalized()
    def shape(label, profile, material, sides=24):
        _spun(name+" | "+label,p,axis,[(z*scale,r*scale) for z,r in profile],material,sides)
    shape("socket flange",[(0,.090),(.013,.105),(.029,.105),(.037,.092),
                            (.045,.086),(.109,.084),(.118,.093),(.135,.093),
                            (.142,.078),(.181,.076)],metal)
    shape("gland hex",[(.081,.086),(.087,.094),(.126,.094),(.132,.081)],
          "brass" if metal!="steel" else "steel",8)
    # These compact stacked ceramic barrels have large cylindrical flanks and a
    # flat, shouldered cap. Soot collects in the cut separating adjacent rings.
    z=.164
    count=3 if ribcount>=4 else 2
    pitch=.058
    shape("recessed waist rings",[(z-.004,.072),(z+count*pitch+.001,.074)],"bronze" if metal!="steel" else "gunmetal")
    for k in range(count):
        rr=.092 if k<count-1 else .087
        shape("ceramic barrel "+str(k+1),[(z,.073),(z+.004,.082),
              (z+.010,rr-.001),(z+.019,rr),(z+.039,rr),
              (z+.046,rr-.004),(z+.050,rr-.011),(z+.051,.072)],"ceramic",32)
        z+=pitch
    shape("ceramic head shoulder",[(z-.006,.070),(z+.001,.071),(z+.011,.066),
                                   (z+.018,.059),(z+.020,.047)],"ceramic",32)
    shape("binding-post cap",[(z+.017,.048),(z+.024,.052),(z+.032,.050),
                               (z+.041,.041),(z+.043,.037)],"brass" if metal!="steel" else "steel",20)
    return tuple(p+(z+.043)*scale*axis)


def _regular(kind):
    # Height, half width at the crown, width of the lower tower, foot & waist bands.
    data = {
        "junior":       (2.98,.515,.303,1.64,2.18,2.63,.97),
        "intermediate": (3.02,.432,.245,1.66,2.06,2.60,.87),
        "senior":       (3.05,.493,.267,1.62,2.01,2.63,.98),
        "planetary":    (3.075,.505,.267,1.62,2.01,2.65,1.01)}
    crown,spread,waist,deck,low,high,pscale=data[kind]
    rich=kind in ("intermediate","planetary")
    weathered="bronze" if kind == "intermediate" else "iron"
    edges="brass" if rich else "bronze"
    rail=.078 if kind=="junior" else .071
    front,back=-.119,.283
    def side(kind_y):return front if kind_y==-1 else back
    # Upper stations flare at the base, narrow down for the zigzag waist, then
    # expand again where the three electrical bushings cantilever outboard.
    foot = waist+(.123 if kind!="junior" else .087)
    levels=[(deck,foot),(low,waist+.030),(high,waist),(crown-.045,waist-.003)]
    for s in (-1,1):
        for k in (-1,1):
            y=side(k)
            box("tower shoe | bearing plate",(s*foot,y,deck),(.16,.17,.043),"iron",.01)
            for i in range(3):
                za,wa=levels[i]
                zb,wb=levels[i+1]
                _section("tower | main rolled upright",(s*wa,y,za),(s*wb,y,zb),
                         rail,rail*.8,weathered,(0,k,0))
            rod("tower shoe | foundation stud",(s*(foot+.053),y,deck+.018),
                (s*(foot+.053),y,deck+.051),.022,"steel",6)
        # Closed side frames resolve the load into both front and rear pillars.
        for node,(z,w) in enumerate(levels):
            _section("tower | side transom",(s*w,front,z),(s*w,back,z),
                     .058,.036,weathered,(s,0,0))
            if node<len(levels)-1:
                nz,nw=levels[node+1]
                y1,y2=(front,back) if (node+(s==1))%2 else (back,front)
                _section("tower | side angle stay",(s*w,y1,z),(s*nw,y2,nz),
                         .039,.027,"iron",(s,0,0),False)
    for row,(z,w) in enumerate(levels):
        for k in (-1,1):
            y=side(k)
            _section("tower | riveted sill",(-w,y,z),(w,y,z),.062,.041,
                     weathered,(0,k,0))
            for s in (-1,1):
                if k==-1:
                    _gusset("tower | front node",s*w,y-.030,z,.108,.087,edges)
        if row<len(levels)-1:
            nz,nw=levels[row+1]
            for k in (-1,1):
                y=side(k)
                # Junior has a succession of broad, simply braced windows. The
                # opposite stays are placed on the same diagonal at the rear.
                # Rear-face bars on the thin stations take the opposing shear.
                front_signs={"junior":(-1,1,-1), "intermediate":(-1,-1,1),
                             "senior":(-1,1,1), "planetary":(-1,1,1)}
                sign=front_signs[kind][row]
                if k==1 and kind!="junior":
                    sign=-sign if row!=2 or kind=="intermediate" else sign
                material=("iron" if kind=="junior" else "bronze") if k==-1 else "dark"
                width=(.049 if kind=="intermediate" else .060) if k==-1 else .031
                if kind in ("senior","planetary") and row==1:
                    zm=z+(nz-z)*.56; wm=w+(nw-w)*.56
                    # Long fore/aft zigzags span a smaller open cell with no mid-height sill.
                    df=(-1 if k==-1 else 1)
                    _section("tower | upper chevron",(df*wm,y,zm),(-df*nw,y,nz),
                             width,.034,material,(0,k,0),False)
                    _section("tower | lower chevron",(-df*w,y,z),(df*wm,y,zm),
                             width,.034,material,(0,k,0),False)
                else:
                    _section("tower | diagonal angle",(sign*w,y,z),(-sign*nw,y,nz),
                             width,.032 if k==-1 else .022,material,(0,k,0),False)
    if kind=="junior":
        for z,w in ((low,waist+.030),(high,waist)):
            box("junior mast | heavy cross collar",(0,front-.029,z),(2*w+.043,.049,.073),"iron",.008)
            for s in (-1,1):
                _gusset("junior mast | square keeper",s*w,front-.052,z,.104,.090,"bronze")
    if kind=="planetary":
        for s in (-1,1):
            rod("magos mast | brass edge of the standard",(s*(waist+.018),front-.038,low),
                (s*(waist+.009),front-.038,high),.011,"brass",10)
    if kind=="junior":
        # Recessed gland hatch, directly on the existing bronze deck. Its
        # cable chases are below the cross-bracing, between the four foot plates.
        box("junior mast | deck access flange",(0,-.074,1.687),(.541,.492,.033),"gunmetal",.016)
        box("junior mast | oil-darkened hatch",(0,-.072,1.711),(.501,.452,.028),"dark",.010)
        for xx in (-.208,.208):
            for yy in (-.244,.092):
                rod("junior mast | hatch screw",(xx,yy,1.725),(xx,yy,1.737),.016,"steel",6)
        for x in (-.124,-.060,.004,.068):
            box("junior mast | cast drainage rib",(x,-.035,1.729),(.015,.239,.014),"iron",.003)
    # The raised crown is a partially open, rounded triangular bus structure.
    cy=-.015
    c=(0,front+.086,crown-.004)
    rear_c=(0,back+.010,crown-.010)
    for s in (-1,1):
        a=(s*spread,cy,crown)
        _section("crosshead | cast outrigger",(s*waist,front,high),a,
                 .085,.061,weathered,(0,-1,0))
        _section("crosshead | rear outrigger",(s*waist,back,high),a,
                 .056,.041,edges,(0,1,0))
        _section("crosshead | sweep",a,rear_c,.087,.061,weathered,(0,-1,0))
        _section("crosshead | arched beam",a,c,.087,.084,weathered,(0,-1,0))
        # Pin bosses make each cantilever read as a casting in front elevation.
        _bolt("crosshead | lower kingpin",s*spread,cy-.092,crown+.050,.028,"brass")
        # A longitudinal saddle underneath every bushing takes its lateral thrust.
        rod("crosshead | terminal tang",(s*spread,cy,crown-.059),a,.075,weathered,8,.100)
        # Each quarter of the front crosshead rises from its outer saddle.
        path("crosshead | rolled forward lip",[
            (s*spread,cy-.005,crown+.029),(s*(spread*.62),front-.043,crown+.070),
            (s*(spread*.31),front-.051,crown+.092),(0,front-.045,crown+.089)],.024,edges)
        path("crosshead | underside bus link",[
            (s*spread,cy+.018,crown-.021),(s*(spread*.57),front+.033,crown+.024),
            (0,front+.040,crown+.052)],.026,weathered)
        _bushing("outboard feedthrough",a,(s*.18,-.012,1),pscale,edges)
    _section("crosshead | central saddle",(0,front,crown+.040),c,
             .10,.060,weathered,(1,0,0))
    _section("crosshead | ridge spine",c,rear_c,.080,.071,weathered,(1,0,0))
    _bushing("central transformer tap",c,(0,.012,1),pscale*.99,edges)
    _loom(kind,spread,waist,deck,high,crown,front,back)



def _wire(name,points,radius,material):
    # Round the bends before passing the whole landing-to-landing route to
    # Pipette; each conductor stays one editable native mesh.
    smooth=[Vector(p) for p in points]
    for step in range(2):
        result=[smooth[0]]
        for a,b in zip(smooth,smooth[1:]):
            result.extend((a.lerp(b,.25),a.lerp(b,.75)))
        smooth=result+[smooth[-1]]
    architecture="wire_single_insulated_solid"
    payload=pipette_tube([tuple(v) for v in smooth], 2*radius, 0, "single_wire",
                         name, architecture, sides=12)
    obj=mesh(name,payload["vertices"],payload["faces"],material)
    if obj is not None and getattr(obj,"type",None)=="MESH":
        obj["pipette_architecture_id"]=architecture
        obj["pipette_outer_diameter_bu"]=2*radius
        for poly in obj.data.polygons:
            poly.use_smooth=True


def _loom(kind,spread,waist,deck,high,crown,front,back):
    # There are two independent harnesses. Jumper leads hang from the crown.
    # The guarded field trunk attaches to the front corner of the cabinet.
    ox="green" if kind not in ("void",) else "rubber"
    for s,material in ((-1,ox),(1,"red")):
        _wire("bus | insulated jumper",[
           (s*.034,back-.018,crown+.135),(s*.09,back-.102,crown+.028),
           (s*.16,.015,crown-.021),(s*.22,-.015,crown+.004),
           (s*(spread-.042),-.015,crown+.079)],.018,material)
    # The three bus conductors tuck behind a single stile. The open upper bay
    # exposes the bracing; the loom emerges through a bolted comb at the sill.
    box("mast | terminal rail",(0,back-.037,crown-.041),
        (.52,.13,.089),"gunmetal",.012)
    junior=kind=="junior"
    mast_x=-waist+.035 if junior else waist-.062
    end_x={"junior":.555,"intermediate":.564,"senior":.575,"planetary":.566}[kind]
    end_z={"junior":.46,"intermediate":.51,"senior":.55,"planetary":.585}[kind]
    loom_y=front+.123
    # Facing the operator, the counter-feed emerges on the left of the shell
    # from an independent shoulder socket. The long trunk serves the right.
    for idx,(jacket,radius) in enumerate((("red",.024),("green",.021),("amber",.017))):
        offset=(idx-1)*.049
        landing_x=end_x+offset
        post=mast_x+offset
        if junior:
            mids=[(post,loom_y,crown-.101),(post,loom_y,crown-.30),
                  (post+.011,loom_y,high-.035),(post+.031,loom_y-.012,high-.18),
                  (post+.041,loom_y-.020,deck+.53),(-.085+offset,front+.029,deck+.38),
                  (.086+offset,front+.015,deck+.235),(.185+offset,front-.020,deck+.130)]
        else:
            mids=[(post,loom_y,crown-.101),(post,loom_y,crown-.32),
                  (post-.010,loom_y,high-.04),(post-.012,loom_y,high-.29),
                  (post-.016,loom_y-.008,deck+.46),(post-.008,front+.053,deck+.31),
                  (post+.035,front+.022,deck+.23),(.231+offset,front-.028,deck+.12)]
        rod("mast | junction stud",(post,loom_y,crown-.047),
            (post,loom_y,crown-.113),radius*1.36,"brass",10)
        # Gland strip is physically continuous between the front rail and studs.
        if idx==1:
            box("mast | bus terminal bridge",(mast_x,(loom_y+back)/2,crown-.076),
                (.163,back-loom_y+.052,.057),"gunmetal",.008)
        mids += [(.191+offset,-.248,deck+.088),(.173+offset,-.385,deck+.049),
                 (.194+offset,-.545,deck+.015),(.222+offset,-.703,1.554),
                 (.246+offset,-.755,1.456),(.253+offset,-.773,1.341),
                 (.271+offset,-.786,1.266),(.294+offset,-.789,1.192),
                 (.329+offset,-.788,1.097),(.373+offset,-.790,.999),
                 (.442+offset,-.795,.934),(.523+offset,-.788,.874),
                 (.554+offset,-.766,.794),(landing_x,-.755,.704),
                 (landing_x,-.755,end_z+.060),(landing_x,-.755,end_z+.011)]
        _wire("field trunk | "+jacket,mids,radius,jacket)
        rod("field trunk | strain relief",(landing_x,-.755,end_z+.009),
            (landing_x,-.755,end_z+.060),radius*1.37,"gunmetal",12)
        rod("field trunk | compression nut",(landing_x,-.755,end_z-.007),
            (landing_x,-.755,end_z+.025),radius*1.59,"bronze",8)

    # Split saddles bolt both ends of a bent strap to a backing tab. Each tab
    # reaches behind the front lip of the underlying casting.
    for name,x,y,z in [("upper",.253,-.773,1.341),("lower",.551,-.766,.794)]:
        box("field trunk | "+name+" saddle foot",(x,y+.062,z),(.216,.116,.041),"gunmetal",.006)
        path("field trunk | "+name+" rolled saddle",[
            (x-.099,y+.022,z),(x-.095,y-.002,z),(x-.074,y-.029,z),
            (x+.066,y-.029,z),(x+.094,y-.002,z),(x+.102,y+.022,z)],.009,"brass")
        for dx in (-.099,.100):
            rod("field trunk | clamp screw",(x+dx,y+.009,z),(x+dx,y-.003,z),.014,"steel",6)
    box("field trunk | cast gland block",(end_x,-.704,end_z-.012),
        (.239,.159,.061),"gunmetal",.009)
    for dx in (-.098,.098):
        rod("field trunk | block mounting stud",(end_x+dx,-.738,end_z+.016),
            (end_x+dx,-.738,end_z+.034),.013,"steel",6)

    return_end=(-.572,-.737,end_z+.088)
    # The short service return drops around the left shoulder through a
    # separate hood rather than crossing the open gantry with the supply.
    lead=[(-.354,-.231,1.602),(-.385,-.302,1.590),(-.417,-.408,1.550),
          (-.434,-.495,1.486),(-.459,-.569,1.381),(-.469,-.657,1.276),
          (-.469,-.714,1.208),(-.501,-.749,1.118),(-.539,-.759,1.038),
          (-.560,-.749,.937),(-.572,-.737,.825),return_end]
    _wire("left shoulder | signal return",lead,.017,"red")
    box("left shoulder | junction hood",(-.335,-.218,1.57),(.134,.139,.123),"dark",.013)
    for name,a,b in (("sending",lead[0],lead[1]),("receiving",lead[-1],lead[-2])):
        pt=Vector(a)
        direction=(Vector(b)-pt).normalized()
        rod("left shoulder | "+name+" gland",pt-direction*.012,pt+direction*.025,.028,"bronze",8)
    box("left shoulder | return socket",(-.572,-.689,end_z+.073),
        (.081,.142,.044),"gunmetal",.006)


def _void():
    from fascia import skull
    deck=1.62; low=2.002; high=2.532; crown=2.955
    front,back=-.137,.294
    levels=[(deck,.445),(low,.316),(high,.270),(crown,.265)]
    for s in (-1,1):
        for y in (front,back):
            box("void mast | forged shoe",(s*.445,y,deck),(.190,.175,.059),"gunmetal",.015)
            for k in range(3):
                z,w=levels[k]; nz,nw=levels[k+1]
                a=Vector((s*w,y,z)); b=Vector((s*nw,y,nz)); u=(b-a).normalized()
                rod("void mast | column",a,b,.052,"steel",16,.048)
                for pos,r in ((a+.025*u,.067),(b-.034*u,.062)):
                    rod("void mast | swage",pos,pos+.033*u,r,"gunmetal",16)
                rod("void mast | raised seam",a+Vector((s*.037,-.027,0)),
                    b+Vector((s*.037,-.027,0)),.013,"steel",10)
            for row in range(3):
                z,w=levels[row]; nz,nw=levels[row+1]
                y1,y2=(front,back) if row%2 else (back,front)
                if y==front:
                    _section("void mast | side knee",(s*w,y1,z),(s*nw,y2,nz),
                             .056,.038,"gunmetal",(s,0,0),False)
        for row,(z,w) in enumerate(levels):
            rod("void mast | transverse stay",(s*w,front,z),(s*w,back,z),.032,"steel",12)
        # The reference has a rear pair of raised ceramic prongs and a much wider
        # opposing pair of transverse high-current feedthroughs, all in one header.
        header=Vector((s*.303,.085,crown-.012))
        for y in (front,back):
            rod("void header | side saddle",(s*.265,y,crown-.042),header,.076,"gunmetal")
        _bushing("void header | upper bushing",header+Vector((0,.070,0)),(s*.27,.15,1),1.055,"steel",4)
        # Inboard front terminals are shorter metal blind caps, prominent in
        # plan relative to the two taller back bushings.
        post=(s*.292,front-.014,crown-.124)
        axis=(s*.10,-.13,1)
        _spun("void header | forward blind turret",post,axis,[
            (0,.095),(.018,.106),(.038,.106),(.055,.078),(.171,.082),
            (.183,.096),(.208,.096),(.225,.083),(.246,.070),
            (.252,.060),(.26,.058)],"steel")
        ap=Vector(post)+Vector(axis).normalized()*.26
        _spun("void header | turret cap",ap,axis,[(0,.045),(.011,.048),(.018,.035)],"gunmetal")
        angle=Vector((s*1.0,-.025,-.195)).normalized()
        sleeve=[(0,.100),(.034,.106),(.048,.119),(.071,.119),(.079,.106),
                (.102,.101),(.125,.104),(.136,.090),(.256,.084),(.275,.09),
                (.290,.096),(.310,.096),(.319,.086)]
        # Parallel cast passages splay out to a common reinforced distal socket.
        for off in (-1,1):
            center=header+Vector((0,off*.052,-.024))
            _spun("void header | twin cast barrel",center,angle,
                  [(z,r*.69) for z,r in sleeve],"steel",24)
        for a in (0,1,2,3):
            theta=a*math.pi/2
            perp=Vector((0,1,0))*math.cos(theta)*.083 + angle.cross(Vector((0,1,0)))*math.sin(theta)*.083
            rod("void header | barrel spline",header+angle*.077+perp,
                header+angle*.287+perp*.91,.012,"steel",8)
        barrel=header+angle*.31
        _spun("void header | turned gland",barrel,angle,[
             (0,.084),(.016,.102),(.04,.102),(.053,.077),
             (.088,.075),(.101,.092),(.116,.092),(.13,.069)],"steel")
        outer=barrel+angle*.12
        _bushing("void header | outboard ceramic nose",outer,(s*.97,-.015,.26),.72,"gunmetal",3)
        # Braided return from the lateral socket; both ends have capture collars.
        _wire("void header | underslung return",[
            tuple(barrel+Vector((0,.048,-.056))),(s*.534,.148,crown-.197),
            (s*.409,.153,crown-.190),(s*.274,.13,crown-.144)],.023,"rubber")
    for row,(z,w) in enumerate(levels):
        for k,y in ((-1,front),(1,back)):
            rod("void mast | cross sill",(-w,y,z),(w,y,z),.036,"gunmetal",16)
            if row<3:
                nz,nw=levels[row+1]
                for sign in ((-1,1) if k==-1 else (1,)):
                    _section("void mast | crossing angle",(sign*w,y,z),(-sign*nw,y,nz),
                             .054 if k==-1 else .037,.034,"steel" if k==-1 else "gunmetal",
                             (0,k,0),False)
    # The central skull has its own wheel and finial, with a clear line of
    # sight across the column; both side sockets are tied to the central casting.
    z=crown-.012
    for s in (-1,1):
        rod("void crown | head yoke",(0,front+.018,z),(s*.29,.050,z+.007),.075,"steel")
    start=part_snapshot()
    rod("void crown | seal back",(0,front+.040,z),(0,front-.058,z),.178,"gunmetal",40)
    torus("void crown | seal moulding",(0,front-.068,z),.163,.015,(0,-1,0),"brass")
    for i in range(12):
        t=2*math.pi*i/12
        _bolt("void crown | embossed stud",.141*math.sin(t),front-.065,z+.141*math.cos(t),.012,"steel")
    for i in range(16):
        t=2*math.pi*i/16
        dx,dz=math.sin(t),math.cos(t)
        if i%4==0:
            length=.068
        else:
            length=.024 if i%2 else .036
        rod("void crown | seal ray",(.158*dx,front-.05,z+.158*dz),
            ((.162+length)*dx,front-.05,z+(.162+length)*dz),.022,"brass",4,.002)
    skull("void crown | death's head",(0,front-.107,z),.205,"brass",False)
    preserve_round_parts(start,z)
    rod("void crown | apex pin",(0,front+.027,z+.147),(0,front+.027,z+.259),.034,"brass",10,.004)
    for s in (-1,1):
        _wire("void mast | bonded harness",[(s*.27,.156,crown-.13),(s*.245,.136,high+.02),
                                            (s*.245,.153,high-.17),(s*.292,.098,low+.049),
                                            (s*.353,.031,deck+.17),(s*.428,-.149,deck+.025)],
             .019,"rubber")


def build_tower(kind):
    if kind=="void":
        _void()
    else:
        _regular(kind)
