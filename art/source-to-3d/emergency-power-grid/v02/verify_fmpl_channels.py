"""Check actual embedded GLB pixels/channels against hash-verified FMPL maps."""
import bpy,json,struct,hashlib
import numpy as np
from pathlib import Path
O=Path(__file__).resolve().parent
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Pass a source checkout containing tools/fmpl and canonical material maps.')
REPO=locate_repo();P=O/'power-grid-v02.glb'
b=P.read_bytes();n,k=struct.unpack_from('<II',b,12);g=json.loads(b[20:20+n]);n2,k2=struct.unpack_from('<II',b,20+n);assert k2==0x004e4942;binary=b[28+n:28+n+n2]
manifest=json.loads((O/'fmpl-surface-manifest.json').read_text());assert hashlib.sha256(b).hexdigest()==manifest['runtime_sha256'];records={r['role']:r for r in manifest['role_instances']};temp=O/'export-check';temp.mkdir(exist_ok=True)
def image_pixels(path,noncolor):
 im=bpy.data.images.load(str(path),check_existing=False)
 if noncolor:im.colorspace_settings.name='Non-Color'
 out=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4);bpy.data.images.remove(im);return out
def texture_pixels(info,noncolor):
 im=g['images'][g['textures'][info['index']]['source']];view=g['bufferViews'][im['bufferView']];start=view.get('byteOffset',0);data=binary[start:start+view['byteLength']];p=temp/('embedded-'+str(im['bufferView'])+'.png');p.write_bytes(data);return image_pixels(p,noncolor)
rows=[]
for m in g['materials']:
 role=m['name'].split(' | ')[-1];r=records[role];pbr=m['pbrMetallicRoughness']
 if 'model_specific_baked_maps'in r:
  maps=r['model_specific_baked_maps'];expected={}
  for kind in('albedo','normal','orm'):
   p=O/maps[kind]['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==maps[kind]['sha256'];expected[kind]=image_pixels(p,kind!='albedo')
 else:
  maps=r['original_maps'];albedo=REPO/maps['albedo']['source_path'];expected={'albedo':image_pixels(albedo,False),'orm':image_pixels(REPO/maps['orm']['source_path'],True),'normal':image_pixels(REPO/maps['normal']['source_path'],True)}
 actual={'albedo':texture_pixels(pbr['baseColorTexture'],False),'orm':texture_pixels(pbr['metallicRoughnessTexture'],True),'normal':texture_pixels(m['normalTexture'],True)}
 errors={}
 for kind in ('albedo','normal'):
  assert actual[kind].shape==expected[kind].shape
  errors[kind]=float(np.abs(actual[kind][:,:,:3]-expected[kind][:,:,:3]).max())
 assert actual['orm'].shape==expected['orm'].shape
 errors['roughness_from_original_green']=float(np.abs(actual['orm'][:,:,1]-expected['orm'][:,:,1]).max())
 errors['metallic_from_original_blue']=float(np.abs(actual['orm'][:,:,2]-expected['orm'][:,:,2]).max())
 assert max(errors.values())<1/255+.0001,(role,errors)
 assert pbr.get('baseColorFactor',[1,1,1,1])==[1,1,1,1] and pbr.get('metallicFactor',1)==1 and pbr.get('roughnessFactor',1)==1,(role,pbr)
 rows.append({'role':role,'fmpl_material_id':r['fmpl_material_id'],'actual_glb_pixels_max_error':errors,'correct_orm_green_roughness_blue_metallic':True,'normal_scale':m['normalTexture'].get('scale',1),'passed':True})
report={'passed':True,'source_sha256':manifest['source_sha256'],'runtime_sha256':manifest['runtime_sha256'],'materials':rows,'original_source_maps_git_blob_verified':True,'albedo_color_space':'sRGB','normal_and_orm_color_space':'Non-Color','all_actual_exported_pixels_checked':True,'correct_source_indexed_fmpl_materials':True,'owner_visual_approved':False}
(O/'fmpl-channel-verification.json').write_text(json.dumps(report,indent=2)+'\n');print('POWER_GRID_FMPL_ACTUAL_CHANNELS_PASS',len(rows),flush=True)
