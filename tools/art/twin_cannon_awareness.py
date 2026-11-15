"""Supported sensing and communications hardware for the reviewed cannon."""
import math

def build_awareness(api):
    from twin_cannon_aerial_motion import make_whip
    api['flexible_whips']=[]
    box,cylinder,tube,armor,profile,conduit=[api[n] for n in ('box','cylinder','tube','armor','profile_body','conduit')]
    # Bridge feet seat on the new casemate shoulders. The optical head and
    # its full forward view clear the raised armour and recoiling barrels.
    for side in (-1,1):box('Director bridge shoulder foot',(side*.23,-.12,3.08),(.16,.32,.12),'dark',bevel=.012)
    box('Shoulder-spanning director bridge',(0,-.12,3.16),(.62,.32,.08),'dark',bevel=.012)
    cylinder('Director swivel pedestal',(0,-.12,3.18),(0,-.12,3.37),.075,'steel')
    tube('Director azimuth bearing',(0,-.12,3.30),(0,-.12,3.36),.13,.030,'dark')
    box('Director yoke cross member',(0,-.12,3.345),(.50,.28,.06),'dark',bevel=.010)
    for side in (-1,1):
        box('Optical director supporting cheek',(side*.22,-.12,3.445),(.055,.28,.23),'dark',bevel=.014)
        cylinder('Director elevation trunnion',(side*.18,-.12,3.50),(side*.27,-.12,3.50),.055,'steel')
    armor('Armoured multispectral director',0,-.12,3.39,.60,.34,.24)
    for x,z,r in ((-.16,3.49,.060),(.14,3.49,.035),(0,3.585,.027)):
        tube('Recessed sensor protective bezel',(x,-.282,z),(x,-.35,z),r+.020,.014,'dark')
        cylinder('Optical and thermal sensor glass',(x,-.335,z),(x,-.343,z),r,'lens')
    conduit('Director protected data harness',[(0,-.10,3.22),(0,.28,3.13),(0,.84,2.95),(0,1.00,2.80)],.022,'dark')
    for p in ((0,-.10,3.22),(0,1.00,2.80)):
        cylinder('Director harness sealed gland',p,(p[0],p[1],p[2]+.05),.040,'steel')

    # Two shoulder pods give independent close tracking outside the barrels.
    for side in (-1,1):
        x=side*1.23
        box('Flank sensor hull saddle',(side*1.10,-.30,2.56),(.16,.30,.25),'dark',bevel=.016)
        for dy in (-.09,.09):cylinder('Braced flank sensor outrigger',(side*1.11,-.30+dy,2.57),(x,-.30+dy,2.98),.028,'dark')
        box('Flank sensor outboard mounting plate',(x,-.30,2.98),(.26,.30,.06),'dark',bevel=.010)
        cylinder('Flank sensor riser',(x,-.30,2.98),(x,-.30,3.07),.048,'steel')
        box('Armoured flank tracking pod',(x,-.30,3.10),(.23,.30,.20),'red',bevel=.035)
        tube('Flank camera recessed hood',(x,-.44,3.10),(x,-.495,3.10),.077,.018,'dark')
        cylinder('Flank tracking camera glass',(x,-.475,3.10),(x,-.487,3.10),.052,'lens')
        for dx in (-.065,.065):cylinder('Flank pod lid screw',(x+dx,-.30,3.20),(x+dx,-.30,3.215),.015,'steel',vertices=6)
        box('Flank sensor loom routing clip',(side*1.14,.30,2.69),(.08,.06,.10),'dark',bevel=.008)
        conduit('Flank sensor armoured cable',[(x,-.16,3.08),(x,.05,2.89),(side*1.14,.30,2.72),(side*1.02,.53,2.64),(side*.19,1.02,2.77)],.019,'dark')
        for p in ((x,-.16,3.08),(side*.19,1.02,2.77)):
            cylinder('Flank harness termination',p,(p[0],p[1],p[2]+.040),.034,'steel')

    # A compact elevated search array has a supported mast and visible panels.
    cylinder('Search array mast foundation',(0,.90,2.63),(0,.90,2.74),.12,'dark')
    cylinder('Search radar and warning mast',(0,.90,2.70),(0,.90,3.70),.065,'steel')
    box('Search array electronics head',(0,.90,3.75),(.25,.22,.24),'red',bevel=.025)
    for sign in (-1,1):
        box('Search array protected face',(0,.90+sign*.125,3.76),(.36,.045,.27),'dark',bevel=.012)
        for z in (3.68,3.75,3.82):box('Radar array radiating strip',(0,.90+sign*.15,z),(.27,.012,.018),'steel',bevel=.003)
    conduit('Search array cabinet loom',[(0,.90,2.75),(.12,1.0,2.72),(.12,1.05,2.81)],.019,'dark')
    cylinder('Radar loom input gland',(.12,1.05,2.81),(.12,1.05,2.86),.035,'steel')

    # Three distinct connected aerials: tall command whip, short redundant
    # receiver, and a flat directional telemetry blade on the rear cabinet.
    for side,top in ((-1,3.95),(1,3.73)):
        x=side*1.20
        box('Radio bracket hull saddle',(side*1.12,.48,2.50),(.12,.32,.28),'dark',bevel=.015)
        for dy in (-.09,.09):cylinder('Radio outrigger supporting strut',(side*1.12,.48+dy,2.47),(x,.48+dy,2.76),.030,'dark')
        box('Radio aerial outboard mounting shoe',(x,.48,2.76),(.30,.28,.07),'dark',bevel=.012)
        cylinder('Insulated aerial socket',(x,.48,2.78),(x,.48,3.00),.060,'dark')
        cylinder('Radio socket central insulator',(x,.48,2.94),(x,.48,3.05),.035,'dark')
        for z in (2.88,2.94,3.00):tube('Whip spring retaining collar',(x,.48,z),(x,.48,z+.018),.068,.020,'steel')
        api['flexible_whips'].append(make_whip(api,len(api['flexible_whips']),x,top))
        for dx in (-.055,.055):
            for dy in (-.075,.075):cylinder('Radio shoe structural bolt',(x+dx,.48+dy,2.795),(x+dx,.48+dy,2.815),.018,'steel',vertices=6)
        conduit('Radio feed to fire-control cabinet',[(x,.48,2.84),(side*1.14,.77,2.64),(side*.19,.99,2.72)],.018,'dark')
        cylinder('Radio cabinet cable gland',(side*.19,.99,2.72),(side*.19,.99,2.77),.034,'steel')
    box('Directional link blade mounting plinth',(.16,1.35,3.04),(.15,.21,.09),'dark',bevel=.014)
    profile('Armoured directional telemetry blade',.16,.045,[(1.25,3.05),(1.46,3.05),(1.40,3.47),(1.31,3.47)],'dark')
    cylinder('Telemetry blade feedthrough',(.16,1.35,2.99),(.16,1.35,3.10),.045,'steel')

    # A rear-facing feed observer watches the covered belt and both inlets.
    box('Rear feed camera supporting bracket',(0,1.51,2.77),(.15,.16,.12),'dark',bevel=.012)
    box('Rear ammunition-feed observer',(0,1.54,2.86),(.21,.18,.18),'red',bevel=.025)
    tube('Rear observer optical hood',(0,1.62,2.86),(0,1.67,2.86),.055,.014,'dark')
    cylinder('Rear-feed camera glass',(0,1.651,2.86),(0,1.665,2.86),.036,'lens')
    conduit('Feed observer cabinet connection',[(0,1.47,2.80),(.11,1.39,2.74),(.12,1.25,2.74)],.017,'dark')
