"""Compose accepted machinery and live-stock adapters into a normal-game addon."""
import argparse
import json
import math
from pathlib import Path
import shutil
from PIL import Image,ImageDraw
from run_compressor_native_jig import lua,sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--repo',default='.');ap.add_argument('--debug-counters',action='store_true');ap.add_argument('--purifier-capture',required=True);ap.add_argument('--resource-icon-root')
    args=ap.parse_args();repo=Path(args.repo).resolve();out=Path(args.out).resolve();here=Path(__file__).resolve().parent
    if out.exists():raise FileExistsError('Preserve integration candidates')
    out.mkdir(parents=True);mod=out/'tp-hydrogen-production_0.1.0';mod.mkdir();family=repo/'art/source-to-3d/metallic-hydrogen-chain';audio=repo/'art/source-to-3d/shared-audio/hydrogen-machinery'
    for folder in ('machines','graphics','icons','sound'): (mod/folder).mkdir()
    records=[];specs=[]
    def port(id,kind,fluid,position,direction):return dict(id=id,production_type=kind,fluid=fluid,color=[.3,.6,.75],position=position,direction=direction)
    def base(key,entity,category,recipe,cycle,size,camera_z,ortho,shift=4):
        return dict(key=key,mod_id='tp-hydrogen-production',entity=entity,title=key,category=category,recipe=recipe,recipe_seconds=cycle,cycle_seconds=cycle,frame_count=8,
            collision_box=[[-size[0]/2+.2,-size[1]/2+.2],[size[0]/2-.2,size[1]/2-.2]],selection_box=[[-size[0]/2,-size[1]/2],[size[0]/2,size[1]/2]],ports=[],body_render_layer='object',sprite_scale=ortho/8,sprite_shift_y=-camera_z*math.sqrt(.5)+shift/32,primary_animation_clock=True,exact_tick_clock=True,exact_animation_speed=.5 if cycle==4 else .25)
    purifier=base('purifier','tp-mh7-review-purifier','tp-mh7-review-purifying','tp-mh7-review-purify',4,[3,3],1.65,5.8,4)
    purifier['body_render_layer']='object';purifier['ports']=[port('raw-water','input','water',[-1,0],'west'),port('purified-water','output','tp-mh7-review-purified-water',[1,0],'east')]
    electro=base('electrolyzer','tp-mh7-review-electrolyzer','tp-mh7-review-electrolysis','tp-mh7-review-electrolyze',4,[3,4],1.3,6.35)
    electro['body_render_layer']='lower-object';electro['ports']=[port('water','input','tp-mh7-review-purified-water',[0,1.5],'south'),port('hydrogen','output','tp-mh7-review-hydrogen-gas',[-1,-.5],'west'),port('oxygen','output','tp-mh7-review-oxygen-gas',[1,-.5],'east')]
    sources=[('purifier',purifier,'water-purifier/v16-owner-accepted',None),('electrolyzer',electro,'electrolyzer/v06-owner-accepted-native','review-mod/tp-mh7-electrolyzer-review_0.0.1')]
    for key,folder,prototype in [
        ('compressor','hydrogen-compressor/v06-owner-accepted-native','review-mod/tp-mh7-compressor-review_0.0.1'),
        ('crucible','metallization-crucible/v04-native-production','review-mod/tp-mh7-crucible-review_0.0.1'),
        ('forge','pelletization-forge/v04-native-preservation','prototype-mod/tp-mh7-forge-review_0.0.1'),
        ('fabricator','pressure-vessel-fabricator/v04-native-review','prototype-mod/tp-mh7-fabricator-review_0.0.1'),
        ('assembler','canister-assembler/v04-native-preservation','prototype-mods/tp-mh7-assembler_0.0.1')]:
        spec=json.loads((family/folder/'spec.json').read_text());spec.update(key=key,mod_id='tp-hydrogen-production',recipe_seconds=spec['cycle_seconds'],primary_animation_clock=True,exact_tick_clock=True,exact_animation_speed=.25)
        spec.setdefault('frame_count',8);spec.pop('fixture_product_quality',None);sources.append((key,spec,folder,prototype))
    native=(here/'native_machine_review_data.lua').read_text()
    native=native.replace('-- Spec-driven isolated native art fixture. No ordinary mod/economy edits.','-- Source-derived production builder; retain accepted sprites and actual ports.')
    native=native[:native.index("if spec.item_product then\n local picker")]
    native=native.replace("local spec=require('spec')",'return function(spec)')
    native=native.replace('spec.exact_tick_clock and .25','spec.exact_tick_clock and (spec.exact_animation_speed or .25)')
    native=native.replace('spec.cycle_seconds*60/4','spec.cycle_seconds*60*animation_speed').replace('spec.cycle_seconds*60/frame_count/4','spec.cycle_seconds*60/frame_count*animation_speed')
    native=native.replace("'__/graphics/'..state", "'__/graphics/'..spec.key..'/'..state").replace("'__/graphics/animation-clock.png'","'__/graphics/'..spec.key..'/animation-clock.png'").replace("'__/graphics/rear-collar-'..direction","'__/graphics/'..spec.key..'/rear-collar-'..direction")
    if native.count("'__/graphics/'..spec.key")!=3:raise RuntimeError('Machine graphic namespace adaptation failed')
    native+='\nend\n';(mod/'machine.lua').write_text(native,encoding='utf-8')
    for key,spec,folder,prototype in sources:
        specs.append(spec);asset=family/folder;graphics=mod/'graphics'/key;graphics.mkdir();capture_manifest=asset/'captures/capture.json'
        if prototype:shutil.copytree(asset/prototype/'graphics',graphics,dirs_exist_ok=True)
        else:
            cap=Path(args.purifier_capture).resolve();capture_manifest=cap/'capture.json'
            captured=json.loads((cap/'capture.json').read_text());accepted=json.loads((asset/'captures/capture.json').read_text())
            if captured['source_sha256']!=accepted['source_sha256'] or captured['config']['camera_override']!=accepted['config']['camera_override']:raise RuntimeError('Purifier capture changed accepted source/camera')
            if captured['config'].get('adapter')!='mh7-purifier-native-fittings-v1' or len(captured['frames'])!=36:raise RuntimeError('Complete fitted purifier capture required')
            if not all(json.loads((cap/n).read_text())['passed'] for n in ('qa.json','reopen-qa.json')):raise RuntimeError('Purifier fitting capture gate')
            for frame in captured['frames']:
                if sha(cap/frame['path'])!=frame['sha256']:raise RuntimeError('Changed purifier capture '+frame['path'])
            for direction,row in [('north',0),('east',3),('south',2),('west',1)]:
                for state in ('idle','working'):
                    image=Image.new('RGBA',(1024,512))
                    for index in range(8):
                        with Image.open(cap/f'frames/{state}/d{row:02d}/f{0 if state=="idle" else index:03d}.png') as frame:image.paste(frame,(index%4*256,index//4*256))
                    image.save(graphics/(state+'-'+direction+'.png'))
        Image.new('RGBA',(1,spec['frame_count'])).save(graphics/'animation-clock.png')
        if args.debug_counters:
            for path in graphics.glob('*.png'):
                if not path.name.startswith(('idle-','working-')):continue
                with Image.open(path) as image:
                    image=image.convert('RGBA');draw=ImageDraw.Draw(image)
                    for index in range(spec['frame_count']):
                        x=index%4*256+12;y=index//4*256+12;color=(240,40,240,255) if path.name.startswith('idle-') else (20+13*index,235-11*index,40+9*index,255)
                        draw.rectangle((x,y,x+7,y+7),fill=color)
                    image.save(path)
        icon_source=graphics/'idle-north.png'
        with Image.open(icon_source) as im:
            cell=im.crop((0,0,256,256));cell.resize((64,64),Image.Resampling.LANCZOS).save(mod/'icons'/(key+'.png'))
            if key=='crucible':cell.save(mod/'icons/crucible-technology.png')
        records.append(dict(key=key,source_delivery=str(asset.relative_to(repo)),capture_manifest=str(capture_manifest),capture_sha256=sha(capture_manifest) if capture_manifest.exists() else None,source_graphic_hashes={p.name:sha(p) for p in graphics.glob('*.png')},native_interfaces_preserved=True))
    (mod/'specs.lua').write_text('return '+lua(specs)+'\n',encoding='utf-8')
    for key,source in [('forge',here/'forge_review_data.lua'),('assembler',here/'assembler_native/data.lua')]:
        text=source.read_text().replace("require('native-data')",'')
        if key=='forge':text=text.replace("ingredients[#ingredients+1]={type='item',name='tp-mh7-forge-accept-guard'", "ingredients[#ingredients+1]={type='item',name=c.inert,amount=1}\ningredients[#ingredients+1]={type='item',name='tp-mh7-forge-accept-guard'")
        text=text.replace('__tp-mh7-assembler__/sound/','__tp-hydrogen-production__/sound/')
        (mod/'machines'/(key+'-state.lua')).write_text(text,encoding='utf-8')
    runtime=(here/'assembler_native/runtime.lua').read_text()
    runtime=runtime.replace("local function register(event)A.register(event.created_entity or event.entity or event.destination);A.invalidate(event) end", "local function configure(e)\n if e and e.valid and e.name=='tp-mh7-review-fabricator' and not e.get_recipe() then e.set_recipe('tp-mh7-review-hydroform') end\n A.register(e)\nend\nlocal function register(event)configure(event.created_entity or event.entity or event.destination);A.invalidate(event) end")
    runtime=runtime.replace("for _,surface in pairs(game.surfaces) do for _,e in pairs(surface.find_entities_filtered{name='tp-mh7-canister-assembler'}) do A.register(e) end end", "for _,surface in pairs(game.surfaces) do for _,e in pairs(surface.find_entities_filtered{name={'tp-mh7-canister-assembler','tp-mh7-review-fabricator'}}) do configure(e) end end")
    runtime=runtime.replace("local A=require('assembler')", "local A=require('assembler');local U=require('player-controls')")
    runtime=runtime.replace('script.on_event(defines.events.on_tick,A.on_tick)', 'script.on_event(defines.events.on_tick,function(event)A.on_tick(event);U.on_tick(event) end)')
    runtime+="\nscript.on_event(defines.events.on_gui_opened,U.on_opened)\nscript.on_event(defines.events.on_gui_closed,U.on_closed)\nscript.on_event(defines.events.on_gui_click,U.on_click)\nremote.add_interface('tp-hydrogen-player-controls',{open=U.open,inspect=U.inspect,interact=U.on_click})\n"
    (mod/'control.lua').write_text(runtime,encoding='utf-8')
    shutil.copy2(here/'hydrogen_player_controls.lua',mod/'player-controls.lua')
    shutil.copy2(here/'hydrogen_stock_access.lua',mod/'stock-access.lua')
    assembler=(here/'assembler_native/assembler.lua').read_text().replace("(s.name==c.shell and shells<3))", "(s.name==c.shell and shells<3) or s.name==c.inert)")
    assembler=assembler.replace("state()[e.unit_number]=job;e.disabled_by_script=true;recipe(job,accept)", "state()[e.unit_number]=job;e.disabled_by_script=true\n local input=e.get_inventory(defines.inventory.crafter_input);if input then for i=1,#input do if input[i].valid_for_read and input[i].name=='tp-mh7-assembler-cycle-token' then input[i].clear() end end end\n recipe(job,accept)")
    assembler=assembler.replace('return A\n',(here/'hydrogen_assembler_player_access.lua').read_text(encoding='utf-8')+'\nreturn A\n')
    (mod/'assembler.lua').write_text(assembler,encoding='utf-8')
    sound_sources={'purifier':('v01',.46),'electrolyzer':('v01',.40),'compressor':('v01',1.15),'crucible':('crucible-v01',.65),'forge':('forge-v01',.70),'fabricator':('fabricator-v01',.70),'assembler':('assembler-v01',.65)}
    mixes={}
    for key,(folder,gain) in sound_sources.items():
        for path in (audio/folder/'masters').glob(key+'-*.ogg'):shutil.copy2(path,mod/'sound'/path.name)
        mixes[key]=dict(gain=gain,distance=3.5 if key=='compressor' else 1.8,priority=16 if key=='compressor' else 30)
    (mod/'audio.lua').write_text('return '+lua(mixes)+'\n')
    shutil.copy2(here/'hydrogen_production_data.lua',mod/'data.lua')
    (mod/'info.json').write_text(json.dumps(dict(name='tp-hydrogen-production',version='0.1.0',title='Tech Priests metallicized hydrogen production',author='Tech Priests',factorio_version='2.1',dependencies=['base >= 2.1.24','tp-mh7-pellet-decay >= 0.0.5','? tech-priests >= 0.1.681']),indent=2)+'\n')
    dependency=out/'tp-mh7-pellet-decay_0.0.5';shutil.copytree(family/'canister-assembler/v04-native-preservation/prototype-mods/tp-mh7-pellet-decay_0.0.3',dependency)
    info=json.loads((dependency/'info.json').read_text());info['version']='0.0.5';(dependency/'info.json').write_text(json.dumps(info,indent=2)+'\n')
    forge=(dependency/'forge.lua').read_text()
    for expression in ('inserter.held_stack','items[j]','inv[j]'):
        forge=forge.replace('if D.is_raw('+expression+') then', 'if D.is_raw('+expression+') or ('+expression+'.valid_for_read and '+expression+'.name==c.inert) then')
    forge=forge.replace("all[e.unit_number]=job;e.disabled_by_script=true", "all[e.unit_number]=job;e.disabled_by_script=true\n local input=e.get_inventory(defines.inventory.crafter_input);if input then for i=1,#input do if input[i].valid_for_read and input[i].name=='tp-mh7-forge-cycle-token' then input[i].clear() end end end")
    forge=forge.replace('return F\n',(here/'hydrogen_forge_player_access.lua').read_text(encoding='utf-8')+'\nreturn F\n')
    (dependency/'forge.lua').write_text(forge,encoding='utf-8')
    shutil.copy2(here/'hydrogen_stock_access.lua',dependency/'stock-access.lua')
    adapter=(dependency/'control.lua').read_text(encoding='utf-8').replace('inspect_forge=F.inspect,','inspect_forge=F.inspect,\n forge_player_view=F.player_view,\n forge_player_transfer=F.player_transfer,')
    (dependency/'control.lua').write_text(adapter,encoding='utf-8')
    resource_names=['purified-water','hydrogen-gas','oxygen-gas','compressed-hydrogen','pellet-fresh','pellet-waning','pellet-degraded','pellet-critical','pellet-inert','empty-pressure-shell','charged-fuel-canister'];resource_sources=[]
    for name in resource_names:
        icon_root=Path(args.resource_icon_root).resolve() if args.resource_icon_root else repo/'tech-priests_src/graphics/icons/hydrogen-chain-v02'
        source=icon_root/(name+'.png')
        if not source.exists():source=family/'ordinary-integration/v01-player-controls/prototype-mods/tp-hydrogen-production_0.1.0/icons'/(name+'.png')
        shutil.copy2(source,mod/'icons'/source.name);resource_sources.append(dict(source=source.relative_to(repo).as_posix() if source.is_relative_to(repo) else str(source),sha256=sha(source)))
    (mod/'resource-icons.lua').write_text("""local function icon(kind,name,image)
 local p=data.raw[kind] and data.raw[kind][name];if p then p.icon='__tp-hydrogen-production__/icons/'..image..'.png';p.icon_size=64;p.icons=nil end
end
for name,image in pairs({['tp-mh7-review-purified-water']='purified-water',['tp-mh7-review-hydrogen-gas']='hydrogen-gas',['tp-mh7-review-oxygen-gas']='oxygen-gas',['tp-mh7-review-compressed-hydrogen']='compressed-hydrogen'}) do icon('fluid',name,image) end
for _,group in ipairs{'raw','forged'} do for i,suffix in ipairs{'','-waning','-degraded','-critical'} do icon('item-with-tags','tp-mh7-'..group..'-metallicized-pellet'..suffix,({'pellet-fresh','pellet-waning','pellet-degraded','pellet-critical'})[i]) end end
icon('item','tp-mh7-inert-pellet','pellet-inert');icon('item','tp-mh7-empty-pressure-shell','empty-pressure-shell');icon('item-with-tags','tp-mh7-contained-metallicized-pellet','charged-fuel-canister')
""",encoding='utf-8')
    (out/'BUILD_RECEIPT.json').write_text(json.dumps(dict(status='normal-game integration candidate; actual combined native tests pending',source_records=records,specs=specs,diagnostic_frame_counters=args.debug_counters,generator_sha256=sha(__file__),source_data_sha256=sha(here/'hydrogen_production_data.lua'),resource_icon_sources=resource_sources,production_addon_hashes={p.relative_to(mod).as_posix():sha(p) for p in mod.rglob('*') if p.is_file()},dependency_addon_hashes={p.relative_to(dependency).as_posix():sha(p) for p in dependency.rglob('*') if p.is_file()},dependency_revision='0.0.5 adds guarded real-stack player transfers; original decay/seal implementation unchanged',fixture_controls_included=False,electricity_enabled=True,research_and_machine_recipes_enabled=True,economy_tuning_final=False),indent=2)+'\n')
    print('HYDROGEN_PRODUCTION_ADDON',mod,flush=True)


if __name__=='__main__':main()
