#!/usr/bin/env python3
"""V13 Water Purifier: heavy slow stirrer, real moving water, readable console.

Source integrity: immutable 50 MH7 meshes and 136 original process meshes.
No fake simulation, no new camera, no changes to canonical fluid pipe mouths.
"""
from __future__ import annotations
import math
import bpy
from mathutils import Matrix, Vector

SAMPLE_FRAMES=tuple(range(1,92,6))+(97,)
TANK_CENTER=(0.,.1)
SURFACE_Z=2.254
ORIGINAL_ROTATION_RAD=math.tau
NEW_ROTATION_RAD=math.pi/2
CRT_YAW_DEG=12.
CRT_MOVE=(.19,-.045,0.)


def _named(p,col,label,ob,mat):
    ob.name=p.name_of(label)
    p.rehouse(ob,col,mat)
    return ob


def _sphere(p,col,label,location,radius,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,ring_count=10,radius=radius,location=location)
    ob=_named(p,col,label,bpy.context.object,mat)
    for poly in ob.data.polygons:
        poly.use_smooth=True
    return ob


def _material(source,name,color,transmission=0.,emission=.0):
    mat=source.copy()
    mat.name=name
    mat.diffuse_color=(*color,1.)
    if getattr(mat,"asset_data",None) is not None:
        mat.asset_clear()
    mat["fmpl_process_derivative_only"]=True
    if "fmpl_effect_id" in mat:
        del mat["fmpl_effect_id"]
    mat["fmpl_source_material"]=source.name
    if mat.use_nodes:
        princ=mat.node_tree.nodes.get("Principled BSDF")
        if princ is not None:
            princ.inputs["Base Color"].default_value=(*color,1.)
            if princ.inputs.get("Transmission Weight") is not None:
                princ.inputs["Transmission Weight"].default_value=transmission
            if princ.inputs.get("Emission Color") is not None:
                princ.inputs["Emission Color"].default_value=(*color,1.)
            if princ.inputs.get("Emission Strength") is not None:
                princ.inputs["Emission Strength"].default_value=emission
    return mat


def slow_agitator(scene,process,p):
    name=p.name_of("keyframed central agitator rotor")
    rotor=bpy.data.objects.get(name)
    if rotor is None or rotor.type!="EMPTY":
        raise RuntimeError("Verified V04 agitator empty missing")
    if rotor.animation_data is None or rotor.animation_data.action is None:
        raise RuntimeError("Verified V04 agitator source keys missing")
    scene.frame_set(1)
    first=float(rotor.rotation_euler.z)
    scene.frame_set(97)
    last=float(rotor.rotation_euler.z)
    if abs((last-first)-ORIGINAL_ROTATION_RAD)>.03:
        raise RuntimeError("Cannot safely replace unrecognized original mixer speed")
    old_action=rotor.animation_data.action
    old_action.use_fake_user=True
    rotor.animation_data.action=old_action.copy()
    rotor.animation_data.action.name="FMPL | Water Purifier slow quarter-turn V13"
    # Four equal paddles at each of two levels are visually 90-degree
    # symmetric. One quarter-turn over 96 frames = 25% prior speed and a
    # seamless physical-image loop despite a different numeric Euler angle.
    for frame in SAMPLE_FRAMES:
        angle=NEW_ROTATION_RAD*(frame-1)/96.
        rotor.rotation_euler.z=angle
        rotor.keyframe_insert(data_path="rotation_euler",index=2,frame=frame)
    rotor["fmpl_v13_rate_ratio_vs_v12"]=.25
    rotor["fmpl_v13_fourfold_visual_loop"]=True
    rotor["fmpl_v13_loop_frame"]=97
    scene.frame_set(1)
    return {
        "source_turn_radians":ORIGINAL_ROTATION_RAD,
        "derivative_turn_radians":NEW_ROTATION_RAD,
        "rate_ratio":.25,
        "loop_visual_symmetry":4,
        "keyed_samples":len(SAMPLE_FRAMES),
        "source_action_preserved":old_action.name,
        "mixer_name":rotor.name,
    }


