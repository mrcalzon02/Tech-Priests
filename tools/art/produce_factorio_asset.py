#!/usr/bin/env python3
"""Single-command Blender -> four-way Factorio sprite production.

Requires an authored/keyframed Blender scene, Blender and Pillow.
The existing export_sprites.py handles actual rendering and frame QA.
This orchestrator adds repeatable game-ready atlases, Lua, icon, receipts and
optional GitHub publication. Never silently rewrites a prior asset.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw

from attach_factorio_prototype import attachment_plan, prepare_attachment, install_attachment, verify_lua_attachment, filehash

ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = ('north', 'east', 'south', 'west')
SAFE = re.compile(r'^[a-z0-9][a-z0-9_-]*$')


def sha(file):
    return hashlib.sha256(Path(file).read_bytes()).hexdigest()


def in_repo(path):
    p = (ROOT / path).resolve()
    if not p.is_relative_to(ROOT.resolve()):
        raise ValueError(f'Path is outside repository: {path}')
    return p


def load_job(job_path):
    job = json.loads(in_repo(job_path).read_text())
    required = ('asset', 'revision', 'capture_profile', 'mod_root', 'mod_name',
                'active_state', 'primary_size', 'sizes', 'scale', 'shift')
    if job.get('schema') != 1 or any(key not in job for key in required):
        raise ValueError('Production job schema/required fields invalid')
    for key in ('asset', 'revision', 'mod_name'):
        if not isinstance(job[key], str) or not SAFE.fullmatch(job[key]):
            raise ValueError(f'Unsafe {key}')
    active = job['active_state']
    if job.get('graphics_schema', 'crafting') not in {'crafting', 'boiler'}:
        raise ValueError('Unknown graphics_schema')
    if job.get('graphics_schema') == 'boiler' and not SAFE.fullmatch(job.get('boiler_target','')):
        raise ValueError('Exact boiler_target required')
    if sorted(job.get('source_direction_indices',[0,1,2,3])) != [0,1,2,3]:
        raise ValueError('Invalid source direction mapping')
    if active is not None and (not isinstance(active, str) or not SAFE.fullmatch(active) or active == 'idle'):
        raise ValueError('Invalid active-state name')
    if (type(job['scale']) not in (int, float) or not math.isfinite(job['scale']) or job['scale'] <= 0
            or not isinstance(job['shift'], list) or len(job['shift']) != 2
            or any(type(v) not in (int, float) or not math.isfinite(v) for v in job['shift'])):
        raise ValueError('Invalid Factorio scale or shift')
    per_direction = job.get('directional_registration')
    if per_direction is not None:
        if not isinstance(per_direction, dict) or set(per_direction) != set(DIRECTIONS):
            raise ValueError('directional_registration must define all four cardinal directions')
        for name, registration in per_direction.items():
            if (not isinstance(registration, dict) or set(registration) != {'scale','shift'}
                    or type(registration['scale']) not in (int,float)
                    or not math.isfinite(registration['scale']) or registration['scale'] <= 0
                    or not isinstance(registration['shift'],list) or len(registration['shift']) != 2
                    or any(type(v) not in (int,float) or not math.isfinite(v) for v in registration['shift'])):
                raise ValueError('Invalid directional sprite registration: '+name)
    sizes = job['sizes']
    if not isinstance(sizes, list) or not sizes or any(type(v) is not int or v <= 0 for v in sizes) or len(set(sizes)) != len(sizes) or job['primary_size'] not in sizes:
        raise ValueError('Invalid requested sprite sizes')
    mod = in_repo(job['mod_root'])
    if json.loads((mod / 'info.json').read_text()).get('name') != job['mod_name']:
        raise ValueError('Mod name does not match target info.json')
    profile = in_repo(job['capture_profile'])
    cfg = json.loads(profile.read_text())
    if cfg.get('directions') != [0, 90, 180, 270] or 'idle' not in cfg.get('states', {}):
        raise ValueError('Four cardinal directions and idle state required')
    if len(cfg['states']['idle']) != 1:
        raise ValueError('Use one authored idle frame; packer will repeat it if necessary')
    if active:
        if set(cfg['states']) != {'idle', active}:
            raise ValueError('Only idle + requested active state supported')
    elif set(cfg['states']) != {'idle'}:
        raise ValueError('Static-only profile must contain idle state only')
    camera = cfg.get('camera_override', {})
    if camera.get('elevation_deg') != 45 or camera.get('azimuth_deg') != 0 or camera.get('ortho_scale', 0) <= 0:
        raise ValueError('45-degree world-aligned structure camera required')
    if any(size not in cfg.get('sizes', []) for size in sizes):
        raise ValueError('Requested resolution missing from capture profile')
    if cfg.get('fps', 0) <= 0:
        raise ValueError('Valid animation fps required')
    return job, cfg, profile, mod


def asset_name(job, state, size):
    stem = f"{job['asset']}-{job['revision']}-{state}"
    return stem + ('' if size == job['primary_size'] else f'-{size}') + '.png'


def preflight(job, out, mod, install):
    if out.exists():
        raise FileExistsError(f'Output already exists: {out}; use a fresh revision')
    if install:
        for state in ('idle', job['active_state']):
            if state is None:
                continue
            for size in job['sizes']:
                target = mod / 'graphics/entity' / asset_name(job, state, size)
                if target.exists():
                    raise FileExistsError(f'Existing sprite would be overwritten: {target}')
        icon = mod / 'graphics/icons' / f"{job['asset']}-{job['revision']}.png"
        if icon.exists():
            raise FileExistsError(f'Existing icon would be overwritten: {icon}')


def validate_capture(capture, job, cfg):
    manifest = json.loads((capture/'capture.json').read_text())
    qa = json.loads((capture/'qa.json').read_text())
    reopen = json.loads((capture/'reopen-qa.json').read_text())
    if not qa.get('passed') or not reopen.get('passed') or manifest.get('config') != cfg:
        raise ValueError('Capture QA/reopen or configuration failed')
    if sha(capture/'master.blend') != manifest.get('master_sha256'):
        raise ValueError('Saved Blender master checksum mismatch')
    cam = manifest['camera']
    if cam['type'] != 'ORTHO' or abs(cam['ortho_scale']-cfg['camera_override']['ortho_scale']) > .0001:
        raise ValueError('Calibrated camera was not saved')
    expected = sum(len(frames)*4 for frames in cfg['states'].values())
    if qa['capture_count'] != expected or len(manifest['frames']) != expected:
        raise ValueError('Missing cardinal-direction captures')
    for entry in manifest['frames']:
        path = capture / entry['path']
        if not path.exists() or sha(path) != entry['sha256']:
            raise ValueError(f'Frame hash mismatch: {path}')
    index = {(s['state'], s['cell_size']): s for s in qa['sheets']}
    for state, frames in cfg['states'].items():
        for size in job['sizes']:
            s = index.get((state, size))
            if not s or s['direction_count'] != 4 or s['frame_count'] != len(frames) or sha(capture/s['path']) != s['sha256']:
                raise ValueError(f'Unverified atlas: {state} {size}')
    return manifest, qa, index


def atlas(capture, sheet, source_count, dest_count, size, direction_order=(0,1,2,3)):
    columns = min(max(8, math.ceil(dest_count * 4 * size / 8192)), dest_count)
    per_direction = math.ceil(dest_count/columns)
    dimensions = (columns*size, per_direction*4*size)
    if max(dimensions) > 8192:
        raise ValueError('Factorio 8192-pixel atlas limit exceeded')
    output = Image.new('RGBA', dimensions)
    with Image.open(capture/sheet['path']) as original:
        for d in range(4):
            source_direction = direction_order[d]
            distinct = set()
            for index in range(dest_count):
                source_index = index if source_count > 1 else 0
                sx = source_index % sheet['columns'] * size
                sy = (source_direction*sheet['rows_per_direction'] + source_index//sheet['columns'])*size
                cell = original.crop((sx,sy,sx+size,sy+size))
                if cell.size != (size,size) or not cell.getchannel('A').getbbox():
                    raise ValueError('Missing or empty atlas cell')
                distinct.add(hashlib.sha256(cell.tobytes()).hexdigest())
                x = index % columns * size
                y = (d*per_direction + index//columns)*size
                output.paste(cell, (x,y))
            if source_count > 1 and len(distinct) != dest_count:
                raise ValueError('Duplicate animation frames')
            if source_count == 1 and len(distinct) != 1:
                raise ValueError('Static state changed when duplicated')
    return output, columns, per_direction


def sprite_registration(job, direction):
    return (job.get('directional_registration') or {}).get(direction,
               {'scale':job['scale'],'shift':job['shift']})


def animation_lua(job, cfg, file, size, frames, columns, rows, index, direction):
    registration = sprite_registration(job,direction)
    scale,shift = registration['scale'],registration['shift']
    return (f'{{ filename = "__{job["mod_name"]}__/graphics/entity/{file}", '
            f'width = {size}, height = {size}, frame_count = {frames}, line_length = {columns}, '
            f'x = 0, y = {index*rows*size}, animation_speed = {cfg["fps"]/60:.8g}, '
            f'scale = {scale:.12g}, shift = {{{shift[0]:.12g}, {shift[1]:.12g}}} }}')


def directional_lua(job, cfg, file, size, frames, columns, rows):
    fields = [f'    {name} = '+animation_lua(job,cfg,file,size,frames,columns,rows,index,name)
              for index,name in enumerate(DIRECTIONS)]
    return '{\n' + ',\n'.join(fields) + '\n  }'


def boiler_pictures_lua(job, cfg, file, size, frames, columns, rows):
    fields = ['  '+name+' = { structure = '+animation_lua(job,cfg,file,size,frames,columns,rows,index,name)+' }'
              for index,name in enumerate(DIRECTIONS)]
    return '{\n'+',\n'.join(fields)+'\n}'


def package(job, cfg, capture, out, mod, install):
    manifest, qa, index = validate_capture(capture, job, cfg)
    active = job['active_state']
    count = len(cfg['states'][active]) if active else 1
    if count > 256:
        raise ValueError('More than 256 frames not supported')
    entity = out/'prototype_ready/graphics/entity'
    icons = out/'prototype_ready/graphics/icons'
    entity.mkdir(parents=True)
    icons.mkdir(parents=True)
    generated = []
    layout = {}
    direction_order = job.get('source_direction_indices', [0,1,2,3])
    if sorted(direction_order) != [0,1,2,3]:
        raise ValueError('source_direction_indices must be a four-way permutation')
    for state in ['idle']+([active] if active else []):
        for size in job['sizes']:
            state_count = 1 if state == 'idle' and job.get('graphics_schema') == 'boiler' else count
            image, columns, rows = atlas(capture,index[(state,size)],len(cfg['states'][state]),state_count,size,direction_order)
            path = entity/asset_name(job,state,size)
            image.save(path)
            with Image.open(path) as check:
                if check.mode != 'RGBA' or check.size != image.size or ImageChops.difference(check,image).getbbox():
                    raise ValueError('Atlas save/reopen roundtrip failed')
            layout[(state,size)] = (path.name,columns,rows)
            generated.append(path)
    start = next((f for f in manifest['frames'] if f['state']=='idle' and f['direction']==0 and f['index']==0),None)
    if not start:
        raise ValueError('No north idle source frame for icon')
    with Image.open(capture/start['path']) as image:
        icon = image.convert('RGBA').resize((64,64),Image.Resampling.LANCZOS)
    icon_path = icons/f"{job['asset']}-{job['revision']}.png"
    icon.save(icon_path)
    generated.append(icon_path)
    size = job['primary_size']
    name,col,rows = layout[('idle',size)]
    idle_lua = directional_lua(job,cfg,name,size,count,col,rows)
    if active:
        name,col,rows = layout[(active,size)]
        active_lua = directional_lua(job,cfg,name,size,count,col,rows)
        snippet = ('-- Paste into an appropriate crafting-machine prototype; review other settings.\n'
                   '-- Complete idle and active objects are ALTERNATIVES, not overlay layers.\n'
                   'graphics_set = {\n  animation = '+active_lua+',\n  idle_animation = '+idle_lua+',\n'
                   '  always_draw_idle_animation = false\n}\n')
    else:
        snippet = '-- Attach to an entity accepting Animation4Way.\ngraphics_set = { animation = '+idle_lua+' }\n'
    if job.get('graphics_schema') == 'boiler':
        target = job.get('boiler_target')
        if not isinstance(target, str) or not SAFE.fullmatch(target):
            raise ValueError('Exact boiler_target required for boiler graphics')
        name,col,rows = layout[(active or 'idle',size)]
        snippet = ('-- Factorio 2.1 BoilerPictureSet; complete frames, no duplicate body overlays.\n'
                   '-- Load after the exact boiler prototype has been declared.\n'
                   f'local target = assert(data.raw.boiler["{target}"], "Missing boiler {target}")\n'
                   'target.pictures = '+boiler_pictures_lua(job,cfg,name,size,count,col,rows)+'\n'
                   'target.water_reflection = nil\n'
                   '-- Match the authored 2x2 body and rear-row circular pipe mouths.\n'
                   'target.collision_box = {{-0.85, -0.85}, {0.85, 0.85}}\n'
                   'target.selection_box = {{-1, -1}, {1, 1}}\n'
                   'target.fluid_box.pipe_connections = {{flow_direction="input-output", '
                   'direction=defines.direction.west, position={-0.5, -0.5}}}\n'
                   'target.output_fluid_box.pipe_connections = {{flow_direction="output", '
                   'direction=defines.direction.east, position={0.5, -0.5}}}\n'
                   f'local icon = "__{job["mod_name"]}__/graphics/icons/{job["asset"]}-{job["revision"]}.png"\n'
                   'target.icon, target.icons, target.icon_size = icon, nil, 64\n'
                   'for _, kind in ipairs({"item", "recipe"}) do\n'
                   f'  local prototype = (data.raw[kind] or {{}})["{target}"]\n'
                   '  if prototype then prototype.icon, prototype.icons, prototype.icon_size = icon, nil, 64 end\n'
                   'end\n')
    lua = out/'prototype-ready.lua'
    lua.write_text(snippet)
    generated.append(lua)
    review = Image.new('RGB',(1024,2*282+28),(31,33,37))
    draw = ImageDraw.Draw(review)
    for d in range(4):
        for row,state in enumerate(['idle']+([active] if active else [])):
            entry = next(f for f in manifest['frames'] if f['state']==state and f['direction']==direction_order[d] and f['index']==0)
            with Image.open(capture/entry['path']) as image:
                image = image.convert('RGBA').resize((240,240),Image.Resampling.LANCZOS)
                backing = Image.new('RGBA',(256,256),(48,50,54,255))
                backing.alpha_composite(image,(8,8))
                review.paste(backing.convert('RGB'),(d*256,row*282))
            draw.text((d*256+8,row*282+258), f'{DIRECTIONS[d]} / {state}',fill='white')
    picture = out/'four-way-review.png'
    review.save(picture)
    generated.append(picture)
    receipt = {
        'schema':1,'passed':True,'factorio_client_tested':False,'prototype_attached':False,
        'asset':job['asset'],'revision':job['revision'],'camera':cfg['camera_override'],
        'directions':list(DIRECTIONS),'source_frame_count':qa['capture_count'],
        'source_direction_indices':direction_order,
        'directional_registration':{name:sprite_registration(job,name) for name in DIRECTIONS},
        'frames_per_direction':count,'fps':cfg['fps'],'master_sha256':manifest['master_sha256'],
        'files':{str(f.relative_to(out)):sha(f) for f in generated},
        'note':'Prototype-ready snippet only; verify insertion and actual Factorio runtime before acceptance.'
    }
    receipt_path = out/'production-receipt.json'
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    generated.append(receipt_path)
    installed = []
    if install:
        # Recheck all targets *before* installing any file.
        targets = [(f,mod/f.relative_to(out/'prototype_ready')) for f in generated
                   if f.is_relative_to(out/'prototype_ready')]
        if any(dest.exists() for _,dest in targets):
            raise FileExistsError('One or more target sprites/icons already exist')
        for file,dest in targets:
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(file,dest)
            if sha(file) != sha(dest):
                raise ValueError(f'Installed sprite hash differs: {dest}')
            installed.append(dest)
    return receipt, installed


def publish(job, out, installed):
    def git(*args, check=True):
        return subprocess.run(['git',*args],cwd=ROOT,text=True,capture_output=True,check=check)
    if git('branch','--show-current').stdout.strip() != 'main':
        raise RuntimeError('Publishing requires branch main')
    if git('diff','--cached','--name-only').stdout.strip():
        raise RuntimeError('Refusing to include pre-existing staged work')
    git('add','--',str(out.relative_to(ROOT)),*(str(f.relative_to(ROOT)) for f in installed))
    git('diff','--cached','--check')
    if git('diff','--cached','--quiet',check=False).returncode == 0:
        raise RuntimeError('No production changes to commit')
    git('commit','-m',f'art(factorio): publish {job["asset"]} {job["revision"]} four-way art')
    for attempt in range(3):
        git('fetch','origin','main')
        git('rebase','origin/main')
        response = git('push','origin','HEAD:main',check=False)
        if response.returncode == 0:
            local = git('rev-parse','HEAD').stdout.strip()
            remote = git('ls-remote','origin','refs/heads/main').stdout.split()[0]
            if local != remote:
                raise RuntimeError('GitHub remote SHA readback failed')
            print('GITHUB_PUBLICATION_VERIFIED',local,flush=True)
            return local
        print('Non-force push rejected, bounded retry',attempt+1,response.stderr,flush=True)
    raise RuntimeError('GitHub push failed after three attempts')


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--job',required=True,help='Repository-relative production job JSON')
    p.add_argument('--out',help='Unique repository-relative directory (default models/sprite-production/ASSET/REVISION)')
    p.add_argument('--from-capture',help='Repackage an existing verified Blender capture without rerendering')
    p.add_argument('--blender',default='blender')
    p.add_argument('--install',action='store_true',help='Copy new versioned images into target mod; no commit')
    p.add_argument('--publish',action='store_true',help='Install graphics, commit, push main and verify remote SHA (no prototype attachment)')
    p.add_argument('--attach-prototype',action='store_true',help='With --install/--publish, attach exact named job.prototype via data-final-fixes.lua')
    p.add_argument('--deploy',action='store_true',help='ONE COMMAND: render, install, attach indicated prototype, commit and verify remote GitHub main')
    p.add_argument('--replace-attachment',action='store_true',help='Explicitly replace an older managed attachment for this SAME prototype target')
    args = p.parse_args(argv)
    job,cfg,profile,mod = load_job(args.job)
    out = in_repo(args.out or f"models/sprite-production/{job['asset']}/{job['revision']}")
    install = args.install or args.publish or args.deploy
    attach = args.attach_prototype or args.deploy
    publish_now = args.publish or args.deploy
    if attach and not install:
        p.error('--attach-prototype requires --install or --publish (or use --deploy)')
    if args.replace_attachment and not attach:
        p.error('--replace-attachment requires --attach-prototype or --deploy')
    preflight(job,out,mod,install)
    # Resolve exact declared target BEFORE paying for any Blender render.
    if job.get('prototype'):
        attachment_plan(job, mod, ROOT, out, replace=args.replace_attachment)
    out.mkdir(parents=True)
    capture = in_repo(args.from_capture) if args.from_capture else out/'capture'
    if not args.from_capture:
        cmd = [sys.executable,str(ROOT/'tools/art/export_sprites.py'),
               '--config',str(profile),'--out',str(capture),'--blender',args.blender]
        try:
            subprocess.run(cmd,cwd=ROOT,check=True)
        except subprocess.CalledProcessError:
            log = capture/'blender.log'
            if log.exists():
                print('\n'.join(log.read_text(errors='replace').splitlines()[-90:]),file=sys.stderr)
            raise
    result,installed = package(job,cfg,capture,out,mod,install)
    if job.get('prototype'):
        # Every job with an indicated prototype receives a reviewable exact-target
        # attachment module. Only --attach-prototype or --deploy installs it.
        plan = prepare_attachment(job, mod, ROOT, out, replace=args.replace_attachment)
        result['prototype_prepared'] = True
        result['prototype_target'] = {
            'type': job['prototype']['type'], 'name': job['prototype']['name'],
            'declaration_sha256': plan['target_evidence']['source_sha256'],
            'attachment_module_sha256': filehash(plan['generated']),
            'stage_file_sha256': filehash(plan['stage'])}
        result['files']['prototype_ready/prototypes/generated_graphics/' + plan['module'].name] = filehash(plan['generated'])
        result['files']['prototype_ready/data-final-fixes.lua'] = filehash(plan['stage'])
        if attach:
            # Lua syntax and three isolated runtime probes must pass before any
            # prototype stage file is touched or any publication takes place.
            try:
                verification = verify_lua_attachment(plan, job)
                attached_files = install_attachment(plan)
            except Exception:
                # The newly installed uniquely named sprite files are rolled back;
                # attachment module installation has its own rollback guard.
                for path in installed:
                    path.unlink(missing_ok=True)
                raise
            installed.extend(attached_files)
            result['prototype_attached'] = True
            result['attachment_lua_verification'] = verification
        (out/'production-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
    print('FACTORIO_PRODUCTION_QA_PASSED',json.dumps({k:result[k] for k in
        ('asset','revision','source_frame_count','frames_per_direction','directions','prototype_attached')}),flush=True)
    if publish_now:
        publish(job,out,installed)
    else:
        print('NOT_PUBLISHED; review generated file:',out/'four-way-review.png',flush=True)


if __name__ == '__main__':
    main()

