"""Portable nonnegative morph weights, preserving every authored source frame."""
def normalize_flame_keys(scene):
 for ob in scene.objects:
  if ob.type!='MESH' or 'animated flame' not in ob.name:continue
  keys=ob.data.shape_keys
  if keys.key_blocks.get('Waver opposite across arch'):continue
  sx=keys.key_blocks['Waver across arch'];sy=keys.key_blocks['Waver fore and aft'];basis=keys.key_blocks['Basis'];values=[]
  for frame in range(1,290):
   scene.frame_set(frame);values.append((frame,sx.value,sy.value))
  nx=ob.shape_key_add(name='Waver opposite across arch');ny=ob.shape_key_add(name='Waver opposite fore and aft')
  for j,v in enumerate(basis.data):nx.data[j].co=2*v.co-sx.data[j].co;ny.data[j].co=2*v.co-sy.data[j].co
  keys.animation_data_clear();sx.slider_min=0;sy.slider_min=0
  for frame,x,y in values:
   for key,value in ((sx,max(0,x)),(nx,max(0,-x)),(sy,max(0,y)),(ny,max(0,-y))):key.value=value;key.keyframe_insert('value',frame=frame)
 scene.frame_set(1)
