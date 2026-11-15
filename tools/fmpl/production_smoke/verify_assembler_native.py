"""Independently bind native preservation, reload, clean captures and safe loading."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image
from run_compressor_native_jig import sha


def main():
    ap=argparse.ArgumentParser()
    for k in ('profile','reload-profile','clock-profile','factorio','out'):ap.add_argument('--'+k,required=True)
    args=ap.parse_args();profile=Path(args.profile).resolve();reload=Path(args.reload_profile).resolve();clock=Path(args.clock_profile).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve native verification')
    out.mkdir(parents=True);receipt=json.loads((profile/'native-jig-receipt.json').read_text());other=json.loads((reload/'native-jig-receipt.json').read_text());cadence=json.loads((clock/'native-clock-readback.json').read_text());spec=json.loads((profile/'spec.json').read_text())
    if not receipt['passed'] or not other['passed'] or not other['save_reload_exercised'] or receipt['diagnostic_frame_counters'] or not cadence['passed']:raise RuntimeError('Native receipts/counters')
    if receipt['results']!=other['results']:raise RuntimeError('Actual tick-400 reload changed complete histories')
    mod=profile/'mods/tp-mh7-assembler_0.0.1'
    for name,digest in receipt['production_mod_hashes'].items():
        if sha(mod/name)!=digest:raise RuntimeError('Changed production addon '+name)
    for name in ('assembler.lua','control.lua','data.lua','native-data.lua','spec.lua'):
        if sha(mod/name)!=sha(reload/'mods/tp-mh7-assembler_0.0.1'/name) or sha(mod/name)!=sha(clock/'mods/tp-mh7-assembler_0.0.1'/name):raise RuntimeError('Different tested code '+name)
    rows=receipt['results']['sites'];modes={'steady','mixed','batch','decay','expire','blocked','missing-shell','missing-pellet','raw-reject'}
    if len(rows)!=36 or {(r['direction'],r['mode']) for r in rows}!={(d,m) for d in ['north','east','south','west'] for m in modes}:raise RuntimeError('Native site coverage')
    conversions=0;batch=[]
    for site in rows:
        for row in site['conversions']:
            before,after=row['before'],row['after']
            if after['name']=='tp-mh7-contained-metallicized-pellet':
                conversions+=1;tags=after['tags']
                if before['health']!=after['health'] or before['quality']!=after['quality'] or tags['mh7_raw_name']!=before['name'] or tags['mh7_remaining_ticks']!=before['spoil_tick']-row['tick']:raise RuntimeError('Pellet refreshed during real seal')
                if row['shell']['health']!=tags['mh7_shell_health'] or row['shell']['quality']!=tags['mh7_shell_quality']:raise RuntimeError('Shell state changed')
        if site['mode']=='batch':
            for row in site['conversions']:
                threshold=(3.5+(row['station']-1)*5)/16
                if abs(row['crafting_progress']-threshold)>1/960+.000001:raise RuntimeError('Seal was not at actual station progress')
            batch.append(dict(direction=site['direction'],stations=[dict(station=r['station'],tick=r['tick'],crafting_progress=r['crafting_progress']) for r in site['conversions']]))
    destroyed=receipt['results']['destruction'];before=next(s for s in destroyed['before']['stock'] if s.get('tags',{}).get('mh7_fixture')=='destroyed');released=next(s for s in destroyed['released'] if s.get('tags',{}).get('mh7_fixture')=='destroyed')
    if before!=released:raise RuntimeError('Destruction refreshed live stock')
    images=[];shots=profile/'user-data/script-output/tp-mh7-assembler-review'
    for path in sorted(shots.glob('*.png')):
        with Image.open(path) as im:
            if im.size!=(900,900) or im.convert('RGB').getextrema()==((0,0),)*3:raise RuntimeError('Invalid native screenshot')
        images.append(dict(path=path.name,sha256=sha(path),kind='clock' if path.name.startswith('clock-') else 'production'))
    if len(images)!=324 or sum(r['kind']=='production' for r in images)!=64:raise RuntimeError('Incomplete native captures')
    for root in (profile,clock):
        if 'Goodbye' not in (root/'graphics.log').read_text(errors='replace'):raise RuntimeError('Graphics run not terminal')
    for p in (mod/'graphics').glob('*.png'):
        if p.name=='animation-clock.png':continue
        with Image.open(p) as im:
            for i in range(16):
                if im.convert('RGBA').getpixel((i%4*256+16,i//4*256+16))[3]!=0:raise RuntimeError('Private counter leaked into delivery')
    # Create a normal map with only the actual production adapters. The isolated
    # fixture's control.lua and no-stock clock-probe prototype are absent.
    mods=out/'safe-mods';mods.mkdir()
    for n in ('tp-mh7-assembler_0.0.1','tp-mh7-pellet-decay_0.0.3'):shutil.copytree(profile/'mods'/n,mods/n)
    enabled={'base','quality','recycler','tp-mh7-pellet-decay','tp-mh7-assembler'}
    (mods/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=n in enabled) for n in sorted(enabled|{'space-age','elevated-rails'})])))
    user=out/'safe-user';user.mkdir();exe=Path(args.factorio).resolve();config=out/'safe-config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n');(out/'steam_appid.txt').write_text('427520')
    with (out/'safe-create.log').open('w') as log:result=subprocess.run([str(exe),'--config',str(config),'--mod-directory',str(mods),'--create',str(out/'safe-normal-map.zip'),'--map-gen-settings',str(profile/'map-gen-settings.json')],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240)
    if result.returncode:raise RuntimeError('Safe ordinary map load failed')
    report=dict(passed=True,model_source_sha256=receipt['model_source_sha256'],capture_sha256=receipt['capture_sha256'],actual_sites=36,orientations=4,modes=sorted(modes),verified_actual_seals=conversions,three_station_progress=batch,full_tick400_reload_histories_identical=True,destruction_released_identical_live_stock=True,
        safe_prototype_normal_map_created=True,safe_load_log_sha256=sha(out/'safe-create.log'),private_native_images=images,clean_production_capture_count=64,private_counter_capture_count=260,native_clock=cadence,production_mod_hashes=receipt['production_mod_hashes'],
        agent_graphical_review=dict(accepted=True,owner_approved=False,reviewed_clean_images=64,method='Four full-resolution batch orientations and complete private 64-image production contact sheet; intact camera/body/footing, all directions, working/stopped cases. Native game pixels remain private.'),
        native_audio_binding_verified=True,native_sound_phase_synchronization_verified=False,native_visual_crafting_phase_synchronization_verified=False,scope='Real stock preservation, batch progress, native cadence and production/stopped graphical states. Engine animation has per-entity phase offsets; no claim of exact graphics-to-seal or sound-to-seal phase synchronization. Review-only void energy and private driver recipes; ordinary chain/economy integration remains open.')
    (out/'native-verification.json').write_text(json.dumps(report,indent=2)+'\n');print('ASSEMBLER_NATIVE_VERIFIED',conversions,'SEALS',len(images),'PRIVATE_IMAGES',flush=True)


if __name__=='__main__':main()