def _water_surface(p,col,mat):
    """Real annular water top with rotating/asymmetric wave shape keys."""
    rings=(.085,.17,.25,.34,.44,.53,.625)
    divisions=64
    verts=[]
    faces=[]
    for i,r in enumerate(rings):
        for j in range(divisions):
            theta=math.tau*j/divisions
            base=-.013*(1-r/.625)+.006*math.cos(2*theta)
            verts.append((r*math.cos(theta),r*math.sin(theta),base))
    for row in range(len(rings)-1):
        for j in range(divisions):
            nxt=(j+1)%divisions
            a=row*divisions+j
            b=(row+1)*divisions+j
            faces.append((a,b,(row+1)*divisions+nxt,row*divisions+nxt))
    mesh=bpy.data.meshes.new("FMPL | Central animated churning water surface V13")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    ob=bpy.data.objects.new(p.name_of("central real animated agitator liquid top"),mesh)
    col.objects.link(ob)
    ob.location=(0,.1,SURFACE_Z)
    ob.data.materials.append(mat)
    ob["fmpl_central_agitation_role"]="actual top-water mesh, four cyclic shape-key wave modes"
    ob.shape_key_add(name="Calm baseline")
    keys=[ob.shape_key_add(name=label) for label in (
        "Clockwise paddle swirl","Return pressure surge",
        "Agitator chopping wakes","Outer tank shoulder lift"
    )]
    for i,(x,y,z) in enumerate(verts):
        rr=math.hypot(x,y)
        a=math.atan2(y,x)
        keys[0].data[i].co.z=z+.038*math.sin(4*a+rr*7)
        keys[1].data[i].co.z=z+.035*math.sin(4*a+rr*7+math.pi/2)
        keys[2].data[i].co.z=z+.021*math.cos(8*a+rr*3)
        keys[3].data[i].co.z=z+.028*(rr/.625)**2
    for frame in SAMPLE_FRAMES:
        phase=math.tau*(frame-1)/96.
        values=(.5+.5*math.sin(phase),
                .5+.5*math.cos(phase),
                .5+.5*math.sin(2*phase+.6),
                .5+.4*math.cos(phase+.8))
        for key,v in zip(keys,values):
            key.value=v
            key.keyframe_insert(data_path="value",frame=frame)
    return ob


def _swirl_ribbon(p,col,mat,index):
    """Four individually editable, camera-visible churning water stripes."""
    base_angle=index*math.pi/2
    subdivisions=24
    mesh_verts=[]
    faces=[]
    for j in range(subdivisions+1):
        t=j/subdivisions
        radius=.30+.25*t
        angle=base_angle+.20+1.10*t
        x=radius*math.cos(angle)
        y=radius*math.sin(angle)
        breadth=.028*(.65+.35*math.sin(math.pi*t))
        normal=Vector((-math.sin(angle),math.cos(angle)))
        for sign in (-1.,1.):
            mesh_verts.append((x+sign*normal.x*breadth,
                              y+sign*normal.y*breadth,
                              .008+.006*math.sin(t*math.tau)))
        if j:
            prev=2*(j-1)
            cur=2*j
            faces.append((prev,cur,cur+1,prev+1))
    mesh=bpy.data.meshes.new("FMPL central visible swirl ribbon %02d"%index)
    mesh.from_pydata(mesh_verts,[],faces)
    mesh.update()
    ob=bpy.data.objects.new(
        p.name_of("central stirring current ribbon %02d"%index),mesh)
    col.objects.link(ob)
    ob.location=(0.,.1,SURFACE_Z+.015)
    ob.data.materials.append(mat)
    ob["fmpl_central_agitation_role"]="visible actual swirling fluid ribbon"
    return ob


