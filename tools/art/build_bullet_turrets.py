"""Author the quad burst gun and twin rotary gun; never include the bunker.

Blender --factory-startup -b --python THIS -- CAMERA_MATERIAL_SOURCE OUTPUT
Metres / tiles, Z up, forward -Y, common traverse socket (0,0,1.70).
"""
import bpy, math, json, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix
source, output=map(Path,sys.argv[sys.argv.index('--')+1:])
output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
S=bpy.context.scene
keep={o for o in S.objects if o.type in ('CAMERA','LIGHT')}
for o in keep:
    mw=o.matrix_world.copy();o.parent=None;o.matrix_world=mw;o.animation_data_clear();o.data.animation_data_clear()
for o in list(S.objects):
    if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
for layer in list(S.view_layers)[1:]:S.view_layers.remove(layer)
def enable(layer):
    layer.exclude=False;layer.hide_viewport=False
    for child in layer.children:enable(child)
enable(S.view_layers[0].layer_collection)
for collection in bpy.data.collections:collection.hide_render=False
S.use_nodes=False;S.render.use_compositing=False;S.render.use_sequencer=False
S.render.engine='CYCLES';S.cycles.samples=16;S.cycles.use_denoising=True
S.render.threads_mode='FIXED';S.render.threads=4
try:
    preferences=bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type='OPTIX';preferences.get_devices()
    for device in preferences.devices:device.use=device.type=='OPTIX'
    if any(d.type=='OPTIX' for d in preferences.devices):S.cycles.device='GPU'
except Exception:S.cycles.device='CPU'
S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA'
S.render.resolution_x=S.render.resolution_y=768;S.render.resolution_percentage=100
S.render.fps=60
original_mats={
 'red':next(m for m in bpy.data.materials if m.name.endswith('committed oxide red') and m.name.startswith('DISH_V03')),
 'steel':next(m for m in bpy.data.materials if m.name.endswith('committed machined steel') and m.name.startswith('DISH_V03')),
 'dark':next(m for m in bpy.data.materials if m.name.endswith('committed gunmetal') and m.name.startswith('DISH_V03')),
 'brass':next(m for m in bpy.data.materials if m.name.endswith('committed tarnished brass') and m.name.startswith('DISH_V03'))}

