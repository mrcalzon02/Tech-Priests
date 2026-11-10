#!/usr/bin/env python3
"""FMPL animated fluid/steam machinery fixtures. Actual Blender meshes only.

Source-safe derivative assemblies; 1 Blender unit = 1 Factorio tile. No 2D
compositing, no fake engine fluidbox ports, no unclassified external donors.
"""
from __future__ import annotations
import math

import bpy
from mathutils import Vector

FRAMES = tuple(range(1, 92, 6)) + (97,)  # 16 authored 8fps samples + exact closing pose


def _own(p, collection, label, obj, material):
    obj.name = label
    return p.rehouse(obj, collection, material)


def _orb(p, collection, label, pos, radius, material):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=radius, location=pos)
    return _own(p, collection, label, bpy.context.object, material)


def _fluid_cylinder(p, collection, label, a, b, radius, material):
    start, end = Vector(a), Vector(b)
    axis = end - start
    if axis.length < .08:
        raise ValueError("Fluid pipe must span a physical segment")
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=radius, depth=axis.length,
        location=(start + end) / 2)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis)
    return _own(p, collection, label, obj, material)


def _clear_flow(p, col, label, a, b, glass, liquid, foam):
    """Actual see-through tube, liquid core and keyed moving witness particles."""
    p.open_hollow_tube(col, label+" / transparent tube", a, b, .055, glass)
    _fluid_cylinder(p, col, label+" / moving liquid channel", a, b, .030, liquid)
    start, end = Vector(a), Vector(b)
    for k in range(2):
        t0 = .22 + .36 * k
        ob = _orb(p, col, label+" / flow tracer %02d"%k,
                  start.lerp(end, t0), .017 + .003 * k, foam)
        for frame in FRAMES:
            phase = (t0 + .82*(frame-1)/96.) % .82 + .08
            ob.location = start.lerp(end, phase)
            ob.keyframe_insert(data_path="location", frame=frame)
        ob["fmpl_fluid_role"] = "keyed witness flow inside glass tube"


def _meniscus(p, col, index, center, radius, material):
    """Real triangulated fluid surface with two animated shape-key waveforms."""
    count = 32
    levels = (radius * .30, radius * .62, radius)
    vertices = [(0., 0., 0.)]
    for r in levels:
        for k in range(count):
            ang = math.tau * k / count
            vertices.append((r * math.cos(ang), r * math.sin(ang), 0.))
    faces = [(0, 1+k, 1+(k+1)%count) for k in range(count)]
    for ring in range(1, len(levels)):
        low, high = 1+(ring-1)*count, 1+ring*count
        for k in range(count):
            nxt = (k+1)%count
            faces.append((low+k, high+k, high+nxt, low+nxt))
    mesh = bpy.data.meshes.new("FMPL WITNESS WATER | %02d"%index)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(
        p.name_of("sample station %d moving liquid meniscus"%index), mesh)
    col.objects.link(obj)
    obj.location = center
    mesh.materials.append(material)
    obj["fmpl_fluid_role"] = "reconstructed vertex slosh surface"
    obj["fmpl_candidate_not_game_approved"] = True
    obj.shape_key_add(name="Datum")
    surge = obj.shape_key_add(name="Inlet surge")
    backwash = obj.shape_key_add(name="Return wash")
    for i, (x, y, _) in enumerate(vertices):
        r = math.hypot(x, y) / radius
        angle = math.atan2(y, x)
        surge.data[i].co.z = .052 * (x/radius) + .017*r*math.sin(3*angle)
        backwash.data[i].co.z = -.050*(x/radius) + .019*r*math.sin(3*angle + 1.4)
    for frame in FRAMES:
        phase = math.tau * (frame - 1) / 96.
        surge.value = .50 - .50 * math.cos(phase)
        surge.keyframe_insert(data_path="value", frame=frame)
        backwash.value = .50 - .50 * math.cos(phase + 1.35)
        backwash.keyframe_insert(data_path="value", frame=frame)
    return obj


