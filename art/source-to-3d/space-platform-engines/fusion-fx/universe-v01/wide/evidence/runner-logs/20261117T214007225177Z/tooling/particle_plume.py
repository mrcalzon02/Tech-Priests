"""Bounded seeded advecting particle/wisp capture rig, never a fluid simulation.

Particles accelerate away from the measured field origin, spread, and fade
through their lifetimes. Every recycled particle is invisible at its birth and
death boundary. No rings, connected trails, tubes, or global brightness sine.
"""
import hashlib,math,random

def _material(name,volume=False,violent=False):
 import bpy
 m=bpy.data.materials.new(name);m.use_nodes=True;nt=m.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial')
 if volume:
  coord=nt.nodes.new('ShaderNodeTexCoord');mapping=nt.nodes.new('ShaderNodeMapping');mapping.name='LOCAL_TURBULENCE';nt.links.new(coord.outputs['Generated'],mapping.inputs['Vector'])
  noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4.8;noise.inputs['Detail'].default_value=3;nt.links.new(mapping.outputs['Vector'],noise.inputs['Vector'])
  distance=nt.nodes.new('ShaderNodeVectorMath');distance.operation='DISTANCE';distance.inputs[1].default_value=(.5,.5,.5);nt.links.new(coord.outputs['Generated'],distance.inputs[0])
  falloff=nt.nodes.new('ShaderNodeMapRange');falloff.clamp=True;falloff.interpolation_type='SMOOTHERSTEP';falloff.inputs['From Min'].default_value=.22;falloff.inputs['From Max'].default_value=.48;falloff.inputs['To Min'].default_value=1;falloff.inputs['To Max'].default_value=0;nt.links.new(distance.outputs['Value'],falloff.inputs['Value'])
  fade=nt.nodes.new('ShaderNodeValue');fade.name='LIFETIME_FADE';fade.outputs[0].default_value=0
  mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';nt.links.new(noise.outputs['Fac'],mul.inputs[0]);nt.links.new(falloff.outputs['Result'],mul.inputs[1])
  density=nt.nodes.new('ShaderNodeMath');density.operation='MULTIPLY';nt.links.new(mul.outputs[0],density.inputs[0]);nt.links.new(fade.outputs[0],density.inputs[1])
  shader=nt.nodes.new('ShaderNodeVolumePrincipled');shader.inputs['Color'].default_value=(.025,.22,.004,1);shader.inputs['Anisotropy'].default_value=.15;shader.inputs['Emission Color'].default_value=(.025,1,.002,1)
  glow=nt.nodes.new('ShaderNodeMath');glow.operation='MULTIPLY';glow.inputs[1].default_value=6.5 if violent else 4.5;nt.links.new(density.outputs[0],glow.inputs[0]);nt.links.new(density.outputs[0],shader.inputs['Density']);nt.links.new(glow.outputs[0],shader.inputs['Emission Strength']);nt.links.new(shader.outputs[0],out.inputs['Volume'])
 else:
  emission=nt.nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=(.10,1,.012,1) if violent else (.20,1,.04,1);emission.inputs['Strength'].default_value=3.2 if violent else 1.8
  transparent=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader');fade=nt.nodes.new('ShaderNodeValue');fade.name='LIFETIME_FADE';fade.outputs[0].default_value=0;nt.links.new(fade.outputs[0],mix.inputs[0]);nt.links.new(transparent.outputs[0],mix.inputs[1]);nt.links.new(emission.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface'])
 return m

def build_particle_plume(*,family,origin,axis,aperture_radius,seed=731,length=2.0,particles=24,wisps=12,violent=False):
 import bpy
 from mathutils import Vector
 assert len(origin)==len(axis)==3 and length>0 and aperture_radius>0
 rng=random.Random(seed);a=Vector(axis).normalized();ref=Vector((1,0,0))
 if abs(a.dot(ref))>.95:ref=Vector((0,0,1))
 u=a.cross(ref).normalized();v=a.cross(u).normalized();collection=bpy.data.collections.new('CAPTURE_ADVECTING_PLUME | '+family);bpy.context.scene.collection.children.link(collection);objects=[]
 def create(name,volume):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if volume else 1,radius=1);o=bpy.context.object;o.name=name
  for c in list(o.users_collection):c.objects.unlink(o)
  collection.objects.link(o);o.data.materials.append(_material(name+' lifetime',volume,violent));o.hide_render=True;return o
 for i in range(particles+wisps):
  volume=i>=particles;o=create(('Advecting turbulent wisp 'if volume else'Accelerating ejecta particle ')+str(i),volume)
  angle=rng.random()*math.tau;direction=(u*math.cos(angle)+v*math.sin(angle));index=i-particles if volume else i;count=wisps if volume else particles;entry={'object':o.name,'volume':volume,'birth_phase':(index/count+rng.uniform(-.003,.003))%1,'lateral':[float(x)for x in direction],'radial_seed':rng.random(),'twist_phase':rng.random()*math.tau,'size':rng.uniform(.025,.065)if violent and not volume else rng.uniform(.22,.46)if violent else rng.uniform(.007,.015)if not volume else rng.uniform(.09,.16),'discharge_shard':violent and not volume and i%3==0};objects.append(entry)
 core=create('Compact aperture-fed ionization volume',True);objects.append({'object':core.name,'volume':True,'core':True,'birth_phase':0,'lateral':[0,0,0],'radial_seed':0,'twist_phase':0,'size':.065})
 receipt={'schema':'advecting_particle_plume_v1','family':family,'collection':collection.name,'objects':objects,'origin':list(origin),'axis':list(a),'basis_u':list(u),'basis_v':list(v),'aperture_radius':aperture_radius,'length':length,'lifetime_seconds':2.0,'seed':seed,'particle_count':particles,'wisp_count':wisps,'aperture_core_count':1,'brightness_contract':'Normalized at18MWpeak. Only individual lifetimefade/turbulence; nativeactual power helper owns wholeengine brightness.','method':'Compact actual-origin ionization core feeding3D glints + soft interior-falloff noisy volume billows; positive axial acceleration, bounded dispersion, invisible lifecycle recycling; no fluid bake or attached loop/tube.'}
 receipt['violent_discharge']=violent
 if violent:receipt['method']='Tortured-universe discharge: broad advecting luminous ion billows, large accelerating glints and disconnected branching lightning shards. Hot aperture-fed core; increasing downstream dispersion and invisible birth/death. No attached tubes, closed loops, physical fluid bake or background refraction.'
 set_particle_plume_phase(receipt,0);return receipt

