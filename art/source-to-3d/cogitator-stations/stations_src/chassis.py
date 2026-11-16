"""Cast footwork, reduction housings and working fluid circuits of the cogitators.

Object coordinates are shared with the station fittings. Front faces negative Y.
Each fabrication assembly is an editable mesh with disconnected castings and fixings.
"""
import math

import bpy
from mathutils import Vector


class _Assembly:
    """Accumulate indexed mechanical solids without creating an object for each bolt."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.mats = []
        self.smooth = []

    def loft(self, rings, material, smooth=False, cap=True):
        start = len(self.verts)
        count = len(rings[0])
        for ring in rings:
            self.verts.extend(tuple(v) for v in ring)
        if cap:
            self.face([start+i for i in reversed(range(count))],material)
        for j in range(len(rings)-1):
            for i in range(count):
                a = start+j*count+i
                b = start+j*count+(i+1)%count
                self.face([a,b,b+count,a+count], material, smooth)
        if cap:
            end = start+(len(rings)-1)*count
            self.face([end+i for i in range(count)],material)

    def face(self, indices, material, smooth=False):
        self.faces.append(indices)
        self.mats.append(material)
        self.smooth.append(smooth)

    def horizontal(self, levels, material):
        # radius_x and radius_y are half extents, corner is the shaved 45-degree corner.
        rings=[]
        for x,y,z,rx,ry,corner in levels:
            c = min(corner,rx*.95,ry*.95)
            rings.append([(x+dx,y+dy,z) for dx,dy in
                          [(-rx+c,-ry),(rx-c,-ry),(rx,-ry+c),(rx,ry-c),
                           (rx-c,ry),(-rx+c,ry),(-rx,ry-c),(-rx,-ry+c)]])
        self.loft(rings,material)

    def slab(self,x,y,z,rx,ry,height,corner,material):
        edge=min(.012,height*.20,rx*.12,ry*.12)
        self.horizontal([(x,y,z,rx-edge,ry-edge,corner),
                         (x,y,z+edge,rx,ry,corner),(x,y,z+height-edge,rx,ry,corner),
                         (x,y,z+height,rx-edge,ry-edge,corner)],material)

    def axial(self, origin, direction, stations, material, n=20, smooth=True):
        p=Vector(origin)
        axis=Vector(direction).normalized()
        up=Vector((0,0,1)) if abs(axis.z)<.92 else Vector((0,1,0))
        u=up.cross(axis).normalized()
        v=axis.cross(u)
        rings=[]
        for distance, radius in stations:
            c=p+axis*distance
            rings.append([c+radius*(u*math.cos(2*math.pi*i/n)+v*math.sin(2*math.pi*i/n)) for i in range(n)])
        self.loft(rings,material,smooth)

    def rod(self,a,b,r,material,n=16,rb=None):
        d=Vector(b)-Vector(a)
        self.axial(a,d,[(0,r),(d.length,rb if rb is not None else r)],material,n,smooth=n>8)

    def strap(self,a,b,width,thickness,material):
        # A rectangular strap parallel to the face of the chassis.
        av,bv=Vector(a),Vector(b)
        d=(bv-av).normalized()
        depth=Vector((0,1,0))
        widthv=depth.cross(d).normalized()
        rings=[]
        for center in [av,bv]:
            rings.append([center+widthv*(sx*width/2)+depth*(sy*thickness/2) for sx,sy in [(1,1),(-1,1),(-1,-1),(1,-1)]])
        self.loft(rings,material)

    def side_plate(self,side,outline,inner,outer,material):
        rings=[[(s*side,y,z) for y,z in outline] for s in (inner,outer)]
        if side<0: rings=[list(reversed(r)) for r in rings]
        self.loft(rings,material)

    def bolt(self,origin,axis,r,bright,iron):
        self.axial(origin,axis,[(0,r*1.32),(.007,r*1.32),(.009,r*1.17)],iron,12)
        self.axial(origin,axis,[(.007,r*.93),(.011,r),(.019,r),(.022,r*.86)],bright,6,False)

    def finish(self,resolve):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts,[],self.faces)
        mesh.update()
        slots={}
        for i,(mat,smooth) in enumerate(zip(self.mats,self.smooth)):
            if mat not in slots:
                slots[mat]=len(mesh.materials)
                mesh.materials.append(resolve(mat))
            mesh.polygons[i].material_index=slots[mat]
            mesh.polygons[i].use_smooth=smooth
        obj=bpy.data.objects.new(self.name,mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def _castings(base, body, hardware, kind, palette):
    dark, iron, trim, edge, red = palette
    foot_height={"junior":.15,"intermediate":.12,"senior":.17,"planetary":.19,"void":.20}[kind]
    # All sections share a real cast bed, recessed between separate projecting shoes.
    base.slab(0,.04,.07,.84,.57,.12,.12,dark)
    base.slab(0,.03,.19,.83,.57,.045,.095,edge)
    base.slab(0,.01,.235,.80,.57,.10,.10,iron)
    body.horizontal([(0,-.015,.31,.78,.635,.13),(0,-.015,.52,.78,.635,.13),
                     (0,-.015,1.05,.69,.61,.12),(0,-.01,1.38,.59,.51,.115),
                     (0,.015,1.60,.43,.41,.075),(0,.025,1.66,.38,.38,.07)],iron)
    # The upper casting is open to the gantry seat, with a stepped flange over the shell.
    body.slab(0,.02,1.59,.445,.41,.055,.083,dark)
    body.slab(0,.02,1.645,.426,.393,.037,.070,trim)

    # The console is a single assembly with a deep service cavity. Its top backplate
    # ties into the sloped main casting, including the space under the gantry seat.
    body.horizontal([(0,-.465,.205,.663,.204,.061),(0,-.460,.555,.650,.207,.059),
                     (0,-.438,.91,.552,.232,.057),(0,-.403,1.23,.397,.269,.05),
                     (0,-.373,1.53,.276,.295,.04),(0,-.350,1.585,.234,.284,.037)],dark)
    body.slab(0,-.486,.154,.656,.200,.077,.052,trim)
    for s in (-1,1):
        # Two cast red-oxide inspection inserts flank the front access hatch.
        # Senior models retain only the narrow metal return at each side of the keyboard.
        if kind in ('junior','senior','void'):
            access='oxide' if kind=='junior' else iron
            body.slab(s*.436,-.651,.225,.134,.033,.298,.016,trim)
            body.slab(s*.436,-.681,.241,.118,.017,.264,.012,access)
            for zz in (.262,.48):
                for dx in (-.087,.087):
                    hardware.bolt((s*.436+dx,-.697,zz),(0,-1,0),.012,edge,dark)
        # Sealed shoulder inspection chambers give every badge a full backing and socket.
        if kind!='junior':
            body.horizontal([(s*.635,-.298,1.22,.126,.225,.044),
                             (s*.609,-.288,1.29,.152,.223,.048),
                             (s*.609,-.282,1.55,.153,.223,.048),
                             (s*.602,-.270,1.592,.149,.220,.044),
                             (s*.572,-.238,1.626,.131,.193,.046),
                             (s*.551,-.208,1.662,.108,.159,.044)],iron)
            body.slab(s*.602,-.270,1.568,.152,.223,.030,.049,trim)
            # Forked upper bearing yoke. The forward strand leans into the mast
            # upright and its rear sister lands on the deeper level of the deck.
            for yy in (-.274,-.126):
                hardware.strap((s*.560,yy,1.650),(s*.365,-.117,1.802),.064,.053,trim)
            hardware.axial((s*.351,-.118,1.795),(s,0,0),
                           [(0,.046),(.029,.051),(.045,.042)],iron,12)
            hardware.bolt((s*.399,-.118,1.795),(s,0,0),.020,edge,dark)
            for yy in (-.329,-.071):
                hardware.bolt((s*.574,yy,1.664),(0,0,1),.019,edge,dark)
        x=s*.84
        # Machined receiver pads expose a mounting face to every main Pipette flange.
        # Pads continue behind the bore into their structural casting.
        body.axial((s*.958,-.546,.237),(0,0,1),[(0,.119),(.037,.130),(.064,.126),(.090,.126)],iron,24)
        if kind=='junior':
            body.axial((s*.421,-.206,1.51),(s,0,0),[(0,.137),(.074,.142),
                        (.125,.133),(.134,.132)],iron,24)
        else:
            body.axial((s*.715,-.250,1.445 if kind=='void' else 1.427),(s,0,0),
                       [(0,.138),(.043,.142),(.051,.141)],iron,24)
        body.slab(s*.773,.596,.227,.112,.112,.190,.04,iron)
        body.slab(s*.459,.435,1.341,.096,.102,.146,.028,iron)
        # Secondary rear shoe and fore/aft rails join the broad front toes into one frame.
        base.slab(s*.78,.48,.012,.215,.245,.095,.075,dark)
        base.slab(s*.78,.48,.095,.207,.233,.062,.072,iron)
        base.slab(s*.80,-.03,.08,.149,.52,.105,.06,dark)
        base.slab(s*.80,-.045,.175,.151,.525,.032,.06,trim)
        base.slab(x,-.59,.008,.205,.31,foot_height,.086,dark)
        base.slab(x,-.59,foot_height-.015,.207,.30,.044,.084,trim)
        base.horizontal([(x,-.59,foot_height+.028,.194,.29,.082),
                         (s*.835,-.57,foot_height+.10,.191,.28,.080),
                         (s*.82,-.53,foot_height+.16,.167,.25,.062)],iron)
        # Individual mounting ears and their captive hex hold-downs.
        for y in (-.80,-.40):
            hardware.bolt((s*.953,y,foot_height+.03),(0,0,1),.037,edge,dark)
        for yy in (-.82,-.60):
            hardware.bolt((s*1.031,yy,foot_height*.52),(s,0,0),.033,edge,dark)
        # Deep knee fixed in the base, tapering back toward the highest shoulder.
        body.horizontal([(s*.82,-.53,foot_height+.13,.169,.245,.065),
                         (s*.81,-.5,.46,.154,.24,.059),
                         (s*.76,-.42,.81,.152,.235,.055),
                         (s*.68,-.34,1.02,.145,.22,.052),
                         (s*.61,-.27,1.18,.126,.19,.050)],iron)
        # Integral cast wedge behind the facing, including its top chain lug landing.
        body.horizontal([(s*.831,-.658,.257,.126,.148,.035),
                         (s*.819,-.657,.488,.123,.139,.031),
                         (s*.787,-.655,.753,.115,.125,.030),
                         (s*.780,-.655,.796,.102,.112,.028)],iron)
        # Sloping front edges carry a replaceable brass sole and a recessed metal web.
        hardware.strap((s*.828,-.803,.29),(s*.788,-.758,.75),.17,.042,trim)
        hardware.strap((s*.828,-.83,.315),(s*.789,-.785,.719),.105,.025,iron)
        for z,t in ((.34,0),(.69,1)):
            hardware.bolt((s*(.828-.037*t),-.854+.04*t,z),(0,-1,0),.023,edge,dark)
        # Slopes beyond the fascia and behind the front intake, exposed in a side view.
        outline=[(-.50,.35),(.48,.35),(.58,.45),(.55,.88),(.33,1.11),(-.24,1.02),(-.46,.71)]
        body.side_plate(s,outline,.71,.77,iron)
        # Louvred service door in the low side cheek, with perimeter and inset.
        outer=[(-.37,.38),(.29,.38),(.36,.45),(.31,.67),(-.29,.72),(-.40,.65)]
        inner=[(-.33,.408),(.269,.408),(.32,.456),(.28,.645),(-.27,.685),(-.36,.63)]
        body.side_plate(s,outer,.765,.804,trim)
        body.side_plate(s,inner,.803,.816,dark)
        for j in range(5):
            yy=-.243+j*.108
            body.side_plate(s,[(yy,.456),(yy+.041,.456),(yy+.053,.635),(yy+.013,.641)],.812,.835,iron)
        for yy,zz in ((-.32,.46),(.26,.46),(-.29,.65),(.26,.62)):
            hardware.bolt((s*.82,yy,zz),(s,0,0),.014,edge,dark)

        # The rear heel buttresses carry the motor and frame on a continuous load path.
        body.horizontal([(s*.78,.46,.15,.18,.205,.065),(s*.77,.46,.44,.15,.19,.057),
                         (s*.70,.40,1.00,.12,.16,.045),(s*.55,.30,1.37,.10,.13,.04)],iron)
        hardware.strap((s*.78,.653,.26),(s*.57,.468,1.29),.075,.049,trim)
        for yy in (.58,.40):
            hardware.bolt((s*.89,yy,.168),(0,0,1),.029,edge,dark)


def _motor(pieces,gear,kind,palette):
    dark,iron,trim,edge,red=palette
    # Axial sections are read from the casting outward, so each fin has an actual root.
    patterns={
        "junior":(.34,9,.096,.212),
        "intermediate":(.31,9,.103,.205),
        "senior":(.335,11,.105,.175),
        "planetary":(.30,8,.115,.195),
        "void":(.29,5,.094,.17)}
    r,fins,_,yy=patterns[kind]
    zz=1.02 if kind!="intermediate" else 1.06
    for s in (-1,1):
        o=(s*.49,yy,zz); axis=(s,0,0)
        pieces.axial(o,axis,[(0,r*.82),(.09,r*.95),(.105,r),(.145,r),(.162,r*.9),
                             (.30,r*.85),(.35,r*.93),(.38,r*.88)],dark,36)
        for j in range(fins):
            t=.155+j*(.175/max(1,fins-1))
            radius=r*(1.04-.12*(j/max(1,fins-1)))
            pieces.axial(o,axis,[(t,radius*.92),(t+.004,radius),(t+.012,radius),
                               (t+.017,radius*.92)],iron if j%3 else edge,36)
        # Stepped gearbox front and large boss, separately cast. Recesses sit between the ribs.
        cap=.365
        pieces.axial(o,axis,[(cap,r*.92),(cap+.015,r*.97),(cap+.036,r*.97),(cap+.048,r*.89)],
                     trim,36)
        pieces.axial(o,axis,[(cap+.041,r*.85),(cap+.060,r*.88),(cap+.078,r*.78),
                             (cap+.085,r*.63),(cap+.088,r*.36)],iron,36)
        pieces.axial(o,axis,[(cap+.08,r*.42),(cap+.10,r*.46),(cap+.125,r*.40),
                             (cap+.138,r*.28)],dark,24)
        pieces.axial(o,axis,[(cap+.13,r*.3),(cap+.147,r*.33),(cap+.161,r*.26)],edge,8,False)
        for a in range(8):
            theta=2*math.pi*a/8
            sy,sz=math.cos(theta),math.sin(theta)
            gear.bolt((s*(.49+cap+.047),yy+sy*r*.862,zz+sz*r*.862),axis,.019,edge,dark)
            gear.rod((s*.939,yy+sy*r*.43,zz+sz*r*.43),
                     (s*.925,yy+sy*r*.74,zz+sz*r*.74),.014,trim,8)
        # Rear access housing in the reduction box, visually darker against the bright cap.
        if kind in ("void","intermediate"):
            o2=(s*.51,yy-.32,zz+.17)
            pieces.axial(o2,axis,[(0,.099),(.20,.10),(.21,.129),(.245,.126),(.272,.104),
                                  (.285,.073)],trim,20)
            pieces.axial(o2,axis,[(.282,.075),(.289,.077),(.30,.046)],dark,18)
    # Serviceable back with heat exchanger and upper vent shutters.
    rear_y=.597
    pieces.slab(0,.478,.39,.52,.122,.67,.074,iron)
    pieces.slab(0,.588,.49,.44,.06,.44,.034,trim)
    pieces.slab(0,.636,.511,.41,.028,.395,.024,dark)
    for j in range(8):
        z=.54+j*.045
        pieces.slab(0,.666,z,.38,.035,.021,.009,iron)
    for s in (-1,1):
        for zz in (.53,.885):
            gear.bolt((s*.417,.659,zz),(0,1,0),.018,edge,dark)

def _round_bends(points):
    knots=[Vector(p) for p in points]
    result=[tuple(knots[0])]
    for a,b,c in zip(knots,knots[1:],knots[2:]):
        incoming=(b-a)
        outgoing=(c-b)
        fillet=min(.12,incoming.length*.44,outgoing.length*.44)
        p0=b-incoming.normalized()*fillet
        p2=b+outgoing.normalized()*fillet
        for i in range(7):
            t=i/6
            result.append(tuple(p0*(1-t)**2+b*(2*t*(1-t))+p2*t*t))
    return result+[tuple(knots[-1])]


def _adopt_part(assembly, part, material, smooth):
    offset=len(assembly.verts)
    assembly.verts.extend(part['vertices'])
    for face in part['faces']:
        assembly.face([i+offset for i in face],material,smooth)


def _process_line(name, points, diameter, arch, section, joint, material, fitting_mat,
                  collar_mat, coats,resolve,clamps=()):
    from pipette import build_fitting, library_geometry as geo, library_fittings as fittings
    assembly=_Assembly(name)
    curve=_round_bends(points)
    # The FMPL mesh uses an open bore across both ends including elbows.
    part=geo.tube(curve,diameter,.21,section,name,arch,sides=16,pitch=max(.08,diameter*1.12))
    _adopt_part(assembly,part,material,True)
    for end, p, neighbor in ((0,points[0],points[1]),(-1,points[-1],points[-2])):
        norm=geo.unit(geo.sub(p,neighbor))
        socket={'id':name+(' return' if end else ' supply'),'xyz_bu':p,'outward_normal':norm}
        for piece in build_fitting(arch,joint,socket,diameter=diameter):
            part_mat=coats if 'bolt' in piece['name'].lower() else fitting_mat
            _adopt_part(assembly,piece,part_mat,False)
    # Each split collar sits across the axis, with a pair of dark thinned gasket lips.
    for segment,t in clamps:
        a,b=Vector(points[segment]),Vector(points[segment+1])
        position=a.lerp(b,t)
        normal=(b-a).normalized()
        radius=diameter*.5
        for off,width,rr,mat_name in ((-.041,.015,1.13,material),(0,.058,1.22,collar_mat),(.04,.014,1.13,material)):
            sleeve=fittings.annul(tuple(position+normal*off),tuple(normal),radius*rr,radius*.92,
                                  width,arch=arch,label='External compression band',role='union-band',sides=20)
            _adopt_part(assembly,sleeve,mat_name,False)
    obj=assembly.finish(resolve)
    obj['fmpl_pipette_architecture']=arch
    obj['fmpl_pipette_terminal_joint']=joint
    obj['fmpl_pipette_socket_start_bu']=list(points[0])
    obj['fmpl_pipette_socket_end_bu']=list(points[-1])
    obj['fmpl_pipette_open_bore_diameter_bu']=diameter*.79
    return obj


def _circuits(kind,palette,resolve):
    dark,iron,trim,edge,red=palette
    for s,title in ((-1,'LH'),(1,'RH')):
        # A cast supply riser is seated in each toe and terminates on the shoulder at the mast.
        # Stacked bipartite unions allow the bent casting to be dismounted for service.
        route=[(.941,-.546,.265),(.943,-.548,.54),(.910,-.544,.80),(.862,-.523,.965),
               (.808,-.420,1.075),(.773,-.335,1.235),(.693,-.256,1.413),
               (.622,-.206,1.51),(.448,-.206,1.51)]
        diameter={'junior':.145,'intermediate':.17,'senior':.145,
                  'planetary':.142,'void':.173}[kind]
        if kind=='void':
            route=[(.94,-.57,.28),(.92,-.57,.54),(.906,-.565,.74),(.832,-.55,.94),
                   (.77,-.517,1.16),(.72,-.428,1.33),(.64,-.31,1.46),
                   (.55,-.195,1.55),(.41,-.195,1.55)]
        elif kind=='senior':
            route[2:6]=[(.920,-.55,.91),(.878,-.54,1.055),(.798,-.439,1.140),(.754,-.301,1.325)]
        elif kind=='intermediate':
            route[4:7]=[(.807,-.43,1.032),(.788,-.40,1.202),(.703,-.31,1.424)]
        # The socket face is outside the full shoulder case. Seating the flange on the
        # nominal central shell would bury it behind the shoulder reliquaries.
        route[0]=(.958,-.546,.339)
        route[1]=(.964,-.548,.56)
        if kind=='junior':
            route[-2:]=[(.672,-.206,1.51),(.562,-.206,1.51)]
        else:
            upper_z=1.445 if kind=='void' else 1.427
            route[4:]=[(.845,-.447,1.085),(.855,-.383,1.223),
                       (.878,-.310,upper_z-.082),(.854,-.250,upper_z),
                       (.773,-.250,upper_z)]
        mirrored=[(s*x,y,z) for x,y,z in route]
        _process_line(title+' | shoulder supply casting',mirrored,diameter,
                      'pipe_stainless_process' if kind=='void' else 'pipe_bronze_cast' if kind=='intermediate' else 'pipe_cast_iron_flanged',
                      'smooth_hollow','flange', iron if kind!='intermediate' else 'bronze',
                      trim,trim,edge,resolve,((0,.52),(2,.42),(4,.55),(6,.45)))
        # A sheltered pipe returning from the expansion chamber tucks into the rear heel.
        rears=[(.773,.706,.320),(.773,.768,.320),(.811,.777,.49),(.807,.745,.68),
               (.745,.696,.88),(.648,.680,1.143),(.535,.640,1.346),
               (.459,.611,1.414),(.459,.529,1.414)]
        _process_line(title+' | rear exchanger return',[(s*x,y,z) for x,y,z in rears],
                      .086 if kind!='void' else .115,'hose_metal_annular','annular_metal','hose_crimp',
                      'gunmetal' if kind=='void' else 'black',trim,trim,edge,resolve)
        if kind in ('senior','planetary','intermediate','void') or s==-1:
            # The instrument takeoff emerges from the knee, runs alongside the supply and
            # turns back to a separate higher port in the upper casting.
            points=[(.864,-.63,.447),(.881,-.64,.55),(.856,-.636,.85),(.78,-.612,1.022),
                    (.718,-.54,1.14),(.66,-.42,1.36),(.55,-.36,1.57),(.405,-.28,1.57)]
            if kind=='void':
                points=[(.84,-.646,.40),(.866,-.653,.59),(.845,-.644,.83),(.761,-.615,.995),
                        (.698,-.56,1.15),(.648,-.47,1.34),(.55,-.35,1.53),(.402,-.31,1.53)]
            if kind!='junior':
                # Metering passage has its own smaller tapped socket, anterior to the feed.
                points[4:]=[(.81,-.565,1.131),(.822,-.519,1.192),
                            (.826,-.441,1.268),(.765,-.406,1.299)]
            _process_line(title+' | instrument hardline',[(s*x,y,z) for x,y,z in points],
                          .061 if kind!='void' else .084,'tube_brass_instrument','smooth_hollow','compression',
                          ('steel' if kind=='void' else 'copper'),trim,trim,edge,resolve,
                          ((1,.54),(4,.52)))


def _edition_details(body, panels, hard, kind, palette):
    dark,iron,trim,edge,red=palette
    for s in (-1,1):
        # A subdued colored chip of vitreous access enamel behind the full structural lip.
        if kind in ('junior','intermediate'):
            a=[(-.23,.39),(.22,.39),(.268,.45),(.238,.60),(-.245,.61),(-.27,.55)]
            # Mounted rear of the main front bearing, between the vertical guide posts.
            panels.side_plate(s,[(y+.15,z+.45) for y,z in a],.637,.68,red)
        # Bolt-ended struts along the rear of the reducer carry the mast load to a cast heel.
        for y,dy in ((.32,.25),(-.14,-.09)):
            hard.rod((s*.51,y+dy*.12,1.52),(s*.70,y+dy*.25,1.22),.051,trim,10)
            hard.axial((s*.698,y+dy*.25,1.22),(s,0,0),[(0,.066),(.03,.070),(.046,.057)],edge,8,False)
        # Splayed back stiles embrace a functional, short rear service gallery.
        panels.strap((s*.66,.594,.34),(s*.43,.449,1.52),.093,.055,trim)
        panels.strap((s*.659,.626,.351),(s*.43,.473,1.51),.044,.019,iron)
        for z,xx,yy in ((.41,.651,.632),(.88,.565,.578),(1.39,.459,.510)):
            hard.bolt((s*xx,yy,z),(0,1,0),.018,edge,dark)
        # Tier-specific shoes. Void plate terminates in a rounded steel boot, senior has
        # square layered cover castings and junior's worn upright cheeks are planar brass.
        if kind=='void':
            p=(s*.848,-.575,.156)
            hard.axial(p,(0,0,1),[(0,.161),(.04,.164),(.066,.155),(.085,.13),(.105,.126)],'steel',20)
        elif kind in ('senior','planetary'):
            for j in range(2 if kind=='senior' else 3):
                panel_z=.204+j*.032
                panels.rod((s*.92,-.73,panel_z),(s*.92,-.42,panel_z),.015,trim,8)
        elif kind=='intermediate':
            for j in range(2):
                y=-.70+j*.082
                hard.axial((s*.98,y,.19),(s,0,0),[(0,.034),(.024,.036),(.03,.028)],edge,8,False)
    # Rear regulator gauge and isolator handwheel, bolted onto visible machine service doors.
    origin=(0,.517,1.205)
    hard.axial(origin,(0,1,0),[(0,.106),(.034,.137),(.06,.137),(.081,.115),(.103,.114)],trim,28)
    hard.axial(origin,(0,1,0),[(.095,.101),(.104,.099)],'ceramic',26)
    for i in range(10):
        a=math.radians(-125+i*(250/9))
        center=Vector((0,.624,1.205))
        needle=Vector((math.sin(a),0,math.cos(a)))
        hard.rod(center+needle*.074,center+needle*.093,.004,dark,6)
    hard.rod((0,.627,1.205),(-.036,.627,1.264),.006,red,6)
    hard.bolt((0,.632,1.205),(0,1,0),.012,edge,dark)
    # Thick open handwheel with solid spokes and threaded stem.
    center=Vector((-.29,.697,.983))
    hard.rod((-.29,.49,.983),center,.021,'steel',12)
    for i in range(20):
        a=math.tau*i/20
        b=math.tau*(i+1)/20
        pt=lambda t: center+Vector((.069*math.cos(t),0,.069*math.sin(t)))
        hard.rod(pt(a),pt(b),.010,red if kind!='void' else trim,8)
        if i%5==0: hard.rod(center,pt(a),.009,trim,8)
    hard.bolt(center,(0,1,0),.015,edge,dark)



def _cheek_columns(body,panels,hard,kind,palette):
    dark,iron,trim,edge,red=palette
    # Continuous web of the sloping frame. Its depth lands on both the forward
    # service cavity and the lower bed; it carries the individual facing strips.
    sections=[
        (.655,-.744,.224,.095),(.650,-.746,.375,.089),(.644,-.742,.613,.087),
        (.624,-.732,.809,.094),(.587,-.710,.980,.094),(.536,-.684,1.094,.087),
        (.483,-.639,1.218,.079),(.431,-.585,1.359,.070),
        (.380,-.517,1.490,.064),(.343,-.449,1.595,.063),(.320,-.399,1.66,.062)]
    for s in (-1,1):
        path=[(s*x,y+(.015 if s==1 and z>1.03 else 0),z,w) for x,y,z,w in sections]
        body.horizontal([(x,y+.105,z,w,.105,.024) for x,y,z,w in path],iron)
        # Pronounced relieved strip with a glint at the edges and steel in its well.
        panels.horizontal([(x,y-.002,z,w*.72,.026,.011) for x,y,z,w in path],trim)
        panels.horizontal([(x,y-.021,z,w*.46,.014,.008) for x,y,z,w in path],dark if kind!='void' else 'gunmetal')
        # Riveted shoes and keeper plates localize the joints instead of arbitrary studs.
        for i in (1,3,5,8):
            x,y,z,w=path[i]
            panels.slab(x,y+.014,z-.031,w+.020,.065,.067,.021,trim)
            for dx in (-.046,.046):
                hard.bolt((x+dx,y-.051,z+.003),(0,-1,0),.012,edge,dark)
        # Cast gussets bridge the jamb to the foot carrier around the front chain.
        for z,y,xx in ((.349,-.738,.744),(.690,-.705,.729)):
            body.slab(s*xx,y+.063,z,.116,.089,.048,.021,iron)
            hard.bolt((s*(xx+.041),y-.025,z+.024),(0,-1,0),.017,edge,dark)
        # A corrugated access inset occupies the recess where the cast jamb turns in.
        # Intermediate's plating has an extra lamina at the shoulder.
        for j in range(4 if kind=='intermediate' else 3):
            z=1.05+j*.057
            x=.660-j*.024
            y=-.490+j*.009
            body.horizontal([(s*x,y,z,.077,.068,.022),(s*x,y-.009,z+.013,.077,.073,.025),
                             (s*x,y-.006,z+.028,.065,.067,.023)],'steel' if kind=='void' else 'bronze')


def _rear_access(body,panels,hard,kind,palette):
    dark,iron,trim,edge,red=palette

    def yz(z):
        return .634-max(0.,z-.55)*.235

    def panel(profile,material,recess=.0,depth=.048):
        # Thickness is constant relative to the sloping access deck.
        outline=[(x,yz(z)+recess,z) for x,z in profile]
        rings=[[(x,y-d,z) for x,y,z in outline] for d in (depth,0.0)]
        panels.loft([list(reversed(r)) for r in rings],material)
    def framed(profile,inner,finish,recess=0):
        panel(profile,trim,recess)
        panel(inner,finish,recess+.008,.020)
    # Sloping rear removable access covers. Cast hinge barrels, captive catches and
    # individual ribs belong to this one hatch instead of being scattered over the wall.
    top=[(-.509,1.045),(.509,1.045),(.496,1.227),(.331,1.543),(.261,1.584),
         (-.25,1.584),(-.338,1.538),(-.493,1.241)]
    inside=[(-.471,1.073),(.471,1.073),(.460,1.224),(.304,1.518),(.242,1.552),
            (-.235,1.552),(-.31,1.518),(-.456,1.232)]
    framed(top,inside,dark)
    grill=[(-.306,1.317),(.306,1.317),(.244,1.492),(.206,1.515),
           (-.20,1.515),(-.247,1.493)]
    panel(grill,iron,.020)
    # Shutters are tilted vanes with deep visible undercuts.
    for i in range(4):
        z=1.332+.039*i
        x=.265-.015*i
        rings=[]
        for xx in (-x,x):
            rings.append([(xx,yz(z)+.041,z),(xx,yz(z)+.066,z+.013),
                          (xx,yz(z)+.065,z+.019),(xx,yz(z)+.023,z+.014)])
        panels.loft(rings,iron if i%2==0 else dark)
    for s in (-1,1):
        for z,xx in ((1.091,.442),(1.245,.415),(1.498,.271)):
            hard.bolt((s*xx,yz(z)+.012,z),(0,1,0),.014,edge,dark)
    # Main cooler door is split off the crankcase flange. A pair of real hinges
    # shares one vertical pin, while the opposite side has quarter-turn dogs.
    for z in (.54,.79):
        panels.slab(-.455,.625,z,.048,.037,.085,.012,trim)
        p=(-.461,.671,z-.003)
        hard.axial(p,(0,0,1),[(0,.023),(.021,.025),(.026,.019),(.062,.024),
                                (.070,.022),(.077,.018),(.087,.021)],edge,12)
        hard.rod((-.461,.671,z-.013),(-.461,.671,z+.099),.009,'steel',8)
        hard.axial((.443,.644,z+.041),(0,1,0),[(0,.037),(.026,.042),(.039,.029)],dark,12)
        hard.rod((.418,.687,z+.029),(.469,.687,z+.054),.009,trim,8)
    # Stiffened inspection panels in the lower removable kick plate, slightly uneven
    # left/right since one panel must clear the valve train.
    for s in (-1,1):
        x=s*(.32 if s<0 else .34)
        panels.slab(x,.579,.287,.237,.051,.134,.025,trim)
        panels.slab(x,.625,.303,.212,.023,.102,.017,dark)
        for dx in (-.178,.178):
            hard.bolt((x+dx,.649,.354),(0,1,0),.014,edge,dark)
        for dx in (-.081,-.027,.027,.081):
            panels.rod((x+dx,.649,.316),(x+dx,.649,.390),.009,iron,8)
    # Load-bearing webs splay from the gauge header to the sides of the cooler.
    for side in (-1,1):
        panels.strap((side*.14,yz(1.28)+.026,1.28),(side*.36,yz(1.035)+.033,1.035),.041,.027,iron)
    # Transfer housing behind the visible handwheel, with a small packing nut.
    hard.axial((-.29,.557,.983),(0,1,0),[(0,.051),(.042,.063),(.062,.064),(.071,.050),
                                         (.084,.043),(.097,.046),(.109,.040)],trim,12)
    hard.axial((-.29,.656,.983),(0,1,0),[(0,.043),(.021,.047),(.027,.035)],edge,6,False)


def _filter(body,hard,kind,palette,resolve):
    dark,iron,trim,edge,red=palette
    # The oil separator occupies the free service side opposite the main wire loom.
    # A bracket to the lower casting supports the bowl; both lines land on the casting.
    a=Vector((-.874,-.231,.576));b=Vector((-.86,-.184,1.086));direction=(b-a).normalized()
    body.axial(a,direction,[(0,.042),(.037,.081),(.058,.094),(.076,.098),(.093,.091),
                          (.312,.093),(.332,.105),(.352,.104),(.362,.094),
                          (.406,.090),(.421,.109),(.456,.107),(.476,.084),(.499,.057)],
               'steel' if kind=='void' else 'bronze',24)
    for at in (.099,.316):
        hard.axial(a,direction,[(at,.094),(at+.008,.102),(at+.020,.101),(at+.026,.094)],dark,24)
    for i in range(8):
        angle=math.tau*i/8
        shift=Vector((.093*math.cos(angle),.093*math.sin(angle),0))
        hard.rod(a+direction*.134+shift,a+direction*.296+shift,.009,iron,8)
    hard.axial(a,direction,[(-.033,.031),(-.012,.036),(0,.033)],edge,6,False)
    for zz,xx in ((.686,-.874),(.995,-.863)):
        body.slab(-.818,-.199,zz,.094,.061,.043,.019,iron)
        hard.bolt((xx,-.249,zz+.020),(0,-1,0),.020,edge,dark)
    # Bundling the drain test line separately leaves the rear gearbox cover removable.
    body.rod((-.687,.005,1.161),(-.713,-.064,1.233),.044,iron,12)
    hard.axial((-.685,-.064,1.233),(-1,0,0),[(0,.039),(.019,.042),(.027,.038)],trim,12)
    pts=[(-.86,-.185,1.076),(-.86,-.185,1.131),(-.836,-.133,1.203),
         (-.778,-.072,1.233),(-.713,-.064,1.233)]
    _process_line('LH | separator-to-bearing pressure line',pts,.042,'tube_copper_capillary',
                  'smooth_hollow','compression','steel' if kind=='void' else 'copper',
                  trim,trim,edge,resolve)


def build_chassis(kind):
    """Build a distinct chassis edition at the shared local attachment datum."""
    from common import mat
    palettes={
        'junior':('dark','iron','bronze','brass','oxide'),
        'intermediate':('dark','gunmetal','bronze','gold','oxide'),
        'senior':('dark','iron','bronze','brass','oxide'),
        'planetary':('dark','iron','bronze','brass','oxide'),
        'void':('dark','gunmetal','steel','brass','oxide')}
    palette=palettes[kind]
    parts=[_Assembly(kind+' | '+name) for name in ('split foundation shoes','tapered engine casting',
            'service door and buttresses','finned reduction housings','studs and instrumentation')]
    base,body,panels,motor,hardware=parts
    _castings(base,body,hardware,kind,palette)
    _motor(motor,hardware,kind,palette)
    _edition_details(body,panels,hardware,kind,palette)
    _cheek_columns(body,panels,hardware,kind,palette)
    _rear_access(body,panels,hardware,kind,palette)
    _filter(body,hardware,kind,palette,mat)
    for p in parts: p.finish(mat)
    _circuits(kind,palette,mat)
