"""Audit a separately reopened FMPL reactor with Blender's auto-run disabled."""
import json,sys
from pathlib import Path
from math import isclose
import bpy
import numpy as np
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import fmpl_adapter as f
from thermal_rig import heat_zones,steam_emitters
from energy_rig import port_pulse

def verify(tier,out):
    sc=bpy.context.scene;name=f.NAMES[tier-1];r=f.RADII[tier-1]
    cfg=f.profile(tier);receipt=f.audit(sc,cfg)
    assert (sc.frame_start,sc.frame_end,sc.render.fps)==(1,96,48)
    objects=list(bpy.data.collections[name].objects)
    rotors=[o for o in objects if o.get('fmpl_role')=='driven_rotor']
    jets=[o for o in objects if o.get('fmpl_reactor_fx')=='steam']
    hot=[o for o in objects if o.get('fmpl_reactor_fx')=='heat']
    ports=sorted([m for m in bpy.data.materials if 'fmpl_port_index' in m],key=lambda m:int(m['fmpl_port_index']))
    count=(10,12,16)[tier-1]
    assert len(rotors)==2 and len(ports)==count
    assert len(hot)==len(heat_zones(tier,r)) and len(jets)==12*len(steam_emitters(tier,r))
    assert all(im.packed_file for im in bpy.data.images if im.users and im.type=='IMAGE')
    def evaluate(power,frame):
        sc['reactor_power']=float(power);sc.update_tag();sc.frame_set(frame)
        bpy.context.view_layer.update()
    def matrices():
        return np.array([np.asarray(o.matrix_world) for o in jets+rotors])
    def strength(mat):
        return mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value
    max_error=0.
    for n,frame in enumerate(f.ACTIVE_FRAMES):
        evaluate(1,frame)
        expected=[port_pulse(frame,i,count,96) for i in range(count)]
        actual=[m['fmpl_pulse'] for m in ports]
        max_error=max(max_error,float(np.max(np.abs(np.array(actual)-expected))))
        assert max_error<1.e-4
        assert all(strength(m)>0.1 for m in ports)
        assert all(not o.hide_render for o in jets+hot)
    evaluate(1,1);first=matrices()
    evaluate(1,25);assert np.max(np.abs(matrices()-first))>.01
    evaluate(1,97);closure=float(np.max(np.abs(matrices()-first)));assert closure<1.e-4
    evaluate(0,37);assert all(o.hide_render and o.hide_viewport for o in jets+hot)
    assert all(strength(m)==0 for m in ports)
    assert all(abs(o.rotation_axis_angle[0])<1.e-6 for o in rotors)
    data={'name':name,'clockwise_ports':count,'moving_shafts':len(rotors),'vent_outlets':len(steam_emitters(tier,r)),
          'heat_boundaries':len(hot),'max_pulse_envelope_error':max_error,'frame_1_97_transform_error':closure,
          'cold_emit_strength':0,'cold_steam_visible':False,'cold_heat_visible':False,'autoexec_required':False,'camera':receipt}
    out.mkdir(parents=True,exist_ok=True)
    (out/(name+'-rig.json')).write_text(json.dumps(data,indent=2))
    print('PASS',name,closure,max_error,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:];verify(int(args[0]),Path(args[1]))