def _bubbles(p, col, index, x, y, material):
    objects = []
    for k in range(12):
        angle = math.tau*k/12 + .17*index
        # Let the chamber's near-inner wall act as a physical observation face.
        # The bubble stays in the modeled fluid, not behind its opaque volume.
        r = .066 + .016*(k%3)
        dx = r*math.cos(angle)
        dy = -math.sqrt(max(.001, .148**2-dx**2)) + .012
        base = .800 + .036*(k%6)
        ob = _orb(p, col, "sample station %d liquid bubble %02d"%(index,k),
                  (x+dx, y+dy, base),
                  .027 + .004*(k%3), material)
        for frame in FRAMES:
            # Bounded, individually phase-shifted 16-sample rise with exact seam.
            phase = math.tau * (frame - 1)/96.
            dz = .050 + .050*math.sin(phase + .41*k)
            ob.location.z = base + dz*(.78+.055*(k%4))
            ob.keyframe_insert(data_path="location", index=2, frame=frame)
        ob["fmpl_fluid_role"] = "rising process bubble in transparent fluid"
        objects.append(ob)
    return objects


def _foam_crest(p, col, idx, x, y, z, material):
    """Front-side physical waterline foam. It follows keyed slosh, not a decal."""
    count=20
    verts=[]
    faces=[]
    radius=.181  # enlarged front liquid column meniscus, previous .151
    for k in range(count+1):
        angle=math.pi * k/count
        # Front semicircle sits just inside the glass, on the actual waterline.
        dx=radius*math.cos(angle)
        dy=-radius*math.sin(angle)
        verts.extend(((dx,dy,-.015),(dx,dy,.015)))
        if k:
            a=2*(k-1)
            b=2*k
            faces.append((a,b,b+1,a+1))
    mesh=bpy.data.meshes.new("FMPL fluid | witness crest %02d"%idx)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(
        p.name_of("sample station %d animated waterline foam crest"%idx),mesh)
    col.objects.link(obj)
    obj.location=(x,y,z)
    obj.data.materials.append(material)
    obj["fmpl_fluid_role"]="keyed foam crest following slosh at real transparent tank wall"
    obj["fmpl_candidate_not_game_approved"]=True
    for frame in FRAMES:
        phase=math.tau*(frame-1)/96.
        obj.location.z=z+.065*math.sin(phase)
        obj.rotation_euler.y=.17*math.sin(phase+.6)
        obj.keyframe_insert(data_path="location",frame=frame)
        obj.keyframe_insert(data_path="rotation_euler",frame=frame)
    return obj


def _watertone_copy(source, name, rgb, transmission, light):
    """Derive a real per-machine material, keeping the canonical FX asset intact."""
    mat=source.copy()
    mat.name=name
    if getattr(mat,"asset_data",None) is not None:
        mat.asset_clear()
    if "fmpl_effect_id" in mat:
        del mat["fmpl_effect_id"]
    mat["fmpl_machine_derivative_of"]=source.name
    mat["fmpl_water_colorway"]="RAW warm olive amber" if "raw" in name else "CLEAN cyan blue"
    mat["fmpl_not_canonical_fx_asset"]=True
    mat.diffuse_color=(*rgb,1.)
    if not mat.use_nodes:
        raise RuntimeError("FMPL liquid source has no procedural PBR nodes")
    surface=mat.node_tree.nodes.get("FMPL | Surface")
    ramp=mat.node_tree.nodes.get("FMPL | Broken Albedo")
    if surface is None or ramp is None:
        raise RuntimeError("FMPL FX water source does not have approved broken-albedo graph")
    surface.inputs["Transmission Weight"].default_value=transmission
    surface.inputs["Base Color"].default_value=(*rgb,1.)
    surface.inputs["Emission Color"].default_value=(*rgb,1.)
    surface.inputs["Emission Strength"].default_value=light
    ramp.color_ramp.elements[0].color=tuple(max(0.,min(1.,v*.73)) for v in rgb)+(1.,)
    ramp.color_ramp.elements[1].color=tuple(max(0.,min(1.,v*1.15)) for v in rgb)+(1.,)
    return mat


