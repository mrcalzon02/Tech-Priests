"""Flexible radio masts driven by recoil impulses and traverse acceleration."""
import math, json
from mathutils import Vector


def make_whip(api, bank, x, top):
    bpy=api['bpy']; height=top-3.01
    vertices=[]; faces=[]; rings=17; sides=12
    for j in range(rings):
        s=j/(rings-1); radius=.012*(1-.55*s)
        for i in range(sides):
            a=i*math.tau/sides
            vertices.append((radius*math.cos(a),radius*math.sin(a),height*s))
    for j in range(rings-1):
        for i in range(sides):
            faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    faces.extend((tuple(reversed(range(sides))),tuple((rings-1)*sides+i for i in range(sides))))
    mesh=bpy.data.meshes.new('Flexible tapered aerial');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('FLEXIBLE_RADIO_WHIP_'+str(bank),mesh);api['S'].collection.objects.link(obj)
    obj.location=(x,.48,3.01);api['finish'](obj,obj.name,'dark')
    obj.shape_key_add(name='Rest')
    for axis in (0,1):
        key=obj.shape_key_add(name='Flex '+('X' if axis==0 else 'Y'));key.slider_min=-1;key.slider_max=1
        for index,vertex in enumerate(vertices):
            s=(index//sides)/(rings-1);key.data[index].co=vertex;key.data[index].co[axis]+=.24*s*s
    cap=api['cylinder']('Flexible whip protective tip',(x,.48,top-.018),(x,.48,top+.018),.014,'dark',vertices=12)
    return {'object':obj,'cap':cap,'rest':cap.location.copy(),'height':height,'x':x,'bank':bank}


def yaw_at(tick):
    # Separate traverse study after the firing/settling demonstration.
    def ease(t):
        t=max(0,min(1,t));return t*t*(3-2*t)
    return 1.05*ease((tick-240)/55)-1.65*ease((tick-320)/55)


def author_aerial_motion(api, shots):
    scene=api['S']; root=api['root']; whips=api['flexible_whips']; records=[]
    states=[{'p':Vector((0,0)),'v':Vector((0,0))} for _ in whips]
    dt=1/60; last_yaw=yaw_at(-1); last_speed=0
    for tick in range(481):
        scene.frame_set(tick+1);yaw=yaw_at(tick);speed=(yaw-last_yaw)/dt;accel=(speed-last_speed)/dt
        root.rotation_euler.z=yaw;root.keyframe_insert('rotation_euler')
        samples=[]
        for whip,state in zip(whips,states):
            p,v=state['p'],state['v'];omega=math.tau*(2.5 if whip['bank']==0 else 3.25)
            for bank,times in shots.items():
                if tick in times:
                    v.y+=1.30 if bank==whip['bank'] else .85
                    v.x+=(-1 if bank==0 else 1)*.30
            # Inertial bending opposes tangential acceleration; mounts remain fixed.
            forcing=Vector((accel*.48+speed*speed*whip['x'], -accel*whip['x']+speed*speed*.48))*.65
            for sub in range(4):
                step=dt/4;v+=(forcing-p*omega*omega-v*(2*.13*omega))*step;p+=v*step
            obj=whip['object']
            for axis in (0,1):
                key=obj.data.shape_keys.key_blocks[axis+1];key.value=p[axis]/.24;key.keyframe_insert('value',frame=tick+1)
            whip['cap'].location=whip['rest']+Vector((p.x,p.y,0));whip['cap'].keyframe_insert('location')
            samples.append(list(p))
        records.append({'tick':tick,'yaw':yaw,'tip_offsets':samples})
        last_yaw=yaw;last_speed=speed
    assert max(abs(v) for row in records for p in row['tip_offsets'] for v in p)<.24
    assert max(abs(v) for p in records[-1]['tip_offsets'] for v in p)<.002
    scene.frame_end=481;scene.frame_set(1)
    (api['O']/'aerial-motion-contract.json').write_text(json.dumps({'status':'PASS','drivers':['cannon discharge impulse','traverse angular acceleration','centrifugal loading'],
        'fixed_mounts':True,'traverse_review_start_tick':240,'samples':records},indent=2)+'\n')