def build_agitation(scene,col,p,mats):
    source=mats["teal"]
    foam_source=mats["foam"]
    surface_mat=_material(source,"FMPL | central churned water V13",
                          (.065,.36,.40),transmission=.28)
    tracer_mat=_material(foam_source,"FMPL | central pale-turquoise swirl wake V13",
                          (.57,.93,.91),emission=.16)
    froth_mat=_material(foam_source,"FMPL | central broken foam V13",
                         (.87,.96,.86),emission=.15)
    bubble_mat=_material(foam_source,"FMPL | central recirculating aeration V13",
                         (.80,.95,.89),emission=.12)
    water=_water_surface(p,col,surface_mat)
    ribbons=[_swirl_ribbon(p,col,tracer_mat,k) for k in range(4)]
    # The ribbon group makes one quarter-turn, matching the fourfold
    # symmetry of the heavy mixer while fluid bubbles can complete an orbit.
    ribbon_root=bpy.data.objects.new(
        p.name_of("central visible spiral flow rig"),None)
    col.objects.link(ribbon_root)
    ribbon_root.location=(0.,.1,SURFACE_Z+.015)
    p.parent_to_rotor(ribbons,ribbon_root)
    for frame in SAMPLE_FRAMES:
        ribbon_root.rotation_euler.z=math.pi/2*(frame-1)/96.
        ribbon_root.keyframe_insert(
            data_path="rotation_euler",index=2,frame=frame)
    bubbles=[]
    for k in range(24):
        radius=.32+.033*(k%7)
        phase0=math.tau*k/24
        z0=2.158+.028*(k%4)
        xyz=(radius*math.cos(phase0),.1+radius*math.sin(phase0),z0)
        ob=_sphere(p,col,"central recirculating bubble %02d"%k,xyz,
                   .016+.003*(k%3),bubble_mat)
        for frame in SAMPLE_FRAMES:
            phase=math.tau*(frame-1)/96.
            angle=phase0+phase
            rr=radius+.018*math.sin(phase+.4*k)
            ob.location=(rr*math.cos(angle),
                         .1+rr*math.sin(angle),
                         z0+.032*math.sin(phase+.51*k))
            ob.keyframe_insert(data_path="location",frame=frame)
        bubbles.append(ob)
    froth=[]
    for k in range(24):
        angle=math.tau*k/24
        radius=.55+.019*math.sin(k*1.31)
        ob=_sphere(p,col,"central floating foam clump %02d"%k,
                   (radius*math.cos(angle),.1+radius*math.sin(angle),
                    SURFACE_Z+.033),
                   .019+.006*(k%3),froth_mat)
        for frame in SAMPLE_FRAMES:
            phase=math.tau*(frame-1)/96.
            a=angle+.26*math.sin(phase+.11*k)
            rr=radius+.016*math.sin(phase+.47*k)
            ob.location=(rr*math.cos(a),.1+rr*math.sin(a),
                         SURFACE_Z+.033+.015*math.cos(phase+.32*k))
            ob.keyframe_insert(data_path="location",frame=frame)
        froth.append(ob)
    # Uneven foam patches around the real paddle path. Do not coat the entire
    # vessel in a perfectly smooth white donut.
    patches=[]
    for k in range(12):
        angle=math.tau*k/12
        radius=.33+.075*(k%3)/2
        ob=_sphere(p,col,"central impeller turbulence froth %02d"%k,
                   (radius*math.cos(angle),.1+radius*math.sin(angle),
                    SURFACE_Z+.035),.023+.004*(k%3),froth_mat)
        for frame in SAMPLE_FRAMES:
            phase=math.tau*(frame-1)/96.
            a=angle+.38*math.sin(phase+.36*k)
            ob.location=(radius*math.cos(a),.1+radius*math.sin(a),
                         SURFACE_Z+.035+.023*math.sin(phase+.31*k))
            ob.keyframe_insert(data_path="location",frame=frame)
        patches.append(ob)
    return {
        "surface_meshes":1,"surface_shape_keys":4,
        "visible_current_ribbons":len(ribbons),
        "suspended_orbiting_bubbles":len(bubbles),
        "outer_waterline_foam_clumps":len(froth),
        "paddle_path_foam_patches":len(patches),
        "animation_samples":len(SAMPLE_FRAMES),
        "waterline_z":SURFACE_Z,
        "center_xy":list(TANK_CENTER),
        "source_water_surface_preserved":True,
        "native_factorio_game_integrated":False,
    }


