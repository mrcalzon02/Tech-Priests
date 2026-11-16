"""Foredeck charge-cassette assemblies and the hinged feed handling gear."""
from math import sin, cos, pi
from structure import Fabricator
from forge import group

def build(tier,r):
    f=Fabricator(r)
    group('Fuel charging station')
    count=tier+1
    d=.088 if tier>1 else .104
    spacing=2*d+.046
    cx=-.04; y=-.79
    z=.257
    w=(count-1)*spacing+2*d+.12
    f.box('Replaceable loading cassette foot',(cx,y,.21),(w+.05,.35,.060),'black',.024)
    f.box('Cast charging tray',(cx,y,z-.020),(w,.32,.076),'iron',.022)
    for side in [-1,1]:
        x=cx+side*(w/2-.015)
        f.box('Armoured end cleat',(x,y,.29),(.066,.32,.117),'red_dark',.02)
    # Alternating bronze and black caution inlays run across the low front lip.
    f.box('Loading lip wear strip',(cx,y-.158,.289),(w-.08,.021,.054),'brass',.004)
    i=0
    while -.5*w+.07+i*.104 < .5*w-.13:
        x=cx-.5*w+.07+i*.104
        f.xz('Diagonal warning inlay',[(x,.265),(x+.047,.265),(x+.077,.312),(x+.030,.312)],y-.171,y-.168,'black')
        i+=1
    for i in range(count):
        x=cx+(i-(count-1)/2)*spacing
        z1=.56+(.015 if i%2 else 0)
        f.cyl('Bayonet seat',(x,y,.258),(x,y,.30),d*1.12,'black',20,.006)
        f.cyl('Canister foot hoop',(x,y,.293),(x,y,.325),d*1.02,'edge',28,.004)
        f.cyl('Replaceable charge canister',(x,y,.316),(x,y,z1),d,'red' if i%2==0 else 'steel',32,.012)
        for zp in [.337,z1-.045,z1-.025]:
            f.cyl('Crimped bottle retaining hoop',(x,y,zp),(x,y,zp+.010),d*1.02,'edge',32,.002)
        f.cyl('Shouldered charge cap',(x,y,z1-.012),(x,y,z1+.036),d*.93,'steel',32,.009)
        f.cyl('Fuel valve collar',(x,y,z1+.03),(x,y,z1+.055),d*.60,'brass',12,.005)
        f.cyl('Connector plug',(x,y,z1+.052),(x,y,z1+.068),d*.36,'black',16,.003)
        f.box('Canister inspection label',(x,y-d*.98,.418),(.053,.006,.065),'ivory',.003)
        for n in range(3):
            f.box('Stamped canister graduations',(x,y-d-.003,.407+.013*n),(.037 if n!=1 else .022,.003,.003),'black')
    # A low cantilever provides the charge-bottle lift without obscuring the vessel.
    group('Fuel manipulator')
    bx=cx-w/2-.122; by=-.725
    f.cyl('Bearing foot',(bx,by,.178),(bx,by,.251),.087,'iron',20,.012)
    f.cyl('Bronze slew ring',(bx,by,.25),(bx,by,.278),.075,'brass',24,.004)
    f.box('Gantry post',(bx,by,.425),(.082,.093,.31),'red',.012)
    for xx in [bx-.043,bx+.043]:
        f.box('Gantry column flange',(xx,by,.425),(.021,.117,.31),'steel',.003)
    # Folded jib uses shaped paired cheeks, a real pivot, and a drop hook.
    ez=.73+.026*tier; ex=bx+.30
    for yy in [by-.065,by+.047]:
        f.xz('Cast lifting jib cheek',[(bx-.066,.537),(bx-.062,.61),(bx+.013,.675),(ex-.020,ez+.036),(ex+.047,ez+.014),(ex+.041,ez-.034),(bx+.035,.598),(bx+.018,.547)],yy,yy+.020,'copper')
    f.cyl('Jib pivot',(bx,by-.083,.588),(bx,by+.082,.588),.048,'steel',24,.006)
    f.cyl('Hoist pulley',(ex,by-.063,ez),(ex,by+.072,ez),.035,'black',24,.003)
    f.cyl('Center pin',(ex,by-.079,ez),(ex,by+.076,ez),.014,'edge',12)
    f.tube('Hardened lift hook',[(ex,by,ez-.015),(ex,by,.642),(ex+.013,by,.629),(ex+.036,by,.630),(ex+.047,by,.652)],.010,'edge',10,.011)
    f.tube('Protected ram',[ (bx-.028,by,.358),(bx+.047,by,.482),(ex-.051,by,ez-.043)],.024,'iron',12,.024)
    f.tube('Feedback loom',[(bx-.047,by,.344),(bx-.088,by,.371),(bx-.102,by,.419),(bx-.093,by,.478),(bx-.041,by,.50)],.011,'rubber',10,.014)