def _foam_color_copy(source, name, rgb):
    mat=source.copy()
    mat.name=name
    mat.diffuse_color=(*rgb,.95)
    mat["fmpl_water_colorway"]="raw" if "raw" in name else "clean"
    mat["fmpl_machine_derivative_of"]=source.name
    if not mat.use_nodes:
        raise RuntimeError("Original FMPL foam shader is absent")
    principled=mat.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Original FMPL foam has no visible Principled BSDF")
    principled.inputs["Base Color"].default_value=(*rgb,1.)
    if principled.inputs.get("Alpha") is not None:
        principled.inputs["Alpha"].default_value=.90
    return mat


def _witness_palette(mats):
    return {
        "raw":_watertone_copy(
            mats["fx_raw"],"FMPL | purifier raw-water olive-amber V11",
            (.48,.275,.047),.22,0.),
        "clean":_watertone_copy(
            mats["fx_clear"],"FMPL | purifier clean-water luminous cyan V11",
            (.035,.58,.92),.45,.15),
        "raw_foam":_foam_color_copy(
            mats["foam"],"FMPL | purifier raw olive-ochre foam V11",
            (.77,.53,.17)),
        "clean_foam":_foam_color_copy(
            mats["foam"],"FMPL | purifier clean cyan-white foam V11",
            (.43,.94,1.0)),
    }


def build_witness_canisters(col, p, mats):
    """Physically larger front RAW and CLEAN canisters with inlet/exit flow."""
    glass, iron, brass, steel = (
        mats.get("fx_glass", mats["glass"]), mats["iron"], mats["brass"], mats["steel"])
    dark=mats["gunmetal"]
    palette=_witness_palette(mats)
    specs = (
        (1,-.17,palette["raw"],palette["raw_foam"]),
        (2, .53,palette["clean"],palette["clean_foam"]),
    )
    out = {"vessels": 0, "moving_surfaces": 0, "visible_foam_crests": 0,
           "liquid_bubbles": 0, "flow_tracers": 0, "glass_flows": 0,
           "vessel_outer_diameter_tiles":.426,
           "vessel_height_tiles":.712,
           "vessel_centers_x_tiles":[-.17,.53],
           "color_material_ids":{k:v.name for k,v in palette.items()}}
    for idx, x, liquid, bubble_color in specs:
        y = -1.242
        p.block(col, "sample station %d foundation shoe"%idx,
                (x,y+.04,.53), (.48,.26,.18), dark, .014)
        # Open-ended physical glass wall; preserve a pressure observation lid.
        # An opaque cylinder or iron cap would block the moving water entirely.
        vessel=p.open_hollow_tube(col,"sample station %d enlarged transparent vessel"%idx,
            (x,y,.645),(x,y,1.357),.213,glass)
        vessel["fmpl_witness_tank_outer_diameter_tiles"]=.426
        vessel["fmpl_witness_tank_body_height_tiles"]=.712
        vessel["fmpl_witness_tank_role"]="RAW" if idx==1 else "CLEAN"
        p.cyl(col,"sample station %d enlarged visible liquid column"%idx,
              (x,y,.935), .190, .552, liquid)
        for height in (.651, 1.352):
            p.torus(col,"sample station %d pressure retainer %.3f"%(idx,height),
                    (x,y,height),.226,.018,brass)
        for side in (-1,1):
            p.cyl(col,"sample station %d front sight support %d"%(idx,side),
                  (x+side*.193,y-.073,1.0),.013,.70,steel,vertices=12)
        p.cyl(col,"sample station %d transparent pressure observation lid"%idx,
              (x,y,1.36),.202,.020,glass)
        _meniscus(p,col,idx,(x,y,1.225),.188,liquid)
        _foam_crest(p,col,idx,x,y,1.225,bubble_color)
        out["liquid_bubbles"] += len(_bubbles(p,col,idx,x,y,bubble_color))
        out["vessels"] += 1
        out["moving_surfaces"] += 1
        out["visible_foam_crests"] += 1
    # These are visible witness/sample branches connecting the EXISTING pump,
    # filter and discharge routes: they do not change the two engine fluidbox
    # openings at X+/-1.5 Y0 Z.36.
    channels = (
        ("raw-canister inlet",(-.74,-1.11,1.19),(-.383,-1.242,1.19),palette["raw"],palette["raw_foam"]),
        ("raw-canister outlet",(-.383,-1.242,.79),(-.75,-1.09,.79),palette["raw"],palette["raw_foam"]),
        ("clean-canister inlet",(.84,-1.08,1.19),(.743,-1.242,1.19),palette["clean"],palette["clean_foam"]),
        ("clean-canister outlet",(.743,-1.242,.79),(.84,-1.05,.79),palette["clean"],palette["clean_foam"]),
    )
    for label, start, end, liquid, witness_foam in channels:
        _clear_flow(p,col,label,start,end,glass,liquid,witness_foam)
        out["glass_flows"] += 1
        out["flow_tracers"] += 2
    p.pipe_route(col,"raw witness feed from pump",
                 [(-1.12,-.79,.61),(-.98,-1.01,.98),(-.74,-1.11,1.19)],
                 .037,iron,brass)
    p.pipe_route(col,"raw witness return to first filter",
                 [(-.75,-1.09,.79),(-.82,-1.05,.72),(-.92,-1.00,.67)],
                 .037,steel,iron)
    p.pipe_route(col,"clean witness feed from treatment outlet",
                 [(.69,-.18,.79),(.84,-.85,1.03),(.84,-1.08,1.19)],
                 .037,steel,iron)
    p.pipe_route(col,"clean witness return to discharge casting",
                 [(.84,-1.05,.79),(.92,-.88,.72),(.88,-.18,.66)],
                 .037,steel,brass)
    for label, _, near, _, _ in channels:
        p.torus(col,label+" / seated vessel connector gland",
                near,.060,.013,brass,axis="X")
    return out


