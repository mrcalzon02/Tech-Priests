"""Package original SFX and a prototype-only audio extension for built machines."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--out',required=True);args=ap.parse_args()
    src=Path(args.source).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve authored audio revisions')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    receipt=json.loads((src/'audio-receipt.json').read_text())
    for row in receipt['assets']:
        for extension in ('wav','ogg'):
            path=src/(row['name']+'.'+extension)
            if sha(path)!=row[extension+'_sha256']:raise RuntimeError('Audio source bytes changed')
            (out/'masters').mkdir(exist_ok=True)
            shutil.copy2(path,out/'masters'/path.name)
    shutil.copy2(src/'audio-receipt.json',out/'audio-receipt.json')
    mod=out/'review-mod/tp-mh7-machinery-audio_0.0.1';mod.mkdir(parents=True);sounds=mod/'sound';sounds.mkdir()
    for path in src.glob('*.ogg'):shutil.copy2(path,sounds/path.name)
    (mod/'info.json').write_text(json.dumps(dict(name='tp-mh7-machinery-audio',version='0.0.1',title='Metallic hydrogen authored machinery audio',author='Tech Priests',factorio_version='2.1',
        dependencies=['base >= 2.1.24','? tp-mh7-purifier-review >= 0.0.1','? tp-mh7-electrolyzer-review >= 0.0.1','? tp-mh7-compressor-review >= 0.0.1']),indent=2)+'\n')
    (mod/'data-updates.lua').write_text("""-- Audio-only extension: preserved geometry, recipes and animation graphics.
local ROOT='__tp-mh7-machinery-audio__/sound/'
local rows={
 {'tp-mh7-review-purifier','purifier-working.ogg',.46,1.25,96},
 {'tp-mh7-review-electrolyzer','electrolyzer-working.ogg',.40,1.15,104},
 {'tp-mh7-review-compressor','compressor-working.ogg',1.15,3.5,16},
}
for _,row in ipairs(rows) do
 local entity=data.raw['assembling-machine'][row[1]]
 if entity then
  entity.working_sound={sound={filename=ROOT..row[2],volume=row[3],audible_distance_modifier=row[4],priority=row[5],preload=true},
   match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=18,fade_out_ticks=24,max_sounds_per_prototype=3}
  if row[1]=='tp-mh7-review-compressor' then
   entity.working_sound.idle_sound={filename=ROOT..'compressor-idle.ogg',volume=.14,audible_distance_modifier=.85,priority=160}
   entity.working_sound.activate_sound={filename=ROOT..'compressor-start.ogg',volume=.90,audible_distance_modifier=3,priority=24}
   entity.working_sound.deactivate_sound={filename=ROOT..'compressor-stop.ogg',volume=.82,audible_distance_modifier=2.5,priority=32}
  end
  log('TP_MH7_AUDIO_BOUND '..row[1]..' gain='..row[3]..' range='..row[4])
 end
end
""",encoding='utf-8')
    (out/'README.md').write_text('# Authored machinery audio V01\n\n'
        'Original procedural mono 48kHz SFX: compressor motor/gear roar, valve chatter, loaded housing knocks and pressure chuffs, with start, idle and shutdown cues. The compressor working bed loops over eight seconds. Purifier pump/water and electrolyzer rectifier/process beds have distinct quieter four-second loops. No sampled recordings or third-party music are used.\n\n'
        'The audio-only review extension binds all three existing review prototypes without touching accepted geometry or graphics. Compressor gain 1.15, audible distance multiplier 3.5 and priority 16 make it the foreground machinery sound; the other two loops use gains .46/.40 and shorter range. The measured effective RMS is about 8.4 dB above the project generic running sample at its existing .38 gain. Master and encoded decode/headroom/loop checks are in the receipt.\n\n'
        'These are authored sound assets and prototype bindings. Owner audition and final ordinary-chain integration remain open. The four remaining precursor machines and three reactors must receive machine-specific audio during their production; do not mark them done with silent prototypes.\n',encoding='utf-8')
    (out/'CHAIN_AUDIO_REQUIREMENTS.json').write_text(json.dumps(dict(owner_request='Every machinery model needs sound; compressor should be the loudest nearby',
        implemented_profiles={'hydrogen-compressor':'eight-second motor/clatter/chuff loop plus start/idle/stop, native review extension',
            'water-purifier':'four-second pump/water bed, native review extension','electrolyzer':'four-second rectifier/process bed, native review extension'},
        remaining={'metallization-crucible':'pressure containment/thermal machinery','pelletization-forge':'press/feeder/solid discharge',
            'pressure-vessel-fabricator':'rollers/drive/welding','canister-assembler':'index/fill/seal',
            'plasma-reactors':'tiered containment/cooling/power beds after native sources recovered'},
        ordinary_chain_integrated=False,owner_audio_approved=False),indent=2)+'\n')
    (out/'SHA256.json').write_text(json.dumps({p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file()},indent=2)+'\n')
    print('MACHINERY_AUDIO_PACKAGED',out,flush=True)


if __name__=='__main__':main()