for variant in ('chicago-piano','twin-minigun'):
    O=output/variant;O.mkdir(exist_ok=True)
    for o in list(S.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    mats={key:m.copy() for key,m in original_mats.items()}
    for key,m in mats.items():m.name=variant+' | '+key+' | authored longitudinal UV'
    def flat(name,color,metal=.0,rough=.5,glow=0):
        m=bpy.data.materials.new(variant+' | '+name);m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
        p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
        return m
    mats['lens']=flat('recessed optical glass',(.012,.07,.08),.15,.2,.4)
    mats['flash']=flat('white orange muzzle discharge',(1,.38,.035),0,.5,7)
    root=bpy.data.objects.new('TURRET_TRAVERSE',None);S.collection.objects.link(root);root.location=(0,0,1.70)
    created=[];fx=[];recoil=[];rotors=[];flash_groups=[]
    def parent_world(o,parent):
        bpy.context.view_layer.update();mw=o.matrix_world.copy();o.parent=parent;o.matrix_world=mw
    def uv(o,cylinder=False):
        layer=o.data.uv_layers.active or o.data.uv_layers.new(name='Physical_scale_2_repeats_per_tile')
        for polygon in o.data.polygons:
            normal=polygon.normal;axis=max(range(3),key=lambda j:abs(normal[j]))
            axes=[j for j in range(3) if j!=axis]
            for li in polygon.loop_indices:
                v=o.data.vertices[o.data.loops[li].vertex_index].co
                if cylinder and len(polygon.vertices)==4:
                    layer.data[li].uv=(math.atan2(v.y,v.x)/math.tau*max(o.dimensions.x,.01)*math.pi*2,v.z*2)
                else:layer.data[li].uv=(v[axes[0]]*2,v[axes[1]]*2)
    def finish(o,name,mat,parent=None,bevel=0):
        o.name=name;o.data.materials.clear();o.data.materials.append(mats[mat]);uv(o)
        if bevel:
            mod=o.modifiers.new('Machined edge break','BEVEL');mod.width=bevel;mod.segments=2
            o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
        parent_world(o,parent or root);created.append(o);return o
    def box(name,loc,size,mat='dark',parent=None,bevel=.012):
        bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return finish(o,name,mat,parent,bevel)
    def cylinder(name,a,b,r,mat='steel',parent=None,vertices=24):
        a,b=Vector(a),Vector(b);d=b-a
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2)
        o=bpy.context.object;uv(o,True);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
        return finish(o,name,mat,parent,.004)
    def tube(name,a,b,r,wall,mat='steel',parent=None):
        a,b=Vector(a),Vector(b);axis=(b-a).normalized()
        u=axis.cross(Vector((1,0,0)))
        if u.length<.1:u=axis.cross(Vector((0,0,1)))
        u.normalize();v=axis.cross(u);n=24;vs=[];fs=[]
        for centre,radius in [(a,r),(b,r),(b,r-wall),(a,r-wall)]:
            for j in range(n):vs.append(centre+radius*(u*math.cos(math.tau*j/n)+v*math.sin(math.tau*j/n)))
        for ring,next_ring in [(0,1),(1,2),(2,3),(3,0)]:
            for j in range(n):fs.append((ring*n+j,ring*n+(j+1)%n,next_ring*n+(j+1)%n,next_ring*n+j))
        data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
        o=bpy.data.objects.new(name,data);S.collection.objects.link(o);finish(o,name,mat,parent)
        layer=o.data.uv_layers.active
        for polygon in data.polygons:
            for li in polygon.loop_indices:
                vi=data.loops[li].vertex_index;ring,j=divmod(vi,n)
                angular=j/n
                if polygon.index%24==23 and j==0:angular=1
                layer.data[li].uv=(angular*math.tau*r*2,(0 if ring in (0,3) else (b-a).length)*2)
        return o
    def conduit(name,points,r=.018,mat='dark',parent=None):
        data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=r;data.bevel_resolution=2
        spline=data.splines.new('POLY');spline.points.add(len(points)-1)
        for p,point in zip(spline.points,points):p.co=(*point,1)
        o=bpy.data.objects.new(name,data);S.collection.objects.link(o);data.materials.append(mats[mat]);parent_world(o,parent or root);created.append(o)
        return o
    def empty(name,loc,parent=None):
        o=bpy.data.objects.new(name,None);S.collection.objects.link(o);o.location=loc;parent_world(o,parent or root);return o
    def flash(name,loc,parent):
        bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=.09,radius2=.015,depth=.32,location=loc)
        o=bpy.context.object;o.rotation_euler.x=math.pi/2;finish(o,name,'flash',parent);fx.append(o);return o
    def armor(name,x,y,z,width,length,height,parent=None):
        # Faceted receiver armor: sloped shoulders carry the upper cover.
        profile=[(-width/2,0),(-width/2,height*.65),(-width*.30,height),
                 (width*.30,height),(width/2,height*.65),(width/2,0)]
        vs=[(x+px,y+sign*length/2,z+pz) for sign in (-1,1) for px,pz in profile]
        fs=[tuple(reversed(range(6))),tuple(range(6,12))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]
        data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
        o=bpy.data.objects.new(name,data);S.collection.objects.link(o);return finish(o,name,'red',parent,.015)
    def profile_body(name,x,width,profile,mat='dark',parent=None):
        # Extrude an engineering side profile, rather than dressing a cube.
        n=len(profile);vs=[(x+sign*width/2,y,z) for sign in (-1,1) for y,z in profile]
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
        data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
        o=bpy.data.objects.new(name,data);S.collection.objects.link(o);return finish(o,name,mat,parent,.009)
    def arc_shell(name,x,y0,y1,z,r,wall,start,end,mat='red',parent=None):
        n=max(3,int(abs(end-start)/(.16)));vs=[];fs=[]
        for y,radius in [(y0,r),(y1,r),(y1,r-wall),(y0,r-wall)]:
            for j in range(n+1):
                a=start+(end-start)*j/n;vs.append((x+radius*math.cos(a),y,z+radius*math.sin(a)))
        count=n+1
        for ring,next_ring in [(0,1),(1,2),(2,3),(3,0)]:
            for j in range(n):fs.append((ring*count+j,ring*count+j+1,next_ring*count+j+1,next_ring*count+j))
        fs += [(0,count,2*count,3*count),(n,3*count+n,2*count+n,count+n)]
        data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
        o=bpy.data.objects.new(name,data);S.collection.objects.link(o);return finish(o,name,mat,parent,.003)
    def cut_port(body,location,size):
        bpy.ops.mesh.primitive_cube_add(size=1,location=location);cutter=bpy.context.object;cutter.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        modifier=body.modifiers.new('Actual recessed ejection aperture','BOOLEAN');modifier.operation='DIFFERENCE';modifier.object=cutter
        bpy.context.view_layer.objects.active=body
        bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
    # Standard interface, supported yoke, rotary coupling and service locks.
    cylinder('Lower bearing adapter',(0,0,1.70),(0,0,1.84),.76,'dark')
    cylinder('Traverse race cover',(0,0,1.84),(0,0,1.90),.70,'steel')
    # An open ladder cradle makes the load paths and service space visible.
    for y in (-.30,.34):box('Cradle cross member',(0,y,2.01),(1.94,.13,.18),'dark',bevel=.018)
    for x in (-.83,.83):box('Cradle longitudinal rail',(x,.02,2.01),(.13,.77,.18),'steel',bevel=.014)
    for side in (-1,1):
        profile_body('Cast triangular elevation web',side*.98,.13,
          [(-.39,1.95),(.39,1.95),(.25,2.21),(.08,2.47),(-.08,2.47),(-.27,2.18)],'dark')
        profile_body('Inset red blast cheek',side*1.055,.035,
          [(-.31,2.02),(.28,2.02),(.15,2.20),(0,2.34),(-.15,2.20)],'red')
        cylinder('Supported elevation trunnion',(side*.82,0,2.30),(side*1.12,0,2.30),.14)
        tube('Trunnion retaining flange',(side*1.115,0,2.30),(side*1.145,0,2.30),.15,.055,'dark')
        for y in (-.25,.29):cylinder('Yoke structural fastener',(side*1.09,y,2.09),(side*1.12,y,2.09),.035,'steel',vertices=6)
    box('Protected targeting controller',(.52,.64,2.23),(.43,.31,.30),'red')
    box('Optical head bracket',(.98,-.25,2.51),(.18,.32,.16),'dark')
    box('Armored rangefinder housing',(.98,-.3,2.64),(.23,.30,.18),'red')
    for x in (.92,1.04):cylinder('Recessed paired optical aperture',(x,-.455,2.65),(x,-.48,2.65),.034,'lens')
    conduit('Armored optics data trunk',[(.98,-.13,2.61),(.99,.36,2.58),(.72,.64,2.40),(.52,.64,2.34)])
    cylinder('Telemetry mast socket',(-.88,.48,2.26),(-.88,.48,2.40),.07,'dark')
    cylinder('Co-traversing short aerial',(-.88,.48,2.40),(-.88,.48,2.96),.016,'dark')
    conduit('Telemetry hardline',[(-.88,.48,2.28),(-.60,.65,2.17),(.30,.65,2.17),(.52,.64,2.23)])
    if variant=='chicago-piano':
        cycle=48
        for index,x in enumerate((-.75,-.25,.25,.75)):
            carrier=empty('RECOIL_GUN_'+str(index),(x,0,2.32));recoil.append(carrier)
            receiver=profile_body('Forged stepped receiver '+str(index),x,.32,
              [(-.43,2.24),(.43,2.24),(.48,2.34),(.33,2.48),(-.17,2.50),(-.36,2.43)],'dark',carrier)
            cut_port(receiver,(x+.145,.08,2.365),(.085,.20,.085))
            box('Dark recessed ejection chamber',(x+.111,.08,2.365),(.012,.17,.065),'dark',carrier,.002)
            box('Ejection port lower wear lip',(x+.166,.08,2.319),(.025,.22,.018),'steel',carrier,.003)
            # Narrow removable covers flank a visible sliding bolt rail.
            for side in (-1,1):
                box('Red receiver side cover',(x+side*.125,.11,2.425),(.035,.48,.10),'red',carrier,.008)
                cylinder('External bolt guide rail',(x+side*.105,-.18,2.49),(x+side*.105,.37,2.49),.017,'steel',carrier)
            box('Exposed bolt carrier',(x,.07,2.493),(.10,.25,.052),'steel',carrier,.007)
            tube('Hollow rifled barrel '+str(index),(x,-.35,2.38),(x,-1.72,2.38),.072,.024,parent=carrier)
            tube('Barrel recoil guide '+str(index),(x,-.28,2.38),(x,-.65,2.38),.105,.025,'dark',carrier)
            for segment in range(6):
                a=segment*math.tau/6
                arc_shell('Slotted heat shield',x,-.67,-1.15,2.38,.105,.014,a,a+math.pi/6,'dark',carrier)
            for y in (-.66,-1.15):tube('Heat shield end retainer',(x,y-.018,2.38),(x,y+.018,2.38),.11,.017,'steel',carrier)
            tube('Slender machined muzzle crown',(x,-1.66,2.38),(x,-1.73,2.38),.080,.030,'dark',carrier)
            cylinder('Recoil return cylinder '+str(index),(x,-.25,2.16),(x,.48,2.16),.056,'dark',carrier)
            cylinder('Sliding return rod '+str(index),(x,-.56,2.16),(x,-.17,2.16),.023,'steel',carrier)
            box('Breech service latch '+str(index),(x,.30,2.52),(.085,.11,.035),'steel',carrier,.005)
            for y in (-.12,.35):
                    for dx in (-.105,.105):cylinder('Receiver cover fastener',(x+dx,y,2.495),(x+dx,y,2.515),.019,'steel',carrier,6)
            flash_groups.append([flash('MUZZLE_FLASH_'+str(index),(x,-1.86,2.38),carrier)])
            box('Spent-case outlet '+str(index),(x+.15,.0,2.27),(.055,.20,.12),'dark',carrier,.003)
        for index,x in enumerate((-.75,-.25,.25,.75)):
            # Four separate articulated tracks rise from the lower ammunition
            # trunk and turn into LEFT-side feed ports, opposite the ejectors.
            # Cartridges run parallel to the bore; the belt travels across it.
            box('Under-cradle ammunition trunk '+str(index),(x-.22,.22,1.96),(.24,.31,.16),'dark',bevel=.018)
            box('Red lower feed collar '+str(index),(x-.28,.22,2.055),(.16,.29,.09),'red',bevel=.012)
            points=[]
            # Vertical lower run, then a quarter-circle into the receiver.
            for j in range(4):points.append((x-.30,.22,2.06+j*.047))
            for j in range(1,7):
                a=math.pi-(math.pi/2)*j/6
                points.append((x-.16+.14*math.cos(a),.22,2.201+.14*math.sin(a)))
            points.append((x-.145,.22,2.341))
            for dy in (-.125,.125):
                conduit('Articulated side-feed edge rail '+str(index),[(px,py+dy,pz) for px,py,pz in points],.014,'dark')
            for j,(px,py,pz) in enumerate(points):
                tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
                link=box('Segmented belt track shoe '+str(index),(px,py,pz),(.035,.27,.018),'dark',bevel=.003)
                link.rotation_euler.y=-math.atan2(tangent.z,tangent.x)
                cylinder('Belted brass cartridge '+str(index),(px,py-.060,pz+.012),(px,py+.105,pz+.012),.021,'brass')
                cylinder('Forward-facing projectile '+str(index),(px,py-.105,pz+.012),(px,py-.060,pz+.012),.017,'steel')
                tube('Cartridge retaining link '+str(index),(px,py+.020,pz+.012),(px,py+.050,pz+.012),.025,.005,'dark')
            box('Side-entry belt feed throat '+str(index),(x-.16,.22,2.345),(.065,.29,.11),'steel',recoil[index],.012)
            box('Feed throat recessed opening '+str(index),(x-.196,.22,2.345),(.008,.23,.065),'dark',recoil[index],.002)
    else:
        cycle=36
        for index,x in enumerate((-.52,.52)):
            carrier=empty('RECOIL_GUN_'+str(index),(x,0,2.37));recoil.append(carrier)
            cylinder('Cast cylindrical rotary receiver',(x,-.27,2.42),(x,.48,2.42),.275,'dark',carrier)
            tube('Receiver front bearing collar',(x,-.28,2.42),(x,-.20,2.42),.29,.055,'steel',carrier)
            for panel in range(3):
                a=.20+panel*.86
                arc_shell('Curved removable drive armor',x,-.10,.48,2.42,.31,.026,a,a+.74,'red',carrier)
                for y in (.02,.37):
                    angle=a+.37;dx=.317*math.cos(angle);dz=.317*math.sin(angle)
                    cylinder('Drive armor retained fastener',(x+dx,y,2.42+dz),
                      (x+dx*1.05,y,2.42+dz*1.05),.024,'steel',carrier,6)
            rotor=empty('SIX_BARREL_ROTOR_'+str(index),(x,-.27,2.42),carrier);rotors.append(rotor)
            cylinder('Continuous central drive shaft',(x,-.32,2.42),(x,-1.58,2.42),.043,'dark',rotor)
            flashes=[]
            for barrel in range(6):
                angle=barrel*math.tau/6;dx=.155*math.cos(angle);dz=.155*math.sin(angle)
                tube('Rotor '+str(index)+' open barrel '+str(barrel),(x+dx,-.30,2.42+dz),(x+dx,-1.62,2.42+dz),.042,.015,'steel',rotor)
                flashes.append(flash('ROTOR_FLASH_'+str(index)+'_'+str(barrel),(x+dx,-1.78,2.42+dz),rotor))
            flash_groups.append(flashes)
            for y in (-.38,-1.43):
                tube('Stationary rotor bearing',(x,y-.035,2.42),(x,y+.035,2.42),.255,.035,'dark',carrier)
            for angle in (math.pi/2,math.pi*7/6,math.pi*11/6):
                dx=.27*math.cos(angle);dz=.27*math.sin(angle)
                cylinder('External bearing stay',(x+dx,-.30,2.42+dz),(x+dx,-1.44,2.42+dz),.022,'dark',carrier)
            cylinder('Rotary drive end casing',(x,.46,2.42),(x,.78,2.42),.19,'dark',carrier)
            for y in (.50,.57,.64,.71):tube('Drive motor cooling fin',(x,y,2.42),(x,y+.023,2.42),.215,.038,'steel',carrier)
            cylinder('Bolted rear drive cover',(x,.78,2.42),(x,.82,2.42),.20,'dark',carrier)
            for j in range(6):
                a=j*math.tau/6;dx=.157*math.cos(a);dz=.157*math.sin(a)
                cylinder('Rear drive-cover bolt',(x+dx,.817,2.42+dz),(x+dx,.84,2.42+dz),.021,'steel',carrier,6)
            side=-1 if x<0 else 1
            cylinder('Co-traversing ammunition drum',(side*.90,.55,2.26),(side*1.20,.55,2.26),.255,'dark')
            cylinder('Red drum service end',(side*1.19,.55,2.26),(side*1.225,.55,2.26),.235,'red')
            tube('Drum service cover lip',(side*1.22,.55,2.26),(side*1.245,.55,2.26),.246,.025,'steel')
            box('Belt feed gearbox',(side*.80,.12,2.43),(.22,.34,.23),'dark',carrier,.035)
            cylinder('Feed gearbox inspection cover',(side*.90,.12,2.43),(side*.94,.12,2.43),.105,'steel',carrier)
            points=[(side*1.02,.29,2.30),(side*1.00,.17,2.35),(side*.90,.06,2.42),(side*.78,.03,2.45)]
            for dz in (-.055,.055):conduit('Flexible belt edge guide',[(px,py,pz+dz) for px,py,pz in points],.019,'dark')
            for j in range(9):
                f=j/8;px=side*(1.02-.24*f);py=.29-.26*f;pz=2.30+.15*f
                cylinder('Linked rifle round in curved feed',(px,py-.065,pz),(px,py+.065,pz),.022,'brass')
            conduit('Drive hydraulic service loop',[(side*.88,.30,2.51),(side*.89,.56,2.62),(side*.63,.71,2.62),(.52,.64,2.34)],.019,'dark')
    # Source keys: all construction geometry remains editable and distinct.
    rest=[o.location.copy() for o in recoil]
    for frame in range(cycle+1):
        S.frame_set(frame+1)
        for index,carrier in enumerate(recoil):
            if variant=='chicago-piano':phase=(frame-index*6)%cycle
            else:phase=frame%6
            kick=.055*math.sin(math.pi*phase/5) if phase<5 else 0
            if variant=='chicago-piano' and frame%cycle>=24:
                kick=.025*math.sin(math.pi*(frame%cycle-24)/24)
            carrier.location=rest[index]+Vector((0,kick,0));carrier.keyframe_insert('location')
        for index,rotor in enumerate(rotors):
            rotor.rotation_euler.y=(1 if index==0 else -1)*math.tau*frame/36;rotor.keyframe_insert('rotation_euler')
        for index,group in enumerate(flash_groups):
            for barrel,o in enumerate(group):
                shot=(frame-index*6)%cycle if variant=='chicago-piano' else frame%6
                # Counter-rotating banks need opposite barrel selection so
                # both discharges stay at a fixed point on their receivers.
                firing_barrel=((1 if index==0 else -1)*(frame//6))%6
                active=shot==0 and (variant=='chicago-piano' or barrel==firing_barrel)
                o.scale=(1,1,1) if active else (.0001,)*3;o.keyframe_insert('scale')
    for obj in recoil+rotors+fx:
        if obj.animation_data and obj.animation_data.action:
            for slot in obj.animation_data.action.slots:
                for layer in obj.animation_data.action.layers:
                    for strip in layer.strips:
                        bag=strip.channelbag(slot)
                        if bag:
                            for curve in bag.fcurves:
                                for key in curve.keyframe_points:key.interpolation='LINEAR'
    S.frame_start=1;S.frame_end=cycle;S.frame_set(1)
    for o in fx:o.hide_render=True
    for i in bpy.data.images:
        if i.source=='FILE' and not i.packed_file:i.pack()
    S['variant']=variant;S['base_included']=False;S['mount_socket']=[0,0,1.70]
    S['surface_plan']='Oxide-red removable receiver/drive armor; longitudinal machined barrel UVs; dark cast cradle and bearing supports; brass only on cartridge links and service fittings; recessed teal optics wired into protected controller.'
    bpy.ops.wm.save_as_mainfile(filepath=str(O/(variant+'.blend')),compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in created:
        if o not in fx:o.select_set(True)
    root.select_set(True);bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(O/(variant+'.glb')),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
    for name,yaw in [('front',0),('rear',math.pi),('quarter',math.pi/4)]:
        root.rotation_euler.z=yaw;S.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True)
    bounds=[o.matrix_world@Vector(p) for o in created if o.type=='MESH' and o not in fx for p in o.bound_box]
    record={'status':'AUTHORED_CANDIDATE','variant':variant,'base_included':False,'mount':[0,0,1.70],
      'mesh_objects':sum(o.type=='MESH' for o in created if o not in fx),'cycle_ticks':cycle,
      'shot_ticks':[0,6,12,18] if variant=='chicago-piano' else list(range(0,36,6)),
      'rounds_per_pulse':1 if variant=='chicago-piano' else 2,
      'fixed_base_source':'existing bunker-autocannon base sprites unchanged',
      'bounds_review_pose':[[min(p[j] for p in bounds) for j in range(3)],[max(p[j] for p in bounds) for j in range(3)]],
      'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256((O/(variant+'.blend')).read_bytes()).hexdigest()}
    (O/'contract.json').write_text(json.dumps(record,indent=2)+'\n')
    print('BULLET_TURRET_AUTHORED',variant,flush=True)