def add_relief_nozzle(col, p, mats):
    """Replace an opaque cap with a visible, actually hollow vertical exhaust.

    The verified V04 source has a solid cylindrical nozzle near (.94,.60,2.80).
    Never modify its mesh; the caller hides only that source object's render.
    These new machine-side pieces sit exactly on the existing relief pipe end.
    """
    center=(.94,.60)
    steel=mats["steel"]
    iron=mats["iron"]
    brass=mats["brass"]
    throat=p.open_hollow_tube(
        col,"relief vent emitter / open steel throat",
        (center[0],center[1],2.760),
        (center[0],center[1],2.913),
        .118,steel,bore_ratio=.66)
    throat["fmpl_nozzle_role"]="open, actually hollow steam outlet"
    throat["fmpl_nozzle_bore_diameter_tiles"]=round(2*.118*.66,5)
    throat["fmpl_nozzle_lip_plane_z"]=2.913
    p.torus(col,"relief vent emitter / seated root ferrule",
            (center[0],center[1],2.785),.123,.018,iron)
    p.torus(col,"relief vent emitter / visible open mouth retaining lip",
            (center[0],center[1],2.910),.124,.014,brass)
    return {
        "emitter_center_xyz":[.94,.60,2.913],
        "outer_diameter_tiles":.236,
        "inner_bore_diameter_tiles":round(2*.118*.66,5),
        "mating_pipe_top_z":2.77,
        "source_solid_cap_preserved":True,
        "visible_open_throat":True,
        "rendered_mesh_parts":3
    }


