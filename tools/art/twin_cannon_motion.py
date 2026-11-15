"""Deep independent recoil, slow runout, and a cold-entry/settle review clip."""
import math,json
from mathutils import Vector

STROKE=.90
SHOTS={0:[0,90],1:[45,135]}
def recoil(age):
    if age is None or age<0 or age>=80:return 0.0
    if age<3:return STROKE*(.5-.5*math.cos(math.pi*age/3))
    if age<=7:return STROKE
    t=(age-7)/73;s=t*t*t*(10+t*(-15+6*t))
    return STROKE*(1-s)

def author_motion(api):
    scene=api['S'];guns=api['gun_roots'];mantlets=api['mantlets'];rams=api['rams']
    rest=[obj.location.copy() for obj in guns];ram_rest=[obj.location.copy() for obj in rams]
    records=[]
    for frame in range(226):
        scene.frame_set(frame+1)
        row={'tick':frame,'recoil':[]}
        for bank,gun in enumerate(guns):
            history=[tick for tick in SHOTS[bank] if tick<=frame]
            age=frame-history[-1] if history else None
            kick=recoil(age);row['recoil'].append(kick)
            gun.location=rest[bank]+Vector((0,kick,0));gun.keyframe_insert('location')
            mantlets[bank].rotation_euler.x=.03*math.sin(math.pi*(age-12)/20) if age is not None and 12<=age<32 else 0
            mantlets[bank].keyframe_insert('rotation_euler')
            travel=.27*math.sin(math.pi*(age-52)/26) if age is not None and 52<=age<78 else 0
            rams[bank].location=ram_rest[bank]+Vector((0,-travel,0));rams[bank].keyframe_insert('location')
        api['update_feed'](frame,shot_schedule=SHOTS);records.append(row)
    for obj in guns+rams+mantlets+api['belt_rounds']:
        for slot in obj.animation_data.action.slots:
            for layer in obj.animation_data.action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for key in curve.keyframe_points:key.interpolation='LINEAR'
    scene.frame_start=1;scene.frame_end=226;scene.frame_set(1)
    scene['recoil_stroke']=STROKE;scene['recoil_peak_tick']=3;scene['return_to_battery_tick']=80
    scene['review_shots_json']=json.dumps(SHOTS);scene['steady_source_start_tick']=90
    scene['native_cannon_effect']='explosion-gunshot at the active barrel muzzle'
    assert abs(max(r['recoil'][0] for r in records)-STROKE)<1e-8
    assert records[45]['recoil'][0]>.35 and records[45]['recoil'][1]==0
    assert records[80]['recoil'][0]==0 and records[225]['recoil']==[0,0]
    (api['O']/'motion-contract.json').write_text(json.dumps({'status':'PASS','stroke':STROKE,
        'shot_ticks':SHOTS,'hard_recoil_ticks':3,'peak_hold_until_tick':7,'return_complete_tick':80,
        'review_end_tick':225,'samples':records},indent=2)+'\n')
