"""FMPL vent steam and optical heat haze on the approved Mars reactor meshes.

Steam uses the production feathered relief material, four core volumes and eight
moving veil volumes per mechanical outlet. The mesh-space emitter tables below
are also usable from ordinary Python by the Factorio sprite capture tools.
"""
from math import cos, pi, sin, sqrt
from pathlib import Path
from importlib.util import module_from_spec, spec_from_file_location

TAU = 2 * pi
ROOT = Path(__file__).resolve().parent
ROWS = {
    1: ((.310, 2.31, 1.69),),
    2: ((.245, 2.31, 1.69), (.765, 2.53, 1.83)),
    3: ((.242, 2.33, 1.67), (.755, 2.63, 1.87), (1.263, 2.81, 2.00)),
}


def _scaled(point, scale):
    return tuple(float(v * scale) for v in point)


def steam_emitters(tier, r):
    """Operating outlets in reactor-root coordinates; displacement is jet travel."""
    jets = []
    def nozzle(label, origin, travel, arc, radius, seed, duty):
        jets.append(dict(name=label, origin=_scaled(origin,r), travel=_scaled(travel,r),
                         arc=_scaled(arc,r), radius=radius*r, seed=seed, scale=r,
                         duty=duty))
    if tier == 1:
        # Adjacent operating slots issue one main stream and a thinner
        # converging feeder. Cross-draft takes the plume clear of the core.
        for slot, travel, radius, seed, duty in (
                (2,(-.32,-.095,1.01),.109,.20,.87),
                (4,(-.38,-.056,.83),.081,.71,.42)):
            x=-1.095-.49*.4+slot*.49*.8/6
            nozzle("Exchanger crown / slot %d" % (slot+1), (x,-.768,.214+.39+.039),
                   travel,(.037,-.025,-.026),radius,seed,duty)
    else:
        bays, half = (3,.335) if tier == 2 else (5,.492)
        # Exhaust load is uneven across the roof. The central bay carries most
        # of the flow. Its neighbor's jet rolls into it; the outer Maximus
        # bypass breathes on a different duty cycle.
        active=[(bays//2,(-.56,-.115,1.15),.126,.18,.86),
                (bays//2-1,(-.35,-.07,1.01),.099,.64,.52)]
        if tier==3:
            active.append((bays//2+1,(-.68,-.16,.91),.079,.87,.23))
        for bay,travel,radius,seed,duty in active:
            x=-half+(bay+.5)*2*half/bays
            sole=1.15+sqrt(1-x*x)*.987-.016+.042
            apex=(2.34 if tier==2 else 2.425)-abs(x)*(.36 if tier==2 else .52)-.033
            z=sole+(apex-sole)*.48
            # Front-facing flow first clears the front drip molding, then
            # turns upward and downwind. At the canonical camera the sustained
            # rise remains visible, even where the outlet starts end-on.
            nozzle("Vaulted exhaust / bay %d" % (bay+1), (x,-.413,z),travel,
                   (.091,-.136,-.215),radius,seed,duty)
    return jets


def heat_zones(tier, r):
    """Underlying rig ellipsoids in model-local XYZ, surrounding the real hot ribs."""
    x=(1.274,1.287,1.295)[tier-1]
    column_r=(.207,.211,.214)[tier-1]
    runs = []
    def add(name, center, axes, seed):
        runs.append(dict(name=name,center=_scaled(center,r),radii=_scaled(axes,r),
                         seed=seed,scale=r))
    for i,(y,z,top) in enumerate(ROWS[tier]):
        bottom=.57
        upper=top-.26
        add("Thermic column %d" % (i+1),(x,y,(bottom+upper)/2+.043),
            (column_r*1.30,column_r*1.30,(upper-bottom)*.67+.035),.19+i*.27)
        ranges = ([(-.24,.23)] if tier==1 else
                  [(-.33,.14)] if tier==2 and i==0 else
                  [(-.60,-.27),(.27,.60)] if i%2==0 else [(-.34,.24)])
        radius=(.096,.108,.117)[tier-1]
        for j,(a,b) in enumerate(ranges):
            add("Transfer %d / induction sleeve %d" % (i+1,j+1),
                ((a+b)/2,y,z+.045),((b-a)*.62+.018,radius*1.53,radius*1.73),
                .45+i*.18+j*.31)
    return runs


def _unit(v):
    length=sqrt(sum(x*x for x in v))
    return tuple(x/length for x in v)


def _envelope(t):
    t=min(1.0,max(0.0,t))
    return t*t*(3-2*t)


def steam_lobes(jet, frame, period=96):
    """Moving, overlapping positive-density volumes in reactor-local coordinates.

    Each ellipsoid's local Z axis follows its jet tangent. Fade is achieved by
    physical contraction at birth/death and density feathering inside each lobe.
    """
    frac=((frame-1)%period)/period
    phase=TAU*frac
    origin,travel,arc=jet['origin'],jet['travel'],jet['arc']
    seed=jet['seed']; nozzle_r=jet['radius']
    length=sqrt(sum(v*v for v in travel))
    valve=_envelope(.5+.5*sin(phase-seed*TAU+.36*sin(phase*2+seed)))
    duty=jet['duty']+(1.-jet['duty'])*valve
    pressure=.37+.69*duty
    reach=.51+.51*duty
    answer=[]
    for k in range(12):
        core=(k<4)
        # The four overlapping core volumes keep the pressure stream attached
        # to the grille. A traveling compression pulse crosses their centers,
        # while the eight outer veils advect all the way to the dissipating tip.
        if core:
            t=.075+.209*k+(.007+.0045*k)*sin(2*phase-1.43*k+seed)
            fade=1.0-.115*(k/3)**2
        else:
            start=(k*.61803398875+seed*.26)%1.0
            t=(frac*2+start)%1.0
            fade=max(.002,_envelope(t/.115)*_envelope((1.0-t)/.215))
        t*=reach
        curl=TAU*(t*1.16+seed)+k*.97
        wiggle=cos(curl+phase)*.11+sin(curl*1.43-phase)*.13
        wave=1+.18*sin(phase*2-TAU*1.6*t+seed)
        thickness=nozzle_r*(.42+1.54*sqrt(t))*wave*(1 if core else .61+.08*sin(k))
        wander=nozzle_r*(.08+.96*t)*(0 if k==0 else (0.46 if core else 1.26))
        tx=travel[0]+4*arc[0]*(1-2*t)
        ty=travel[1]+4*arc[1]*(1-2*t)
        tz=travel[2]+4*arc[2]*(1-2*t)
        axis=_unit((tx,ty,tz))
        side=_unit((axis[1],-axis[0],0))
        up=(axis[1]*side[2]-axis[2]*side[1],
            axis[2]*side[0]-axis[0]*side[2],
            axis[0]*side[1]-axis[1]*side[0])
        cross=wander*(sin(curl)+wiggle)
        cross_up=wander*.57*cos(curl*.89-phase)
        center=tuple(origin[j]+travel[j]*t+arc[j]*4*t*(1-t)
                     +cross*side[j]+cross_up*up[j] for j in range(3))
        axial=length*(.225+.066*t) if core else length*(.105+.11*t)
        if k==0:
            axial=length*.152
        radii=(thickness*pressure*fade,
               thickness*pressure*fade*(.75+.095*cos(k+phase)),
               axial*fade*(1+.09*sin(phase*2-.4*k)))
        answer.append(dict(role='core' if core else 'veil', location=center,
                           axis=axis,radii=radii,seed=k*.163+seed))
    return answer


def _fmpl():
    file=ROOT/'vendor'/'fmpl'/'fluid_steam_fx.py'
    if not file.is_file():
        raise FileNotFoundError("The pinned FMPL relief-steam shader module is required: "+str(file))
    spec=spec_from_file_location('reactor_pinned_fmpl_fluid_steam',str(file))
    module=module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _property_driver(owner, path, scene, expression):
    driver=owner.driver_add(path).driver
    driver.type='SCRIPTED'
    power=driver.variables.new()
    power.name='power'
    power.type='SINGLE_PROP'
    power.targets[0].id_type='SCENE'
    power.targets[0].id=scene
    power.targets[0].data_path='["reactor_power"]'
    driver.expression=expression


def _drive(socket, scene, expression):
    _property_driver(socket,"default_value",scene,expression)


def _unit_sphere(name,material,rings=13,segments=24):
    import bpy
    verts=[(0.,0.,-1.)]
    for a in range(1,rings):
        lat=pi*a/rings-pi/2
        verts.extend((cos(lat)*cos(TAU*i/segments),cos(lat)*sin(TAU*i/segments),sin(lat))
                     for i in range(segments))
    verts.append((0.,0.,1.))
    faces=[]
    for j in range(segments):
        n=(j+1)%segments
        faces.append((0,1+n,1+j))
        for i in range(rings-2):
            base=1+i*segments
            faces.append((base+j,base+n,base+segments+n,base+segments+j))
        base=1+(rings-2)*segments
        faces.append((base+j,base+n,len(verts)-1))
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces)
    for face in me.polygons: face.use_smooth=True
    me.materials.append(material); me.update()
    return me


def _math(nodes, op, label):
    n=nodes.new('ShaderNodeMath'); n.operation=op;n.label=label;return n


def _clock(node_tree, period, seed=0):
    """Two native fcurves trace a closed orbit in the noise field."""
    nodes=node_tree.nodes
    sn=nodes.new('ShaderNodeValue');sn.label="Thermal cycle / sine"
    cs=nodes.new('ShaderNodeValue');cs.label="Thermal cycle / cosine"
    steps=32
    for i in range(steps+1):
        angle=TAU*(seed+(i%steps)/steps)
        f=1+period*i/steps
        for n,val in ((sn,sin(angle)),(cs,cos(angle))):
            n.outputs[0].default_value=val
            n.outputs[0].keyframe_insert(data_path='default_value',frame=f)
    for curve in node_tree.animation_data.action.fcurves:
        for k in curve.keyframe_points:k.interpolation='LINEAR'
        if not curve.modifiers.get('Cycles'):curve.modifiers.new('CYCLES')
    return sn.outputs[0],cs.outputs[0]


def _steam_mat(scene,r,period,class_name):
    material=_fmpl()._feathered_steam_material().copy()
    material.name=class_name+" | FMPL operating vent steam"
    material['fmpl_source_blob']='3206a5c3d0366452c4fab13b565b6cc841d4e8d3'
    material['fmpl_fx_origin']='FMPL relief steam irregular feathered wisps v05'
    nt=material.node_tree; nodes=nt.nodes; links=nt.links
    density=next(n for n in nodes if n.name.startswith("FMPL STEAM | noise-dithered radial density"))
    vol=next(n for n in nodes if n.type=='PRINCIPLED_VOLUME')
    lift=next(n for n in nodes if n.name.startswith('FMPL STEAM | bounded core lift'))
    soft=next(n for n in nodes if n.name.startswith("FMPL STEAM | steep smooth radial feather"))
    mix=next(n for n in nodes if n.type=='MIX_SHADER')
    noise=next(n for n in nodes if n.type=='TEX_NOISE')
    noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=4.4
    # Increase the FMPL boundary's local displacement as the jet stretches.
    for n in nodes:
        if n.type=='MATH' and n.operation=='MULTIPLY' and abs(n.inputs[1].default_value-.105)<1.e-4:
            n.inputs[1].default_value=.19
    vol.inputs["Color"].default_value=(.64,.69,.71,1.)
    lift.inputs[1].default_value=.036
    sn,_=_clock(nt,period)
    links.new(sn,noise.inputs['W'])
    # Scale optical depth to maintain density under tier/world-scale changes.
    factor=nodes.new('ShaderNodeValue');factor.label='Powered pressure and optical density'
    _drive(factor.outputs[0],scene,f"power*{2.75/r:.9g}")
    optical=_math(nodes,'MULTIPLY','FMPL radial density × operating pressure')
    links.new(density.outputs['Result'],optical.inputs[0]);links.new(factor.outputs[0],optical.inputs[1])
    breakup=nodes.new('ShaderNodeMapRange');breakup.label='Turbulent pockets inside the vapor'
    breakup.clamp=True
    for n,v in [('From Min',.27),('From Max',.73),('To Min',.11),('To Max',1.27)]:breakup.inputs[n].default_value=v
    links.new(noise.outputs["Fac"],breakup.inputs['Value'])
    varied=_math(nodes,'MULTIPLY','Billow pockets');links.new(optical.outputs[0],varied.inputs[0]);links.new(breakup.outputs[0],varied.inputs[1])
    # Core density thins downstream; veil meshes contain wispy vapor. Object
    # color is only a scalar concentration, never a solid surface or a decal.
    info=nodes.new('ShaderNodeObjectInfo')
    channel=nodes.new('ShaderNodeSeparateColor');links.new(info.outputs['Color'],channel.inputs[0])
    dilution=_math(nodes,'MULTIPLY','Spatial dilution / veil concentration')
    links.new(varied.outputs[0],dilution.inputs[0]);links.new(channel.outputs[0],dilution.inputs[1])
    links.new(dilution.outputs[0],vol.inputs["Density"]);links.new(dilution.outputs[0],lift.inputs[0])
    # Very low surface density from the donor is also suppressed in the off state.
    skin=_math(nodes,'MULTIPLY','Operating valve'); links.new(soft.outputs['Result'],skin.inputs[0])
    _drive(skin.inputs[1],scene,"power");links.new(skin.outputs[0],mix.inputs[0])
    return material


def _heat_mat(scene,period,class_name,r):
    import bpy
    material=bpy.data.materials.new(class_name+" | optical hot-air boundary")
    material.use_nodes=True; material.diffuse_color=(.11,.32,.37,.03)
    material['fmpl_fx_role']='Refractive air immediately outside an induction coil'
    nt=material.node_tree;nodes=nt.nodes;nodes.clear();links=nt.links
    out=nodes.new('ShaderNodeOutputMaterial');trans=nodes.new('ShaderNodeBsdfTransparent')
    refr=nodes.new('ShaderNodeBsdfRefraction');refr.label='Weakly refracting hot air'
    refr.inputs['IOR'].default_value=1.115;refr.inputs['Roughness'].default_value=.0
    tex=nodes.new('ShaderNodeTexCoord')
    mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY'
    mapping.inputs[1].default_value=(2.45,2.45,.92)
    links.new(tex.outputs['Generated'],mapping.inputs[0])
    sn,cs=_clock(nt,period,.173)
    motion=nodes.new('ShaderNodeCombineXYZ');links.new(sn,motion.inputs['Z'])
    offset=nodes.new('ShaderNodeVectorMath');offset.operation='ADD'
    links.new(mapping.outputs[0],offset.inputs[0]);links.new(motion.outputs[0],offset.inputs[1])
    noise=nodes.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=3.1
    noise.inputs['Detail'].default_value=1.5;noise.inputs['Roughness'].default_value=.62
    links.new(offset.outputs[0],noise.inputs['Vector']);links.new(cs,noise.inputs['W'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.98;bump.inputs['Distance'].default_value=.19*r/1.65
    links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],refr.inputs['Normal'])
    facing=nodes.new('ShaderNodeLayerWeight')
    fade=nodes.new('ShaderNodeMapRange');fade.clamp=True; fade.interpolation_type='SMOOTHSTEP'
    fade.inputs['From Min'].default_value=.03;fade.inputs['From Max'].default_value=.83
    fade.inputs['To Min'].default_value=.91;fade.inputs['To Max'].default_value=0.
    links.new(facing.outputs['Facing'],fade.inputs['Value'])
    enabled=_math(nodes,'MULTIPLY','Powered shimmer');links.new(fade.outputs[0],enabled.inputs[0])
    _drive(enabled.inputs[1],scene,'power')
    rays=nodes.new('ShaderNodeLightPath'); cam=_math(nodes,'MULTIPLY','Optical view only')
    links.new(enabled.outputs[0],cam.inputs[0]);links.new(rays.outputs['Is Camera Ray'],cam.inputs[1])
    mix=nodes.new('ShaderNodeMixShader');links.new(cam.outputs[0],mix.inputs[0])
    links.new(trans.outputs[0],mix.inputs[1]);links.new(refr.outputs[0],mix.inputs[2])
    links.new(mix.outputs[0],out.inputs['Surface'])
    return material


def apply(scene, collection, tier, r, root, period=96):
    import bpy
    from mathutils import Vector
    class_name=('Minoris','Majoris','Maximus')[tier-1]
    vapor=_unit_sphere(class_name+" | FMPL vapor volume",_steam_mat(scene,r,period,class_name))
    air=_unit_sphere(class_name+" | refractive boundary",_heat_mat(scene,period,class_name,r))
    def obj(name,mesh,role):
        ob=bpy.data.objects.new(name,mesh);collection.objects.link(ob);ob.parent=root
        ob.display_type='WIRE';ob.visible_shadow=False
        ob['fmpl_reactor_fx']=role
        ob['fmpl_loop_period']=period
        # Fully transparent nested volumes still consume ray bounces in Cycles.
        # Removing the optical objects in the cold state gives a clean alpha.
        _property_driver(ob,'hide_render',scene,'power < 0.0001')
        _property_driver(ob,'hide_viewport',scene,'power < 0.0001')
        return ob
    for jet in steam_emitters(tier,r):
        lobes=[]
        for k in range(12):
            ob=obj(jet['name']+" | FMPL "+('core ' if k<4 else 'veil ')+str(k+1),vapor,'steam')
            ob['fmpl_nozzle']=jet['name'];ob['fmpl_origin_xyz']=jet['origin']
            concentration=(1.06,.87,.63,.38)[k] if k<4 else (.36+.17*(.5+.5*cos(k)))
            ob.color=(concentration,concentration,concentration,1.)
            ob['fmpl_lobe_index']=k;ob.rotation_mode='QUATERNION'
            lobes.append(ob)
        for frame in range(1,period+2):
            poses=steam_lobes(jet,frame,period)
            for ob,pose in zip(lobes,poses):
                ob.location=pose['location'];ob.scale=pose['radii']
                ob.rotation_quaternion=Vector((0,0,1)).rotation_difference(Vector(pose['axis']))
                for key in ('location','scale','rotation_quaternion'):
                    ob.keyframe_insert(data_path=key,frame=frame,group='Vapor advection')
        for ob in lobes:
            for curve in ob.animation_data.action.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
                curve.modifiers.new('CYCLES')
    for zone in heat_zones(tier,r):
        ob=obj(zone['name']+" | optical heat shimmer",air,'heat')
        ob['fmpl_thermal_zone']=zone['name'];ob['fmpl_heat_seed']=zone['seed']
        ob.location=zone['center'];ob.scale=zone['radii']
    scene.frame_set(1)