def _feathered_steam_material():
    """True lightweight volumetric steam inside real Blender sphere meshes.

    Procedural local-space dither and smooth radial density suppress surface
    rims and silhouetted facets. No billboard cards or simulation/cache baking.
    """
    name="FMPL | relief steam irregular feathered wisps v05"
    existing=bpy.data.materials.get(name)
    if existing:
        return existing
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    mat.diffuse_color=(.86,.91,.93,.045)
    mat["fmpl_fx_role"]="physically nozzle-anchored 3D variable-density steam volume"
    mat["fmpl_fx_source"]="FMPL steam-clean; expanded low-contrast scattered true volume with bounded density-aware lift"
    mat["fmpl_fx_not_game_approved"]=True
    if hasattr(mat,"surface_render_method"):
        try:
            mat.surface_render_method="DITHERED"
        except (TypeError,ValueError):
            pass
    nodes=mat.node_tree.nodes
    nodes.clear()
    links=mat.node_tree.links
    output=nodes.new("ShaderNodeOutputMaterial")
    output.name="FMPL STEAM | surface output"
    transparent=nodes.new("ShaderNodeBsdfTransparent")
    transparent.name="FMPL STEAM | transparent exterior"
    surface=nodes.new("ShaderNodeBsdfPrincipled")
    surface.name="FMPL STEAM | pale vapor surface"
    surface.inputs["Base Color"].default_value=(.89,.92,.94,1.)
    surface.inputs["Roughness"].default_value=.94
    mix=nodes.new("ShaderNodeMixShader")
    mix.name="FMPL STEAM | radial-dither alpha mix"
    links.new(transparent.outputs["BSDF"],mix.inputs[1])
    links.new(surface.outputs["BSDF"],mix.inputs[2])
    links.new(mix.outputs["Shader"],output.inputs["Surface"])
    coords=nodes.new("ShaderNodeTexCoord")
    coords.name="FMPL STEAM | mesh-generated coords"
    distance=nodes.new("ShaderNodeVectorMath")
    distance.name="FMPL STEAM | actual sphere radial distance"
    distance.operation="DISTANCE"
    distance.inputs[1].default_value=(.5,.5,.5)
    links.new(coords.outputs["Generated"],distance.inputs[0])
    noise=nodes.new("ShaderNodeTexNoise")
    noise.name="FMPL STEAM | multi-surface dither breakup"
    noise.inputs["Scale"].default_value=15.0
    noise.inputs["Detail"].default_value=3.2
    noise.inputs["Roughness"].default_value=.67
    links.new(coords.outputs["Generated"],noise.inputs["Vector"])
    offset=nodes.new("ShaderNodeMath")
    offset.operation="SUBTRACT"
    offset.inputs[1].default_value=.5
    links.new(noise.outputs["Fac"],offset.inputs[0])
    jitter=nodes.new("ShaderNodeMath")
    jitter.operation="MULTIPLY"
    jitter.inputs[1].default_value=.105
    links.new(offset.outputs[0],jitter.inputs[0])
    perturbed=nodes.new("ShaderNodeMath")
    perturbed.operation="ADD"
    links.new(distance.outputs["Value"],perturbed.inputs[0])
    links.new(jitter.outputs[0],perturbed.inputs[1])
    feather=nodes.new("ShaderNodeMapRange")
    feather.name="FMPL STEAM | steep smooth radial feather"
    feather.clamp=True
    feather.interpolation_type="SMOOTHSTEP"
    feather.inputs["From Min"].default_value=.14
    feather.inputs["From Max"].default_value=.49
    feather.inputs["To Min"].default_value=.021
    feather.inputs["To Max"].default_value=0.0
    links.new(perturbed.outputs[0],feather.inputs["Value"])
    links.new(feather.outputs["Result"],mix.inputs[0])
    volume=nodes.new("ShaderNodeVolumePrincipled")
    volume.name="FMPL STEAM | true variable density volume"
    volume.inputs["Color"].default_value=(.89,.93,.96,1.)
    volume.inputs["Anisotropy"].default_value=.20
    density=nodes.new("ShaderNodeMapRange")
    density.name="FMPL STEAM | noise-dithered radial density"
    density.clamp=True
    density.interpolation_type="SMOOTHSTEP"
    density.inputs["From Min"].default_value=.095
    density.inputs["From Max"].default_value=.51
    density.inputs["To Min"].default_value=3.10
    density.inputs["To Max"].default_value=0.
    links.new(perturbed.outputs[0],density.inputs["Value"])
    links.new(density.outputs["Result"],volume.inputs["Density"])
    # The first true-volume proof was nearly invisible because the top relief
    # receives little scene illumination. A restrained density-coupled emission
    # makes real scattering vapor readable against industrial dark backgrounds.
    # It necessarily decays to ZERO with radial density at every sphere edge.
    lift=nodes.new("ShaderNodeMath")
    lift.name="FMPL STEAM | bounded core lift linked to density"
    lift.operation="MULTIPLY"
    lift.inputs[1].default_value=.112
    links.new(density.outputs["Result"],lift.inputs[0])
    if volume.inputs.get("Emission Strength") is None or volume.inputs.get("Emission Color") is None:
        raise RuntimeError("Native Blender volume node is missing emissive fog sockets")
    volume.inputs["Emission Color"].default_value=(.78,.87,.92,1.)
    links.new(lift.outputs[0],volume.inputs["Emission Strength"])
    links.new(volume.outputs["Volume"],output.inputs["Volume"])
    return mat


