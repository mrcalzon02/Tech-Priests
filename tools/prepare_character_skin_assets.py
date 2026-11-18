"""Install the locally prepared, attributed art and generate its shared catalog."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parents[1]/'deps'))
from PIL import Image

NAMES={
 'Battle-Sister':('battle-sister','Battle Sister','Sisters of Battle'),
 'Canoness':('canoness','Canoness','Sisters of Battle'),
 'Cybernetica-Datasmith':('datasmith','Cybernetica Datasmith','Adeptus Mechanicus'),
 'Dialogus':('dialogus','Dialogus','Sisters of Battle'),
 'Guardsman':('guardsman','Guardsman','Astra Militarum'),
 'Imperial-Officer':('imperial-officer','Imperial Officer','Astra Militarum'),
 'Kataphron-Breacher':('kataphron-breacher','Kataphron Breacher','Adeptus Mechanicus'),
 'Kataphron-Destroyer':('kataphron-destroyer','Kataphron Destroyer','Adeptus Mechanicus'),
 'Lord-Commissar':('lord-commissar','Lord Commissar','Astra Militarum'),
 'Skitarii-Marshal':('skitarii-marshal','Skitarii Marshal','Adeptus Mechanicus'),
 'Skitarii-Ranger':('skitarii-ranger','Skitarii Ranger','Adeptus Mechanicus'),
 'Skitarii-Vanguard':('skitarii-vanguard','Skitarii Vanguard','Adeptus Mechanicus'),
 'Tech-Priest-Dominus':('dominus','Tech-Priest Dominus','Adeptus Mechanicus'),
 'Tech-Priest-Enginseer':('enginseer','Tech-Priest Enginseer','Adeptus Mechanicus'),
 'Tech-Priest-Manipulus':('manipulus','Tech-Priest Manipulus','Adeptus Mechanicus'),
}

def lua(v):
 if isinstance(v,dict): return '{'+','.join('['+json.dumps(str(k))+']='+lua(value) for k,value in v.items())+'}'
 if isinstance(v,list): return '{'+','.join(lua(x) for x in v)+'}'
 if isinstance(v,str): return json.dumps(v)
 if isinstance(v,bool): return 'true' if v else 'false'
 if v is None:return 'nil'
 return repr(v)

def main():
 p=argparse.ArgumentParser()
 p.add_argument('--source',type=Path,required=True)
 p.add_argument('--model',choices=sorted(NAMES),help='Replace one verified model while preserving all other catalog entries')
 a=p.parse_args()
 target=ROOT/'tech-priests_src/graphics/entity/gladius-donors'
 icons=ROOT/'tech-priests_src/graphics/icons/character-skins'
 icons.mkdir(parents=True,exist_ok=True)
 catalog=[]
 for directory,(identifier,label,faction) in NAMES.items():
  if a.model and directory!=a.model:continue
  src=a.source/directory
  info=json.loads((src/'render-manifest.json').read_text())
  qa=json.loads((src/'team-colour-verification.json').read_text())
  dest=target/directory
  dest.mkdir(parents=True,exist_ok=True)
  states={}
  for state,clip in info['states'].items():
   check=qa['states'][state]
   assert check['unmasked_pixels_unchanged'] and check['shadow_identical_to_v1']
   for filename,key in ((state+'.png','body_sha256'),(state+'-team-colour.png','team_colour_sha256')):
    source=src/filename
    assert hashlib.sha256(source.read_bytes()).hexdigest()==check[key]
    shutil.copy2(source,dest/filename)
   shutil.copy2(src/(state+'-shadow.png'),dest/(state+'-shadow.png'))
   states[state]={'scale':clip.get('scale',info['scale']),'shift':clip.get('shift',info['shift']),
                  'speed':clip['animation_speed'],'duration':clip['duration_seconds']}
  shutil.copy2(src/'SOURCE_ATTRIBUTION.txt',dest/'SOURCE_ATTRIBUTION.txt')
  # Actual source crop, not a separately generated portrait or invented artwork.
  size=info['cell_size'][0]
  box=(0,4*size,size,5*size)
  base=Image.open(src/'idle.png').convert('RGBA').crop(box)
  mask=Image.open(src/'idle-team-colour.png').convert('RGBA').crop(box)
  channels=mask.split()
  mask=Image.merge('RGBA',(channels[0].point(lambda x:round(x*.9)),channels[1].point(lambda x:round(x*.1)),channels[2].point(lambda x:round(x*.06)),channels[3]))
  portrait=Image.alpha_composite(base,mask)
  bounds=portrait.getchannel('A').getbbox()
  assert bounds
  portrait=portrait.crop(bounds)
  portrait.thumbnail((112,112),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(128,128))
  canvas.alpha_composite(portrait,((128-portrait.width)//2,(128-portrait.height)//2))
  canvas.save(icons/(identifier+'.png'))
  catalog.append({'id':identifier,'label':label,'faction':faction,'directory':directory,'size':size,
                  'frames':info['frames'],'states':states,'character':'tech-priests-skin-'+identifier})
  print('SKIN_ASSETS',identifier,flush=True)
 library=ROOT/'tech-priests_src/shared'
 library.mkdir(exist_ok=True)
 ranks={'junior':'enginseer','intermediate':'datasmith','senior':'manipulus','planetary-magos':'dominus','void':'dominus'}
 if a.model:
  path=library/'character_skin_catalog.lua';text=path.read_text(encoding='utf-8')
  row=catalog[0];start=text.index('{["id"]='+json.dumps(row['id']))
  depth=0;quoted=False;escaped=False;end=None
  for i in range(start,len(text)):
   char=text[i]
   if quoted:
    if escaped:escaped=False
    elif char=='\\':escaped=True
    elif char=='"':quoted=False
   elif char=='"':quoted=True
   elif char=='{':depth+=1
   elif char=='}':
    depth-=1
    if depth==0:end=i+1;break
  assert end is not None
  path.write_text(text[:start]+lua(row)+text[end:],encoding='utf-8')
  print('REPLACED_ONE_CATALOG_ENTRY',row['id'])
  return
 (library/'character_skin_catalog.lua').write_text('''-- Original models: Proxy Studios. Publisher: Slitherine Ltd.
-- All rights and copyrights remain theirs or Games Workshop, as applicable.
-- Generated from the verified native SIC-blue masked sprite export.
local M={skins='''+lua(catalog)+',ranks='+lua(ranks)+'''}
M.by_id={}
for _,skin in ipairs(M.skins) do M.by_id[skin.id]=skin end
function M.allowed(id,startup)
 if id=="vanilla" then return true end
 if not M.by_id[id] then return false end
 local flag=startup and startup["tech-priests-skin-allow-"..id]
 return not flag or flag.value~=false
end
return M
''',encoding='utf-8')
 shutil.copy2(a.source/'SOURCE_ATTRIBUTION.txt',ROOT/'tech-priests_src/THIRD-PARTY-NOTICES-GLADIUS.txt')
 print(json.dumps({'skins':len(catalog),'ranks':ranks}))

if __name__=='__main__':main()
