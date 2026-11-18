"""Read actual retained collar vertices; bind center/phase to repaired shafts."""
import bpy,json,pathlib,hashlib,math,numpy as np
R=pathlib.Path.cwd();D=R/'build/thruster-resume-20261117/thetazine-v06-motion/core08-matched-collar-facets';src=D/'thetazine-v06-matched-collar-motion.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(src));bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
A=np.array([0,-math.cos(math.radians(25)),-math.sin(math.radians(25))]);U=np.array([1,0,0]);V=np.cross(A,U);step=math.tau/48;rows=[]
def points(o):return np.array([o.matrix_world@v.co for v in o.data.vertices],dtype=float)
def angular(q,center):
    off=q-center;off-=np.outer(off@A,A);r=np.linalg.norm(off,axis=1)
    return np.arctan2(off@V,off@U),r
for sign,offset in[(-1,0),(1,4)]:
    for i in range(4):
        n=offset+i;collar=bpy.data.objects['Outer actuator collar'+(''if n==0 else f'.{n:03d}')];shaft=bpy.data.objects[f'Outer actuator body {sign}'if i<2 else f'V06 giant actuator sliding rod {sign}']
        cp=points(collar);sp=points(shaft);cc=cp.mean(0);sc=sp.mean(0);cd=cc-sc;cd-=A*(cd@A)
        ca,cr=angular(cp,cc);sa,sr=angular(sp,sc);ca=ca[cr<.13];sa=sa[sr>.09]
        phase=np.abs((ca[:,None]-sa[None,:]+step/2)%step-step/2).min(1)
        rows.append({'collar':collar.name,'shaft':shaft.name,'actual_collar_center_world':cc.tolist(),'actual_shaft_center_world':sc.tolist(),'perpendicular_axis_offset_bu':float(np.linalg.norm(cd)),'maximum_angular_phase_difference_rad':float(phase.max()),'actual_collar_inner_radius_range_bu':[float(cr[cr<.13].min()),float(cr[cr<.13].max())],'actual_shaft_seating_radius_range_bu':[float(sr[sr>.09].min()),float(sr[sr>.09].max())],'pass':float(np.linalg.norm(cd))<1e-6 and float(phase.max())<1e-5})
report={'status':'PASS_ACTUAL_RETAINED48FACET_COLLAR_FRAMES'if all(r['pass']for r in rows)else'FAIL_ACTUAL_COLLAR_FRAME_MATCH','source_sha256':sha(src),'script_sha256':sha(pathlib.Path(__file__)),'units':'BU; no real-world scale inferred','rows':rows}
(D/'actual-collar-frame-measurement.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report['status'],json.dumps(rows),flush=True)
