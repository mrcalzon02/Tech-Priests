"""Fresh isolated native visual/power proof. Private stubs are not FX art."""
import argparse,hashlib,json,pathlib,shutil,struct,zlib
HERE=pathlib.Path(__file__).resolve().parent;REPO=HERE.parents[3];WORK=REPO.parent
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--no-assets',action='store_true');a=p.parse_args();out=a.out.resolve();assert out.parent==WORK/'local-validation' and not out.exists(),out
frozen=WORK/'local-validation/thruster-low-flange-mount-20261117';source=REPO/'tech-priests_src';mod=out/'mods/tp-visual-power-proof';mod.mkdir(parents=True);shutil.copytree(frozen/'mods/tech-priests',out/'mods/tech-priests');private=out/'mods/tech-priests'
binding=json.loads((frozen/'source-binding.json').read_text());binding['files'].update(json.loads((frozen/'mounting-source-binding.json').read_text())['updated_files'])
updated={}
for name in ('scripts/generated/control_legacy_part_002.lua','scripts/core/void_fusion_visuals.lua'):
    path=source/name;digest=sha(path);shutil.copy2(path,private/name);assert sha(path)==digest==sha(private/name);updated[name]=digest;binding['files'][name]=digest
assert sha(private/'control.lua')==binding['files']['control.lua']==sha(source/'control.lua')
# Read-only private test observation; no setter, registration call, operation
# resampling or sink/fluid mutation is exposed across the mod boundary.
wrapper="""\n-- PRIVATE NATIVE PROOF OBSERVER ONLY; ordinary source control.lua untouched.
local VisualProofSnapshot=require('scripts.core.void_fusion_visuals')
remote.add_interface('tp-visual-power-observer',{
 snapshot=function(unit)
  local records=storage.tech_priests and storage.tech_priests.void_fusion_thrusters
  local rec=records and records[unit]
  if not rec then return {registered=false,unit=unit}end
  local e=rec.thruster;local sink=rec.sink;local valid_sink=sink and sink.valid
  local operation;if rec.operation then operation={};for k,v in pairs(rec.operation)do operation[k]=v end end
  return {registered=true,unit=unit,operation=operation,
   visuals=VisualProofSnapshot.snapshot(rec),sink={valid=valid_sink==true,unit=valid_sink and sink.unit_number or false,
   energy=valid_sink and sink.energy or 0,power_watts=valid_sink and sink.power_usage*60 or 0},
   status=e.valid and e.status or false,fluid1=e.valid and e.get_fluid(1)or false,
   fluid2=e.valid and e.get_fluid(2)or false,platform_state=e.valid and e.surface.platform.state or false,
   platform_paused=e.valid and e.surface.platform.paused or false}
 end,
 render_objects=function()
  local out={};for _,o in pairs(rendering.get_all_objects('tech-priests'))do
   out[#out+1]={id=o.id,valid=o.valid,type=o.type,visible=o.visible,color=o.color}
  end;return out
 end
})
"""
with (private/'control.lua').open('a',encoding='utf-8')as f:f.write(wrapper)
(mod/'info.json').write_text(json.dumps({'name':'tp-visual-power-proof','version':'0.0.1','title':'Private visual power API proof','author':'Local validation','factorio_version':'2.1','dependencies':['base','space-age','tech-priests']},indent=2)+'\n')
if not a.no_assets:shutil.copy2(HERE/'control.lua',mod/'control.lua')
else:
    text=(HERE/'control.lua').read_text().split('script.on_event(defines.events.on_tick')[0]
    text=text.replace("assert(helpers.is_valid_animation_path(prefix..'-energy-v01')and helpers.is_valid_animation_path(prefix..'-plume-v01'),'Actual native animation stub unavailable')","assert(not helpers.is_valid_animation_path(prefix..'-energy-v01')and not helpers.is_valid_animation_path(prefix..'-plume-v01'),'Unexpected optional visual asset')")
    text+='''script.on_event(defines.events.on_tick,function()
 local t=game.tick-storage.start
 if t==120 then for _,row in ipairs(storage.rows)do power(row)end end
 if t==600 then local result={status='NO_OPTIONAL_ASSETS_ACTUAL_NATIVE_SAMPLES',rows={},objects=objects()}
  for _,row in ipairs(storage.rows)do local s=snapshot(row,t);s.platform_speed=row.platform.speed;result.rows[#result.rows+1]=s end
  write('continuous-results',result)
 end
end)
'''
    (mod/'control.lua').write_text(text)
# Tiny64-frame1px actual PNG: just exercises native animation paths/objects.
def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',64,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0'+bytes((32,96,48,255))*64))+chunk(b'IEND',b'');(mod/'stub.png').write_bytes(png)
data=(frozen/'mods/thruster-resume-proof/data.lua').read_text()+"\nlocal rows={}\n"
for family in (()if a.no_assets else('void-fusion-thruster','large-void-fusion-thruster')):
    for lane in ('energy','plume'):
        name='tp-'+family+'-'+lane+'-v01';data+="rows[#rows+1]={type='animation',name='"+name+"',filename='__tp-visual-power-proof__/stub.png',width=1,height=1,line_length=64,frame_count=64,animation_speed=32/60,apply_runtime_tint=true,blend_mode='additive'}\n"
data+='if #rows>0 then data:extend(rows)end\n';(mod/'data.lua').write_text(data)
shutil.copy2(frozen/'mods/mod-settings.dat',out/'mods/mod-settings.dat');(out/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True}for n in ('base','quality','elevated-rails','space-age','tech-priests','tp-visual-power-proof')]},indent=2)+'\n')
(out/'user-data').mkdir();(out/'config.ini').write_text('[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\nwrite-data='+str(out/'user-data').replace('\\','/')+'\n[other]\ncheck-updates=false\n');shutil.copy2(frozen/'map-gen.json',out/'map-gen.json');(out/'steam_appid.txt').write_text('427520\n')
proof={'status':'PREPARED_REQUIRES_ACTUAL_NATIVE_CREATE_BENCHMARK_AND_RELOAD','frozen_baseline':str(frozen),'updated_runtime_source_hashes':updated,'ordinary_control_sha256':sha(source/'control.lua'),'private_control_observer_sha256':sha(private/'control.lua'),'observer_scope':'READONLY snapshot only; private frozen control append. Ordinary control/runtime sources unchanged.','fixture_control_sha256':sha(mod/'control.lua'),'fixture_data_sha256':sha(mod/'data.lua'),'stub_png_sha256':sha(mod/'stub.png'),'scope':'Actual ordinary registered sealed drives, real sink draw/fluids and native LuaRenderObject IDs/RGBA/visibility/lifecycle. Tiny1px64frame private stub is explicitly not FX pixel appearance proof.','source_binding':binding}
proof['optional_animation_assets_present']=not a.no_assets
(out/'preparation.json').write_text(json.dumps(proof,indent=2)+'\n');print('VISUAL_NATIVE_PRIVATE_PROFILE_PREPARED',out)
