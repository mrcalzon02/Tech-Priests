"""Pinned supports between each inspection plate and its rear loader housing."""
import math
from mathutils import Matrix, Vector


def build_hatch_stays(api, hatch, x):
    box, cylinder, tube, parent_world = [api[k] for k in ('box','cylinder','tube','parent_world')]
    axis = Vector((1, 0, 0))
    for side in (-1, 1):
        pins = []
        for front in (True, False):
            slope = -math.atan(.07/.31) if front else math.atan(.16/.24)
            rot = Matrix.Rotation(slope, 3, 'X')
            normal = rot @ Vector((0,0,1))
            surface = (Vector((x,.22,3.041)) + rot @ Vector((side*.14,.075,.0125))
                       if front else Vector((x+side*.14,.75,3.04)))
            pin = surface + normal*.056
            pins.append(pin)
            mounted = []
            foot = box('Hatch stay bolted mounting foot', surface+normal*.011,
                       (.095,.075,.022), 'dark', bevel=.003)
            foot.rotation_euler.x = slope
            mounted.append(foot)
            for offset in (-.034,.034):
                web = box('Hatch stay clevis web', surface+normal*.025+axis*offset,
                          (.022,.050,.018), 'dark', bevel=.002)
                web.rotation_euler.x = slope
                mounted.extend((web, tube('Hatch stay clevis lug',pin+axis*(offset-.011),
                                         pin+axis*(offset+.011),.035,.013,'dark')))
            mounted.append(cylinder('Hatch stay hinge pin',pin-axis*.056,pin+axis*.056,.015,'steel'))
            for end in (-1,1):
                mounted.append(cylinder('Hatch stay pin retaining head',pin+axis*(end*.050),
                                        pin+axis*(end*.059),.022,'steel',vertices=6))
            if front:
                for obj in mounted: parent_world(obj,hatch)
        start, end = pins
        direction = (end-start).normalized()
        for pin in pins:
            tube('Hatch support rod end eye',pin-axis*.014,pin+axis*.014,.032,.012,'steel')
        cylinder('Hatch support captive shaft',start+direction*.025,end-direction*.025,.014,'steel')
        delta = end-start
        tube('Hatch support telescopic sleeve',start+delta*.38,start+delta*.80,.026,.007,'dark')
        tube('Hatch support sleeve dust collar',start+delta*.36,start+delta*.42,.030,.011,'steel')
