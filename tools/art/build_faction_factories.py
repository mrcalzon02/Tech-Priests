"""Author, texture-bake, export/reimport and render the three faction factories.

Blender 5: --background --python this.py -- --model martian [--samples 32]
Geometry is original project construction, not extracted donor building art.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/source-to-3d/faction-factories-v1/candidates'
CONTRACTS={
 'martian':dict(label='Martian Manufactorum',tiles=4,height=3.6,target=1.35),
 'guard':dict(label='Imperial Guard Muster Hall',tiles=5,height=3.9,target=1.45),
 'sororitas':dict(label='Sororitas Convent',tiles=6,height=5.9,target=2.0),
}
PARTS=[]

def material(name,base,rough=.75,metal=0,scale=12,grain=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links
 p=n.get('Principled BSDF');p.inputs['Metallic'].default_value=metal
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=scale
 tex.inputs['Detail'].default_value=3;tex.inputs['Roughness'].default_value=.7
 coord=n.new('ShaderNodeTexCoord')
 if grain:
  mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=grain
  l.new(coord.outputs['Object'],mapping.inputs[0]);l.new(mapping.outputs[0],tex.inputs['Vector'])
 else:l.new(coord.outputs['Object'],tex.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB')
 for stop,mult in zip(ramp.color_ramp.elements,[.72,1.13]):stop.color=tuple(min(1,c*mult) for c in base)+(1,)
 l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 roughnode=n.new('ShaderNodeMapRange');roughnode.inputs['To Min'].default_value=rough-.09;roughnode.inputs['To Max'].default_value=min(1,rough+.09)
 l.new(tex.outputs['Fac'],roughnode.inputs[0]);l.new(roughnode.outputs[0],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.23;bump.inputs['Distance'].default_value=.025 if metal==0 else .007
 l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m

def finish(obj,name,mat,bevel=0):
 obj.name=name;obj.data.materials.append(mat)
 if bevel:
  mod=obj.modifiers.new('Manufactured edge radius','BEVEL');mod.width=bevel;mod.segments=2
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
 obj['construction_role']=name;PARTS.append(obj);return obj

def box(name,loc,size,mat,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,mat,bevel)

def cyl(name,loc,radius,depth,mat,vertices=20,axis='Z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
 o=bpy.context.object
 if axis=='Y':o.rotation_euler.x=math.pi/2
 elif axis=='X':o.rotation_euler.y=math.pi/2
 return finish(o,name,mat,.012)

def beam(name,a,b,r,mat,vertices=12):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat,vertices)
 o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def path(name,points,r,mat):
 # Rounded physical elbows and straight runs, not tubes buried in the vessel.
 for i,(a,b) in enumerate(zip(points,points[1:])):beam(name+' run '+str(i),a,b,r,mat)
 for i,p in enumerate(points[1:-1]):
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=r,location=p)
  finish(bpy.context.object,name+' elbow '+str(i),mat)

def torus(name,loc,major,minor,mat,axis='Z'):
 bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=loc,major_radius=major,minor_radius=minor)
 o=bpy.context.object
 if axis=='Y':o.rotation_euler.x=math.pi/2
 return finish(o,name,mat)

def roof(name,cx,cy,width,length,eave,rise,mat):
 # Two structural closed roof halves; each sheet has an authored seam direction.
 for side in [-1,1]:
  slope=math.atan2(rise,width/2)
  o=box(name+(' left' if side<0 else ' right'),(cx+side*width/4,cy,eave+rise/2),
        (math.hypot(width/2,rise),length,.12),mat,.025)
  o.rotation_euler.y=side*slope

def gable(name,y,width,depth,eave,rise,mat):
 verts=[(-width/2,y-depth/2,eave),(width/2,y-depth/2,eave),(0,y-depth/2,eave+rise),
        (-width/2,y+depth/2,eave),(width/2,y+depth/2,eave),(0,y+depth/2,eave+rise)]
 faces=[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,mat,.02)

def arch_points(width,height,segments=12):
 r=width/2;spring=height-r
 return [(-r,0),(r,0)]+[(r*math.cos(i*math.pi/segments),spring+r*math.sin(i*math.pi/segments)) for i in range(segments+1)]

def arch(name,loc,width,height,depth,mat):
 pts=arch_points(width,height);n=len(pts);x,y,z=loc
 verts=[(x+u,y+d,z+v) for d in [-depth/2,depth/2] for u,v in pts]
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,mat)

def arch_frame(name,loc,w,h,mat):
 x,y,z=loc;r=w/2;spring=h-r
 box(name+' jamb L',(x-r-.06,y,z+spring/2),(.12,.18,spring),mat)
 box(name+' jamb R',(x+r+.06,y,z+spring/2),(.12,.18,spring),mat)
 for i in range(12):
  a=i*math.pi/12;b=(i+1)*math.pi/12
  beam(name+' voussoir '+str(i),(x+(r+.06)*math.cos(a),y,z+spring+(r+.06)*math.sin(a)),
       (x+(r+.06)*math.cos(b),y,z+spring+(r+.06)*math.sin(b)),.085,mat,8)

def cut_arch(wall,loc,w,h,depth,mat):
 cutter=arch('Window opening tool',loc,w,h,depth,mat)
 bpy.context.view_layer.objects.active=wall;mod=wall.modifiers.new('Real arched opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)

def bolts_front(x0,x1,y,z,mat,spacing=.3):
 n=max(2,round((x1-x0)/spacing))
 for i in range(n+1):cyl('Seated frame fastener',(x0+(x1-x0)*i/n,y,z),.027,.035,mat,8,'Y')

def martian(m):
 red,iron,brass,stone,rubber,glass=m
 box('Four tile foundation',(0,0,.11),(3.9,3.9,.22),stone,.09)
 box('Factory rear wall',(0,1.25,1.05),(2.85,.2,1.75),red)
 for x in [-1.32,1.32]:
  box('Cast production side wall',(x,0,1.05),(.22,2.65,1.75),red)
  for y in [-1.15,-.35,.45,1.17]:box('External iron load rib',(x*1.065,y,1.05),(.16,.14,1.75),iron)
 box('Front lintel',(0,-1.27,1.82),(2.85,.24,.3),iron)
 for x in [-1.13,1.13]:box('Door side pier',(x,-1.27,.95),(.58,.28,1.4),red)
 box('Recessed black shutter backing',(0,-1.22,.95),(1.7,.1,1.4),rubber)
 for z in [.37+i*.125 for i in range(10)]:box('Separate steel rolling shutter slat',(0,-1.32,z),(1.65,.1,.095),iron,.012)
 for x in [-.88,.88]:box('Shutter rail',(x,-1.4,1.0),(.09,.09,1.5),brass,.014)
 box('Armoured roof deck',(0,0,1.98),(2.9,2.83,.18),iron,.06)
 for x in [-.93,0,.93]:box('Red roof plate',(x,-.25,2.1),(.85,1.95,.1),red)
 for y in [-.7,.25]:
  for x in [-1.1,0,1.1]:cyl('Roof countersunk bolt',(x,y,2.17),.04,.035,brass,10)
 cyl('Roof extraction housing',(.55,.6,2.22),.56,.3,iron)
 cyl('Dark fan well',(.55,.6,2.39),.45,.04,rubber)
 for i in range(8):
  a=i*math.pi/4;blade=box('Ventilator blade',(.55+.23*math.cos(a),.6+.23*math.sin(a),2.43),(.43,.1,.04),brass,.01);blade.rotation_euler.z=a+.4
 torus('Ventilator guard',(.55,.6,2.47),.47,.03,iron)
 for i in [-2,-1,0,1,2]:box('Fan finger guard',(.55+i*.14,.6,2.51),(.025,.82,.025),iron,.005)
 for x,y,height in [(-.85,.83,3.35),(-.35,1.08,2.9)]:
  cyl('Chimney base',(x,y,2.22),.23,.25,brass)
  cyl('Sooted exhaust barrel',(x,y,(height+2.2)/2),.16,height-2.2,iron)
  torus('Exhaust collar',(x,y,height-.2),.17,.035,brass)
  cyl('Black exhaust opening',(x,y,height+.01),.12,.025,rubber)
  for k in range(5):box('Exhaust heat shield band',(x,y,height-.35-k*.12),(.37,.37,.035),iron,.02)
 box('Production inspection bay',(1.65,.55,.85),(.35,1.4,1.2),iron)
 for y in [.05,.35,.65,.95]:box('Cooling fin',(1.72,y,.93),(.36,.08,.9),brass,.01)
 path('Exterior feed pipe',[(-1.6,-.7,.35),(-1.6,-.7,1.5),(-1.6,.75,1.5),(-1.6,.75,2.0)],.075,brass)
 for y in [-.6,.5]:box('Pipe wall saddle',(-1.47,y,1.5),(.3,.08,.18),iron)
 box('Cogitator casing',(-1.05,-1.57,1.05),(.4,.27,.62),iron)
 box('Cogitator glass',(-1.05,-1.72,1.16),(.25,.035,.22),glass,.01)
 for x in [-1.13,-1.02]:cyl('Cogitator selector',(x,-1.75,.91),.035,.025,brass,10,'Y')
 # Original cog motif, seated on the lintel; not a copied franchise insignia.
 torus('Workshop cog',(0,-1.43,1.95),.24,.065,brass,'Y')
 for i in range(10):
  a=i*math.tau/10;o=box('Workshop cog tooth',(.31*math.cos(a),-1.43,1.95+.31*math.sin(a)),(.14,.12,.12),iron,.01);o.rotation_euler.y=-a
 box('Front deployment sill',(0,-1.64,.25),(1.85,.52,.1),iron)
 for x in [-.62,-.31,0,.31,.62]:box('Sill grip',(x,-1.64,.32),(.06,.43,.035),brass,.005)

def guard(m):
 olive,iron,tan,stone,wood,glass=m
 box('Five tile foundation',(0,0,.1),(4.9,4.9,.2),stone,.08)
 box('Barracks long walls',(0,0,1.05),(3.9,3.55,1.7),tan,.05)
 for y in [-1.79,1.79]:gable('Gabled end',y,3.9,.18,1.9,.78,tan)
 roof('Pitched military metal roof',0,0,4.25,3.95,1.95,.83,olive)
 for y in [-1.85+i*.22 for i in range(18)]:
  for side in [-1,1]:beam('Raised standing roof seam',(side*.03,y,2.85),(side*2.1,y,2.02),.023,iron,8)
 box('Roof ridge cap',(0,0,2.84),(.12,4.05,.12),iron)
 # Cut a genuine front door instead of mounting a false door over solid wall.
 cut_arch(PARTS[1],(0,-1.8,.21),1.28,1.42,1.0,tan)
 arch('Dark entrance recess',(0,-1.49,.21),1.26,1.4,.06,iron)
 for x in [-.32,.32]:box('Reinforced double door',(x,-1.84,.86),(.6,.08,1.25),olive)
 for x in [-.58,.58]:box('Door slide rail',(x,-1.91,.92),(.07,.07,1.4),iron)
 box('Door header',(0,-1.94,1.65),(1.5,.19,.16),iron)
 for x in [-1.35,1.35]:
  box('Front window black rebate',(x,-1.81,1.28),(.65,.08,.55),iron)
  box('Front wire glass',(x,-1.86,1.28),(.51,.04,.42),glass,.01)
  for a in [-.18,0,.18]:box('Window security bar',(x+a,-1.91,1.28),(.035,.04,.53),iron,.005)
 for x in [-1.96,1.96]:
  for y in [-1.1,0,1.1]:
   box('Side framed window',(x,y,1.24),(.08,.6,.55),iron)
   box('Side window glass',(x*1.022,y,1.24),(.035,.48,.43),glass,.005)
  for y in [-1.65,-.55,.55,1.65]:box('Wall structural upright',(x*1.035,y,1.03),(.12,.12,1.75),olive)
 # Roof radio/vent tower stands on the ridge and its own support frame.
 box('Roof ventilation plinth',(.15,.7,2.88),(1.0,.9,.16),iron)
 box('Vent cupola',(.15,.7,3.14),(.8,.7,.43),olive)
 for z in [3.03,3.14,3.25]:box('Vent louvre',(.15,.32,z),(.68,.08,.045),iron,.01)
 box('Cupola cap',(.15,.7,3.42),(1,.9,.12),olive)
 beam('Radio mast',(.15,.7,3.48),(.15,.7,3.85),.025,iron)
 for y in [.35,.7,1.05]:beam('Radio antenna spreader',(-.25,y,3.67),(.55,y,3.67),.018,iron)
 # Canvas canopy, anchored to real posts over a supply loading side.
 for x in [-1.75,-.75]:
  for y in [-2.27,-1.82]:beam('Awning post',(x,y,.22),(x,y,1.72),.035,iron)
 awning=box('Canvas supply canopy',(-1.25,-2.02,1.76),(1.15,.62,.07),olive,.015)
 awning.rotation_euler.x=.12
 for x in [-1.55,-1.0]:
  box('Supply crate',(x,-2.03,.44),(.43,.4,.43),wood,.025)
  for z in [.33,.52]:box('Crate band',(x,-2.245,z),(.44,.025,.04),iron,.005)
 for x in [.9,1.4,1.9]:
  box('Defensive filled sandbag',(x,-2.17,.36),(.52,.34,.23),tan,.10)
  box('Upper offset sandbag',(x-.1,-2.17,.58),(.5,.32,.22),tan,.09)
 box('Inset entry step',(0,-2.07,.22),(1.4,.56,.12),iron)
 for x in [-1.75,1.75]:bolts_front(x-.1,x+.1,-1.865,1.9,iron,.1)
 # Own military chevrons; no borrowed regiment icon or generated text.
 for side in [-1,1]:
  a=(side*.13,-1.93,2.38);b=(side*.40,-1.93,2.16)
  beam('Muster chevron',a,b,.045,iron,8)

def sororitas(m):
 stone,dark,roofmat,brass,glass,red=m
 box('Six tile dressed foundation',(0,0,.14),(5.85,5.85,.28),stone,.07)
 box('Inset dark foundation course',(0,0,.31),(5.6,5.6,.12),dark)
 # A hollow nave with real window apertures and structural corner piers.
 walls=[]
 for x in [-1.65,1.65]:walls.append(box('Nave side masonry',(x,.15,1.78),(.24,4.4,2.8),stone,.025))
 front=box('Portal wall',(0,-2.0,1.78),(3.54,.24,2.8),stone,.025)
 rear=box('Rear apse wall',(0,2.23,1.78),(3.54,.24,2.8),stone,.025)
 cut_arch(front,(0,-2.0,.36),1.05,1.7,.7,dark)
 arch('Recessed bronze portal',(0,-2.04,.37),1.0,1.64,.09,brass)
 arch_frame('Carved portal',(0,-2.18,.36),1.12,1.78,stone)
 for x in [-.2,.2]:box('Portal iron strap',(x,-2.12,1.0),(.06,.025,1.1),dark,.008)
 for x,wall in zip([-1.65,1.65],walls):
  for y in [-1.05,.25,1.55]:
   # Arch geometry starts in X/Z; rotate window + cutter into the side wall.
   cutter=arch('Window opening tool',(0,0,0),.62,1.48,.65,dark)
   cutter.rotation_euler.z=math.pi/2;cutter.location=(x,y,1.1)
   bpy.context.view_layer.objects.active=wall;mod=wall.modifiers.new('Real window opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
   bpy.ops.object.modifier_apply(modifier=mod.name);PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
   start=len(PARTS)
   arch('Lead glass inset',(0,0,0),.58,1.44,.04,glass)
   arch_frame('Stone window surround',(0,-.07,0),.64,1.5,stone)
   for offset in [-.15,0,.15]:box('Lead glass vertical',(offset,-.04,.65),(.025,.035,1.3),dark,.004)
   for z in [.35,.7,1.05]:box('Lead glass crossbar',(0,-.04,z),(.57,.035,.025),dark,.004)
   for o in PARTS[start:]:
    local=o.location.copy();o.location=(x-local.y,y+local.x,1.1+local.z);o.rotation_euler.z+=math.pi/2
  for y in [-1.8,-.4,.95,2.18]:
   outer=x+math.copysign(.6,x)
   box('Buttress footing',(outer,y,.56),(.42,.48,.4),dark)
   box('Buttress pier',(outer,y,1.31),(.3,.36,1.2),stone)
   beam('Sloped supported buttress',(outer,y,1.65),(x,y,2.75),.14,stone,8)
   box('Buttress coping',(outer,y,1.95),(.42,.48,.12),stone)
 for y in [-2,2.23]:gable('Nave stone gable',y,3.54,.22,3.18,1.0,stone)
 roof('Burgundy slate nave roof',0,.12,3.9,4.62,3.18,1.08,roofmat)
 # Actual overlapping slate rows, aligned with the roof slope.
 for side in [-1,1]:
  for row in range(6):
   x=side*(.15+row*.31);z=4.30-abs(x)*1.08/1.95
   for col in range(12):
    y=-2.02+col*.37+(row%2)*.12
    tile=box('Individual nave slate',(x,y,z),(.37,.40,.04),roofmat,.01);tile.rotation_euler.y=side*math.atan2(1.08,1.95)
 box('Nave ridge flashing',(0,.12,4.33),(.15,4.7,.11),brass)
 # Two asymmetric front bell/armoury towers, separated from the nave portal.
 for x,h in [(-2.13,3.65),(2.13,4.05)]:
  box('Tower ashlar base',(x,-1.77,.65),(1.08,1.2,.62),dark)
  box('Front tower shaft',(x,-1.77,(h+.45)/2),(.92,1.02,h-.45),stone)
  for z in [.9,1.55,2.2,2.85,h-.1]:box('Tower string course',(x,-1.77,z),(1.02,1.12,.08),dark,.015)
  for dx in [-.46,.46]:box('Tower corner quoin',(x+dx,-2.28,1.9),(.12,.12,2.8),stone)
  arch('Bell louvre recess',(x,-2.3,h-1.15),.5,.8,.06,dark)
  for z in [h-.96,h-.78,h-.60]:box('Belfry slat',(x,-2.35,z),(.43,.08,.055),brass,.008)
  box('Tower cornice',(x,-1.77,h+.03),(1.2,1.3,.16),stone)
  bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.78,radius2=0,depth=1.25,location=(x,-1.77,h+.75))
  finish(bpy.context.object,'Faceted slate spire',roofmat)
  beam('Spire finial',(x,-1.77,h+1.35),(x,-1.77,h+1.62),.035,brass)
  for side in [-1,1]:beam('Finial cross arm',(x,-1.77,h+1.52),(x+side*.12,-1.77,h+1.52),.025,brass)
 # Original rosette above the front portal, with radial metal tracery.
 cyl('Rosette glass',(0,-2.15,2.75),.36,.045,glass,24,'Y')
 torus('Rosette stone rim',(0,-2.21,2.75),.39,.07,stone,'Y')
 for i in range(8):
  a=i*math.tau/8;beam('Rosette radial lead',(0,-2.25,2.75),(.34*math.cos(a),-2.25,2.75+.34*math.sin(a)),.022,brass,8)
 for x in [-.75,.75]:
  box('Hanging crimson pennant',(x,-2.20,1.85),(.24,.035,.75),red,.008)
  beam('Pennant support',(x-.18,-2.24,2.25),(x+.18,-2.24,2.25),.025,brass)
 for k in range(3):box('Portal stone stair',(0,-2.40-k*.12,.34-k*.07),(1.3,.45,.16),stone)
 # Rear industrial sacristy makes the production function legible from behind.
 box('Rear armoury service enclosure',(0,2.53,1.05),(2.6,.45,1.3),dark)
 for x in [-.85,0,.85]:
  box('Rear forge service panel',(x,2.78,1.05),(.68,.06,.85),brass)
  for z in [.8,1,1.2]:box('Forge panel slot',(x,2.83,z),(.5,.04,.055),dark,.005)

def setup_materials(model):
 if model=='martian':return [material(model+' oxide red enamel',(.28,.035,.025),.71,.3,16),material(model+' cast iron',(.075,.085,.09),.68,.65,35),material(model+' worn copper',(.38,.19,.065),.59,.65,25),material(model+' soot concrete',(.18,.17,.14),.9,0,8),material(model+' black rubber',(.018,.022,.023),.93,0,28),material(model+' green monitor glass',(.09,.38,.17),.38,.2,80)]
 if model=='guard':return [material(model+' olive corrugated steel',(.16,.22,.10),.77,.3,18),material(model+' blackened steel',(.09,.10,.095),.66,.65,30),material(model+' dusty khaki plaster',(.38,.31,.20),.9,0,9),material(model+' worn foundation',(.21,.22,.18),.94,0,9),material(model+' crate timber',(.25,.13,.055),.88,0,9,(1,1,12)),material(model+' blue wireglass',(.12,.25,.31),.45,.2,60)]
 return [material(model+' warm carved limestone',(.61,.53,.39),.91,0,11),material(model+' weathered grey ashlar',(.22,.23,.22),.94,0,13),material(model+' oxblood slate',(.15,.035,.045),.87,.1,22),material(model+' aged bronze',(.34,.22,.08),.65,.6,30),material(model+' turquoise stained glass',(.07,.25,.32),.40,.15,40),material(model+' crimson woven pennant',(.33,.02,.035),.95,0,90,(1,1,3))]

def setup_scene():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
 s.render.threads_mode='FIXED';s.render.threads=12
 try:
  prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
  for device in prefs.devices:device.use=device.type!='CPU'
  s.cycles.device='GPU'
 except Exception:pass
 s.world=bpy.data.worlds.new('Neutral ambient daylight');s.world.use_nodes=True
 s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.56,.62,.7,1)
 s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
 s.view_settings.view_transform='AgX';s.render.film_transparent=True
 s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
 s.render.resolution_x=s.render.resolution_y=768;s.render.resolution_percentage=100
 return s

def bake_export(model,folder):
 source_components=None
 if bpy.context.scene.get('preserve_components'):
  source_components=bpy.data.collections.new('Editable source components - solo to edit')
  bpy.context.scene.collection.children.link(source_components)
  for original in PARTS:
   copy=original.copy();copy.data=original.data.copy();copy.name='SOURCE | '+original.name;source_components.objects.link(copy)
  source_components.hide_render=True;source_components.hide_viewport=True
 bpy.ops.object.select_all(action='DESELECT')
 for obj in PARTS:obj.select_set(True)
 bpy.context.view_layer.objects.active=PARTS[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 obj=bpy.context.object;obj.name=CONTRACTS[model]['label']+' | complete authored assembly'
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 # Bevelled thin plates can leave zero-area cap triangles. Clean the actual
 # source before UV/bake/export, preserving all positive-area construction.
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
 dead=[f for f in bm.faces if f.calc_area()<1e-10]
 if dead:bmesh.ops.delete(bm,geom=dead,context='FACES_ONLY')
 bm.to_mesh(obj.data);bm.free();obj.data.update()
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False)
 bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.006,area_weight=1.0,scale_to_bounds=True)
 bpy.ops.object.mode_set(mode='OBJECT')
 obj['source_parts']=len(PARTS);s=bpy.context.scene;s.cycles.bake_type='DIFFUSE';s.render.bake.use_pass_direct=False;s.render.bake.use_pass_indirect=False;s.render.bake.use_pass_color=True;s.render.bake.margin=8
 original=list(obj.data.materials);images={}
 for channel,bake_type in [('base-color','DIFFUSE'),('roughness','ROUGHNESS'),('normal','NORMAL'),('emission','EMIT')]:
  image=bpy.data.images.new(model+' '+channel,width=2048,height=2048,alpha=False)
  image.colorspace_settings.name='sRGB' if channel in ('base-color','emission') else 'Non-Color'
  for mat in original:
   nodes=mat.node_tree.nodes;node=nodes.new('ShaderNodeTexImage');node.image=image;nodes.active=node
  bpy.ops.object.bake(type=bake_type)
  image.filepath_raw=str(folder/(channel+'.png'));image.file_format='PNG';image.save();image.pack();images[channel]=image
 baked=bpy.data.materials.new(model+' baked PBR atlas');baked.use_nodes=True;n=baked.node_tree.nodes;l=baked.node_tree.links;p=n.get('Principled BSDF')
 for channel,socket in [('base-color','Base Color'),('roughness','Roughness')]:
  t=n.new('ShaderNodeTexImage');t.image=images[channel];l.new(t.outputs['Color'],p.inputs[socket])
 normal=n.new('ShaderNodeTexImage');normal.image=images['normal'];decode=n.new('ShaderNodeNormalMap');l.new(normal.outputs['Color'],decode.inputs['Color']);l.new(decode.outputs['Normal'],p.inputs['Normal'])
 emissionmap=n.new('ShaderNodeTexImage');emissionmap.image=images['emission'];l.new(emissionmap.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=1
 # Source materials retain their real metal channels; a dedicated metallic map
 # is baked as emission to preserve different metals and nonmetals in export.
 metalimage=bpy.data.images.new(model+' metallic',width=2048,height=2048,alpha=False);metalimage.colorspace_settings.name='Non-Color'
 for mat in original:
  nodes=mat.node_tree.nodes;links=mat.node_tree.links;principled=nodes.get('Principled BSDF');output=nodes.get('Material Output')
  emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=(principled.inputs['Metallic'].default_value,)*3+(1,)
  links.new(emission.outputs[0],output.inputs['Surface']);t=nodes.new('ShaderNodeTexImage');t.image=metalimage;nodes.active=t
 bpy.ops.object.bake(type='EMIT');metalimage.filepath_raw=str(folder/'metallic.png');metalimage.file_format='PNG';metalimage.save();metalimage.pack()
 for mat in original:
  mat.node_tree.links.new(mat.node_tree.nodes.get('Principled BSDF').outputs[0],mat.node_tree.nodes.get('Material Output').inputs['Surface'])
 t=n.new('ShaderNodeTexImage');t.image=metalimage;l.new(t.outputs['Color'],p.inputs['Metallic'])
 # Save editable procedural source BEFORE replacing material slots for GLB.
 obj['authorship']='Original project-authored building; no extracted Gladius geometry.'
 obj['footprint_tiles']=CONTRACTS[model]['tiles'];obj['front_axis']='-Y';obj['units']='metres / one Factorio tile per metre'
 if bpy.context.scene.get('servo_joint_frames'):obj['servo_joint_frames']=bpy.context.scene['servo_joint_frames']
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/(model+'-source.blend')))
 if source_components:bpy.context.scene.collection.children.unlink(source_components)
 for poly in obj.data.polygons:poly.material_index=0
 obj.data.materials.clear();obj.data.materials.append(baked)
 bpy.ops.export_scene.gltf(filepath=str(folder/(model+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_image_format='AUTO',export_extras=True)
 bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(folder/(model+'.glb')))
 imported=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert imported
 return imported

def inspect(objects,model):
 points=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
 low=[min(p[i] for p in points) for i in range(3)];high=[max(p[i] for p in points) for i in range(3)]
 # glTF importer restores Blender's Z-up frame; assert actual floor registration.
 for i in [0,1]:assert low[i]>=-CONTRACTS[model]['tiles']/2-.02 and high[i]<=CONTRACTS[model]['tiles']/2+.02,(model,low,high)
 assert low[2]>=-.015 and high[2]<=CONTRACTS[model]['height'],(low,high)
 triangles=0;bad=0;area=0;uv_area=0;textured_area=0
 for o in objects:
  mesh=o.data;mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
  for tri in mesh.loop_triangles:
   a,b,c=[o.matrix_world@mesh.vertices[j].co for j in tri.vertices];value=(b-a).cross(c-a).length/2
   area+=value
   if not math.isfinite(value) or value<1e-10:bad+=1
   if mesh.uv_layers.active:uv_area+=value
   mat=mesh.materials[mesh.polygons[tri.polygon_index].material_index]
   if mat and mat.use_nodes and any(n.type=='TEX_IMAGE' and n.image and min(n.image.size)>=128 for n in mat.node_tree.nodes):textured_area+=value
 assert triangles<160000 and bad/max(1,triangles)<.001,(triangles,bad)
 assert uv_area/area>=.98 and textured_area/area>=.98
 return dict(bounds_min=low,bounds_max=high,triangles=triangles,degenerate_triangles=bad,uv_area_fraction=uv_area/area,textured_area_fraction=textured_area/area,
             source_images=[{'name':i.name,'size':list(i.size),'pixels_loaded':i.has_data} for i in bpy.data.images if i.type=='IMAGE'])

def render_imported(objects,model,folder,samples):
 c=CONTRACTS[model];s=bpy.context.scene;s.cycles.samples=samples
 light=bpy.data.lights.new('Fixed Factorio sun','SUN');light.energy=3;light.angle=math.radians(4)
 sun=bpy.data.objects.new('Sun rays +4 +6 -8',light);s.collection.objects.link(sun);sun.rotation_euler=Vector((4,6,-8)).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('45 degree orthographic camera');cam=bpy.data.objects.new('Fixed entity capture',data);s.collection.objects.link(cam)
 target=Vector((0,0,c['target']));cam.location=target+Vector((0,-14,14));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=12;s.camera=cam
 bpy.ops.mesh.primitive_plane_add(size=200);ground=bpy.context.object;ground.name='Shadow catcher - excluded from GLB';ground.is_shadow_catcher=True
 ground.hide_render=True
 root=bpy.data.objects.new('Cardinal turntable',None);s.collection.objects.link(root)
 for o in objects:o.parent=root
 for lightobj in list(s.objects):
  if lightobj.type=='LIGHT' and lightobj!=sun:lightobj.parent=root
 render=folder/'renders';render.mkdir(exist_ok=True)
 def capture(path):s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 for i,name in enumerate(['north','east','south','west']):
  root.rotation_euler.z=-i*math.pi/2;bpy.context.view_layer.update();ground.hide_render=True
  capture(render/(name+'.png'))
  ground.hide_render=False
  for o in objects:o.visible_camera=False
  capture(render/(name+'-shadow.png'))
  for o in objects:o.visible_camera=True
  print('FACTORY_DIRECTION_READY',model,name,flush=True)
 ground.hide_render=True;root.rotation_euler.z=0
 cam.data.ortho_scale=c['tiles']*1.1;cam.location=Vector((0,-14,14))+Vector((0,0,c['target']));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 capture(render/'closeup.png')
 clay=material('Neutral geometry inspection',(.4,.4,.4),.8)
 s.view_layers[0].material_override=clay;cam.data.ortho_scale=12;capture(render/'clay.png');s.view_layers[0].material_override=None
 if s.get('servo_joint_frames'):
  target=Vector((.28,-1.23,1.50));cam.location=target+Vector((.4,-4,2));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.65
  capture(render/'servo-closeup.png')
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/(model+'-export-review.blend')))

def main():
 p=argparse.ArgumentParser();p.add_argument('--model',choices=list(CONTRACTS),required=True);p.add_argument('--samples',type=int,default=32)
 a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=OUT/a.model;folder.mkdir(parents=True,exist_ok=True)
 setup_scene();m=setup_materials(a.model)
 (folder/'surface-plan.json').write_text(json.dumps({'contract':CONTRACTS[a.model],
   'regions':[mat.name for mat in m],'maps':{'base-color':'sRGB','roughness':'Non-Color','normal':'Non-Color tangent','metallic':'Non-Color'},
   'texel_plan':'2048 atlas; area-weighted smart UV islands; 8 pixel bake dilation',
   'construction':'Separate manufactured parts, physically mounted ribs/pipes/fittings; no organic union requirement',
   'camera':'Fixed 45 degree orthographic; 64 source px/metre; 32 game px/tile',
   'icons':'Deferred by owner; do not generate inventory icons'},indent=2)+'\n')
 globals()[a.model](m)
 parts=len(PARTS);objects=bake_export(a.model,folder);bpy.context.view_layer.update();report=inspect(objects,a.model)
 render_imported(objects,a.model,folder,a.samples)
 report.update(model=a.model,label=CONTRACTS[a.model]['label'],authored_parts=parts,footprint_tiles=CONTRACTS[a.model]['tiles'],origin=[0,0,0],
   runtime=dict(size=768,scale=.5,shift=[0,-CONTRACTS[a.model]['target']/math.sqrt(2)],camera_elevation=45,sun_ray=[4,6,-8]),
   channels=['base-color','roughness','normal','metallic'],status='TECHNICAL_PASS_VISUAL_REVIEW_REQUIRED')
 report['sha256']={str(f.relative_to(folder)):hashlib.sha256(f.read_bytes()).hexdigest() for f in folder.rglob('*') if f.is_file() and f.suffix in ['.png','.glb','.blend']}
 (folder/'inspection.json').write_text(json.dumps(report,indent=2)+'\n')
 print('FACTORY_CANDIDATE_COMPLETE',a.model,parts,report['triangles'],flush=True)

if __name__=='__main__':main()