def set_particle_plume_phase(receipt,phase):
 import bpy
 from mathutils import Vector
 phase=phase%1;a=Vector(receipt['axis']);u=Vector(receipt['basis_u']);v=Vector(receipt['basis_v']);origin=Vector(receipt['origin']);result=[]
 for item in receipt['objects']:
  if item.get('core'):
   violent=receipt.get('violent_discharge',False);o=bpy.data.objects[item['object']];o.location=origin+a*(.20 if violent else .035);o.rotation_euler=a.to_track_quat('Z','Y').to_euler();r=receipt['aperture_radius']*1.8 if violent else min(.065,receipt['aperture_radius']*.60);o.scale=(r,r,.60 if violent else .11);o.data.materials[0].node_tree.nodes['LIFETIME_FADE'].outputs[0].default_value=4.5 if violent else 2.2;o.data.materials[0].node_tree.nodes['LOCAL_TURBULENCE'].inputs['Location'].default_value=(.05*math.sin(math.tau*phase),.05*math.cos(math.tau*phase),.06*math.sin(2*math.tau*phase));result.append({'object':o.name,'age_fraction':None,'axial_distance':.20 if violent else .035,'position':list(o.location),'fade':1.0,'material_gain':4.5 if violent else 2.2,'volume':True,'core':True});continue
  age=(phase-item['birth_phase'])%1
  # Faster downstream travel as age increases, not an object wobbling in place.
  distance=receipt['length']*(.22*age+.78*age*age)
  violent=receipt.get('violent_discharge',False)
  lateral=Vector(item['lateral']);spread=receipt['aperture_radius']*.55+((.65 if item['volume']else .95)if violent else(.16 if item['volume']else .22))*(age**1.2)
  drift=lateral*spread*(.2+.8*item['radial_seed'])
  turbulence=(u*math.sin(age*8.5+item['twist_phase'])+v*math.sin(age*11.3+item['twist_phase']*.71))*(age*(.14 if violent else .025))
  position=origin+a*distance+drift+turbulence
  onset=min(1,age/.08);tail=max(0,min(1,(1-age)/.35));fade=onset*onset*(3-2*onset)*tail*tail*(3-2*tail)
  o=bpy.data.objects[item['object']];o.location=position;o.rotation_euler=a.to_track_quat('Z','Y').to_euler()
  if item['volume']:
   r=item['size']*(.22+1.5*age);o.scale=(r,r*.82,min(r*((1.5 if violent else .9)+age*1.6),max(.015,(receipt['length']-distance)*.7)));amount=fade*(.75+.25*math.sin(age*6+item['twist_phase']))*(5.0 if violent else 3.0)
   mapping=o.data.materials[0].node_tree.nodes['LOCAL_TURBULENCE'];mapping.inputs['Location'].default_value=(age*.18,age*-.25,age*.35)
  else:
   r=item['size']*(.8+.35*age);o.scale=(r,r,r*(2+age*8 if violent else 1+age*2));amount=fade
   if item.get('discharge_shard'):
    # Freely travelling forked flashes, rebuilt every short local burst. Their
    # centroid obeys the same strictly downstream accelerating lifecycle.
    burst=int(age*28);rr=random.Random(int(item['twist_phase']*100000)+burst)
    pts=[Vector((0,0,-1.4))]+[Vector((rr.uniform(-.55,.55),rr.uniform(-.4,.4),-1.4+j*.4))for j in range(1,7)]+[Vector((0,0,1.4))]
    branches=[pts,[pts[3],pts[3]+Vector((.65,-.25,.3)),pts[3]+Vector((1.3,-.5,.7))]];vertices=[];faces=[]
    for path in branches:
     for q,w in zip(path,path[1:]):
      edge=w-q;normal=edge.cross(Vector((0,1,0))).normalized()*.10;k=len(vertices);vertices.extend([q-normal,q+normal,w+normal,w-normal]);faces.append((k,k+1,k+2,k+3))
    o.data.clear_geometry();o.data.from_pydata(vertices,[],faces);o.data.update();o.scale=(r*3,r*3,r*5)
  o.data.materials[0].node_tree.nodes['LIFETIME_FADE'].outputs[0].default_value=amount
  result.append({'object':o.name,'age_fraction':age,'axial_distance':distance,'position':list(position),'fade':fade,'material_gain':amount,'volume':item['volume'],'core':False})
 return result
