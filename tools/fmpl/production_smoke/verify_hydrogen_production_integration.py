"""Bind real production, power, reload, native clocks and unmodified body pixels."""
import argparse
import json
from pathlib import Path
from PIL import Image,ImageChops
from run_compressor_native_jig import sha


def main():
    ap=argparse.ArgumentParser()
    for k in ('addon','baseline','reload','visual-profile','clock-addon','out'):ap.add_argument('--'+k,required=True)
    args=ap.parse_args();addon=Path(args.addon).resolve();baseline=Path(args.baseline).resolve();reload=Path(args.reload).resolve();visual=Path(args.visual_profile).resolve();debug=Path(args.clock_addon).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve integration readbacks')
    build=json.loads((addon/'BUILD_RECEIPT.json').read_text());test=json.loads((baseline/'chain-receipt.json').read_text());other=json.loads((reload/'chain-receipt.json').read_text());visual_test=json.loads((visual/'chain-receipt.json').read_text());clocks=json.loads((visual/'clock-readback.json').read_text())
    if build['diagnostic_frame_counters'] or not test['passed'] or not other['passed'] or not other['save_reload_exercised'] or test['results']!=other['results']:raise RuntimeError('Production/reload gate')
    if test['build_receipt_sha256']!=sha(addon/'BUILD_RECEIPT.json') or other['build_receipt_sha256']!=sha(addon/'BUILD_RECEIPT.json'):raise RuntimeError('Stale production addon')
    if not clocks['passed'] or not visual_test['passed']:raise RuntimeError('Actual native clock profile')
    if not test['results']['power_pause_verified'] or not test['results']['separate_native_expiration_and_inert_logistics_probe_passed']:raise RuntimeError('Power/inert flow gate')
    if test['results']['intermediate_stock_injected_into_production_line']:raise RuntimeError('Injected intermediates invalidate end-to-end proof')
    modules=addon/'tp-hydrogen-production_0.1.0';probe=debug/'tp-hydrogen-production_0.1.0';pixel_checks=[]
    for path,digest in build['production_addon_hashes'].items():
        if sha(modules/path)!=digest:raise RuntimeError('Changed production file '+path)
        if Path(path).suffix!='.png' and sha(modules/path)!=sha(probe/path):raise RuntimeError('Counter addon changes production code/sound '+path)
    for spec in build['specs']:
        key=spec['key'];count=spec['frame_count']
        for state in ('idle','working'):
            for direction in ('north','east','south','west'):
                name=f'graphics/{key}/{state}-{direction}.png'
                with Image.open(modules/name) as a,Image.open(probe/name) as b:
                    a=a.convert('RGBA');b=b.convert('RGBA');difference=ImageChops.difference(a,b)
                    for i in range(count):
                        x=i%4*256+12;y=i//4*256+12
                        if a.getpixel((x+4,y+4))[3]!=0:raise RuntimeError('Private counter appears in production art')
                        difference.paste((0,0,0,0),(x,y,x+8,y+8))
                    if any(high for low,high in difference.getextrema()):raise RuntimeError('Counter study changed actual machine body '+name)
                pixel_checks.append(dict(path=name,body_pixels_identical=True,production_sha256=sha(modules/name),counter_sha256=sha(probe/name)))
    # Compare actual native graphics and pipe definitions with/without the main
    # mod. The graphical probe is standalone; the full functional run includes
    # the published Tech Priests and Space Age build.
    main_raw=json.loads((baseline/'user-data/script-output/data-raw-dump.json').read_text());visual_raw=json.loads((visual/'user-data/script-output/data-raw-dump.json').read_text());equivalence=[]
    for spec in build['specs']:
        a=main_raw['assembling-machine'][spec['entity']];b=visual_raw['assembling-machine'][spec['entity']]
        for field in ('graphics_set','collision_box','selection_box','fluid_boxes','working_sound','tile_width','tile_height'):
            if a.get(field)!=b.get(field):raise RuntimeError('Native prototype differs in visual probe '+spec['key']+' '+field)
        equivalence.append(spec['key'])
    if main_raw['pipe']['pipe']['pictures']!=visual_raw['pipe']['pipe']['pictures']:raise RuntimeError('Different native pipe graphics invalidate join equivalence')
    sealed=[];formed=[]
    for row in test['results']['assembler_conversions'].values():
        before,after=row['before'],row['after']
        if after['name']=='tp-mh7-contained-metallicized-pellet':
            tags=after['tags']
            if before['health']!=after['health'] or before['quality']!=after['quality'] or tags['mh7_raw_name']!=before['name'] or tags['mh7_remaining_ticks']!=before['spoil_tick']-row['tick']:raise RuntimeError('Integrated seal repaired or refreshed stock')
            sealed.append(row)
    for row in test['results']['forge_conversions'].values():
        if row['before']['health']!=row['after']['health'] or row['before']['quality']!=row['after']['quality'] or row['before']['spoil_tick']!=row['after']['spoil_tick']:raise RuntimeError('Integrated formation repaired or refreshed stock')
        formed.append(row)
    if not sealed or not formed or test['results']['blocked']['output']['name']!='tp-mh7-contained-metallicized-pellet':raise RuntimeError('No actual buffered contained output')
    images=[];shots=visual/'user-data/script-output/tp-hydrogen-chain-review'
    for path in sorted(shots.glob('*.png')):
        with Image.open(path) as im:
            if im.size!=(900,900):raise RuntimeError('Wrong native image dimensions')
        images.append(dict(name=path.name,sha256=sha(path),kind='clock' if path.name.startswith('clock-') else 'production'))
    if len(images)!=487 or sum(r['kind']=='production' for r in images)!=32:raise RuntimeError('Incomplete native capture set')
    if 'Goodbye' not in (visual/'graphics.log').read_text(errors='replace'):raise RuntimeError('Native render is not terminal')
    report=dict(passed=True,build_receipt_sha256=sha(addon/'BUILD_RECEIPT.json'),baseline_receipt_sha256=sha(baseline/'chain-receipt.json'),reload_receipt_sha256=sha(reload/'chain-receipt.json'),main_mod_loaded=test['main_mod_loaded'],actual_end_to_end_contained=test['results']['contained_output_before_unseal'],actual_formation_records=len(formed),actual_seal_records=len(sealed),no_live_intermediates_injected=True,power_pause_verified=True,expired_inert_actual_inserter_flow_verified=True,whole_history_reload_identical=True,
        native_clock_readback=clocks,graphical_body_pixel_equivalence=pixel_checks,native_main_and_visual_definitions_identical=equivalence,native_pipe_definitions_identical=True,private_native_images=images,private_native_production_images=32,
        player_facing_gui_complete=False,energy_recipe_economy_final=False,owner_approved=False,scope='Functional end-to-end electric production and real stock conservation with published main, plus exact structural/native graphics equivalence and bounded graphical captures. Hidden processor recipes still need a player-facing interface. Economy values are initial tuning. Agent visual judgement is recorded separately.')
    out.write_text(json.dumps(report,indent=2)+'\n');print('HYDROGEN_INTEGRATION_VERIFIED',report['actual_end_to_end_contained'],'CONTAINED',len(images),'PRIVATE_IMAGES',flush=True)


if __name__=='__main__':main()