def add_relief_steam(col,p,mats):
    """Layered small steam wisps at the true relief nozzle; no cones or hard rims.

    Four core lobes retain the original QA identity, eight thin secondary lobes
    break the surface silhouette. All meshes are editable, softly shader-faded,
    and keyframed in closed 16-sample loops (frame 1 == frame 97).
    """
    if mats.get("fx_steam") is None:
        raise RuntimeError("Pinned FMPL native steam-clean material is missing")
    soft=_feathered_steam_material()
    origin=(.94,.60,2.80)
    # Four overlapping core lobes, eight asymmetric drifting wisps. Explicit
    # measured origins break the previous perfectly stacked conical silhouette.
    # The first two cores intersect the open lip, and every later lobe
    # overlaps another; these are not disconnected decorative clouds.
    wisps=(
        (.000,.000,2.949,.125),(.015,-.012,3.016,.130),
        (-.048,.024,3.087,.116),(-.080,.040,3.164,.083),
        (.039,-.029,2.969,.088),(-.028,.036,3.017,.086),
        (.063,.010,3.052,.079),(-.061,-.014,3.103,.090),
        (-.099,.037,3.147,.072),(.045,.046,3.172,.075),
        (-.047,.059,3.207,.070),(-.079,-.016,3.068,.068)
    )
    for k,(dx,dy,z0,radius) in enumerate(wisps):
        primary=k<4
        x0=.94+dx
        y0=.60+dy
        name=("relief nozzle keyed condensed steam %02d"%k if primary
              else "steam veil layered feather %02d"%(k-4))
        # More geometric samples allow soft volumes without octagonal corners;
        # they remain actual editable meshes, not sprites or textured planes.
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=24,ring_count=16,radius=radius,
            location=(x0,y0,z0))
        ob=_own(p,col,name,bpy.context.object,soft)
        for face in ob.data.polygons:
            face.use_smooth=True
        for frame in FRAMES:
            phase=math.tau*(frame-1)/96.
            swell=.92+.10*math.sin(phase+.41*k)
            ob.scale=(.93*swell,.80*swell,(1.28+.04*(k%3))*swell)
            ob.location=(x0+.018*math.sin(phase+.53*k),
                         y0+.013*math.cos(phase+.39*k),
                         z0+.030*math.sin(phase+.61*k))
            ob.keyframe_insert(data_path="scale",frame=frame)
            ob.keyframe_insert(data_path="location",frame=frame)
        ob["fmpl_fx_origin"]="open relief nozzle lip (.94,.60,2.913)"
        ob["fmpl_fx_surface"]="irregular lobe geometry, radial noise density, sparse density-coupled visibility"
        ob["fmpl_fx_mesh_role"]="core" if primary else "silhouette feather veil"
    return {
        "relief_steam_puffs":4,
        "soft_surface_lobes":12,
        "emission_coupled_to_density":True,
        "density_lift_multiplication":.112,
        "secondary_feather_veils":8,
        "soft_edge_shader":soft.name,
        "true_volumetric_density":True,
        "hard_surface_opacity_at_core":0.021,
        "root_nozzle_xyz":list(origin),
        "physical_emitter_lip_z":2.913,
        "volume_density_core":3.10,
        "animation_samples":len(FRAMES),
        "legacy_cone_geometry_preserved":True
    }
