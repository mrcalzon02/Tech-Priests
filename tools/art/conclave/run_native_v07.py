"""Reuse the native container test in a separate V07 sandbox and capture motion."""
from pathlib import Path
import sys
P=Path(__file__).resolve().parent
revision=sys.argv[sys.argv.index('--revision')+1] if '--revision' in sys.argv else 'v07'
assert revision in ('v07','v08')
src=(P/'run_native.py').read_text().replace('build/conclave-native-v01','build/conclave-native-'+revision).replace("'native-control.lua'","'native-"+revision+"-control.lua'").replace("['native-close.png','native-gameplay.png']","['native-close.png','native-gameplay.png','native-motion-035.png','native-night.png','native-ghost.png']" if revision=='v08' else "['native-close.png','native-gameplay.png','native-motion-035.png']")
control=(P/'native-control.lua').read_text()
control=control.replace("helpers.table_to_json(status.caption)","(type(status.caption)=='table' and helpers.table_to_json(status.caption) or tostring(status.caption))")
# This run observes art, not a physical owner click: never infer that gate from
# the console opening automatically during ordinary test activity.
control=control.replace('storage.checks.physical_gui_observed=true','storage.checks.gui_present_during_automation=true')
anchor='end)\nscript.on_event(defines.events.on_player_created'
insert=""" if t>=1300 and t<=2000 and (t-1300)%20==0 then
  local p=game.players[1]
  if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={0,-0.5586143571373725},resolution={640,640},zoom=4,path=string.format('conclave-center/native-motion-%03d.png',(t-1300)/20),show_gui=false,show_entity_info=false,allow_in_replay=true} end
 end
end)
script.on_event(defines.events.on_player_created"""
assert control.count(anchor)==1
control=control.replace(anchor,insert)
if revision=='v08':
 control=control.replace('local e=storage.sites[1].entity',"s.create_entity{name=ID,position={0,6},force='player',raise_built=true}\n s.create_entity{name='entity-ghost',inner_name=ID,position={4,6},force='player'}\n local e=storage.sites[1].entity",1)
 control=control.replace('position={0,-0.5586143571373725}', 'position={0,5.4413856428626275}')
 control=control.replace(' if t>=1300'," if t==2010 then local surface=game.surfaces[1];surface.always_day=false;surface.daytime=0.5;surface.freeze_daytime=true end\n if t==2070 then local p=game.players[1];if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={0,5.4413856428626275},resolution={640,640},zoom=4,path='conclave-center/native-night.png',show_gui=false,show_entity_info=false} end end\n if t>=1300")
 control=control.replace(' if t>=1300'," if t==2090 then game.surfaces[1].always_day=true end\n if t==2120 then local p=game.players[1];if p then game.take_screenshot{player=p,surface=game.surfaces[1],position={2,5.4413856428626275},resolution={1000,640},zoom=3,path='conclave-center/native-ghost.png',show_gui=false,show_entity_info=false} end end\n if t>=1300")
(P/('native-'+revision+'-control.lua')).write_text(control)
if len(sys.argv)>1 and sys.argv[1]=='capture':
 folder=P.parents[2]/('build/conclave-native-'+revision+'/user-data/script-output/conclave-center')
 for screenshot in folder.glob('native-*.png'):
  assert screenshot.resolve().parent==folder.resolve();screenshot.unlink()
exec(compile(src,str(P/'run_native.py'),'exec'))