def relocate_console(scene,col,p,original,mats):
    """Source-safe CRT and animated readout rerouted around right witness tank."""
    names=[
        "MH7_service inset CRT",
        "MH7_service interface casting",
        "MH7_control push button",
        "MH7_control push button.001",
        "MH7_control push button.002",
        "MH7_control push button.003",
    ]
    originals=[]
    for name in names:
        matches=[o for o in original if o.name==name]
        if len(matches)!=1 or matches[0].hide_render:
            raise RuntimeError("Expected one visible historic CRT component: "+name)
        originals.extend(matches)
    yaw=math.radians(CRT_YAW_DEG)
    pivot=(1.12,-1.18,0.)
    transform=(
        Matrix.Translation(Vector(CRT_MOVE)) @
        Matrix.Translation(Vector(pivot)) @
        Matrix.Rotation(yaw,4,'Z') @
        Matrix.Translation(Vector((-pivot[0],-pivot[1],0.)))
    )
    clones=[]
    for src in originals:
        world=src.matrix_world.copy()
        src.hide_render=True
        src["fmpl_derived_console"]="immutable original, hidden for angled V13 replacement"
        new=src.copy()
        new.data=src.data.copy()
        new.name=p.name_of("angled service console / "+src.name.removeprefix("MH7_"))
        col.objects.link(new)
        new.hide_render=False
        new.hide_viewport=False
        # Trim only the oversized backing, not the CRT face or old switches.
        # Retain the right-hand controls while clearing the cyan sample tank.
        trim=Matrix.Identity(4)
        if src.name=="MH7_service interface casting":
            trim=(Matrix.Translation(Vector((.11,0,0))) @
                  Matrix.Diagonal(Vector((.70,.74,1.,1.))))
        new.matrix_world=transform @ world @ trim
        new["fmpl_console_role"]="actual source mesh, yawed and shifted out from tank"
        new["fmpl_console_yaw_degrees"]=CRT_YAW_DEG
        new["fmpl_console_source"]=src.name
        clones.append(new)
    led=_material(mats["teal"],"FMPL | live green CRT level bars V13",
                  (.055,.87,.14),transmission=0.,emission=1.15)
    bars=[]
    for i in range(5):
        x=.618+i*.072
        # Original CRT plane normal faces the viewer at original Y-1.325.
        ob=p.block(col,"angled CRT live green readout bar %02d"%i,
                   (x,-1.346,.959),(.027,.012,.118),led,.003)
        ob.matrix_world=transform @ ob.matrix_world
        for frame in SAMPLE_FRAMES:
            phase=math.tau*(frame-1)/96.
            amp=.49+.43*math.sin(phase+.77*i)**2
            ob.scale.z=amp
            ob.keyframe_insert(data_path="scale",index=2,frame=frame)
        ob["fmpl_console_role"]="real keyed diagnostic line bars proud of the sample tank"
        bars.append(ob)
    return {
        "original_source_crt_meshes_preserved":len(originals),
        "derived_crt_meshes":len(clones),
        "animated_readout_bars":len(bars),
        "console_yaw_deg":CRT_YAW_DEG,
        "console_move_xyz":list(CRT_MOVE),
        "screen_original":"MH7_service inset CRT",
        "screen_clone":clones[0].name,
        "source_screen_animation_preserved":True,
        "front_right_clean_tank_center_x":.53,
        "native_mesh_construction_only":True,
    }


def build(scene,col,p,original,process,mats):
    slow=slow_agitator(scene,process,p)
    fluid=build_agitation(scene,col,p,mats)
    console=relocate_console(scene,col,p,original,mats)
    return {"slowed_mixer":slow,"central_water":fluid,
            "angled_green_console":console}
