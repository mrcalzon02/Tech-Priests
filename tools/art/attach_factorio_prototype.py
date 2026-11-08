#!/usr/bin/env python3
"""Fail-closed Factorio graphics attachment for an explicitly named prototype.

Construct a late data-stage override rather than rewriting an arbitrary Lua table.
The job must identify the entity type/name and exact repository source file.
Only assembling-machine/furnace CraftingMachineGraphicsSet is supported.
"""
import hashlib
import json
import re
from pathlib import Path

SUPPORTED = {'assembling-machine', 'furnace'}
MANAGED = '-- factorio-art-target:'
SAFE_NAME = re.compile(r'^[a-z0-9][a-z0-9_-]*$')


def filehash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _tokens(code):
    """Small Lua lexical scanner: ignore quoted text, line/long comments safely.

    Only tokenizes identifiers, quoted strings, braces and equals. This is used
    for source identification, NOT for rewriting or executing unknown Lua code.
    """
    i = 0
    while i < len(code):
        start = i
        if code.startswith('--', i):
            m = re.match(r'--\[(=*)\[', code[i:])
            if m:
                close = ']' + m.group(1) + ']'
                end = code.find(close, i+len(m.group()))
                if end < 0:
                    raise ValueError('Unclosed long Lua comment')
                i = end + len(close)
            else:
                end = code.find('\n', i)
                i = len(code) if end < 0 else end + 1
            continue
        if code[i] in ('"', "'"):
            quote = code[i]
            i += 1
            chars = []
            while i < len(code):
                if code[i] == '\\':
                    i += 1
                    if i < len(code):
                        chars.append(code[i]); i += 1
                elif code[i] == quote:
                    i += 1
                    yield ('string', ''.join(chars), start)
                    break
                else:
                    chars.append(code[i]); i += 1
            else:
                raise ValueError('Unclosed Lua quoted string')
            continue
        m = re.match(r'\[(=*)\[', code[i:])
        if m:
            close = ']' + m.group(1) + ']'
            end = code.find(close, i+len(m.group()))
            if end < 0:
                raise ValueError('Unclosed Lua long string')
            i = end + len(close)
            continue
        if code[i] in '{}=':
            yield (code[i], code[i], i)
            i += 1
            continue
        m = re.match(r'[A-Za-z_][A-Za-z_0-9]*', code[i:])
        if m:
            yield ('ident', m.group(), i)
            i += len(m.group())
        else:
            i += 1


def find_prototype_declaration(source, category, name):
    """Require exactly one {type='...', name='...'} Lua table in named file."""
    code = Path(source).read_text()
    tokens = list(_tokens(code))
    stack, tables = [], []
    for index, (typ, value, pos) in enumerate(tokens):
        if typ == '{':
            stack.append({'start': pos, 'fields': {}})
        elif typ == '}':
            if not stack:
                raise ValueError('Unmatched closing brace in prototype source')
            tables.append(stack.pop())
        elif stack and typ == 'ident' and value in ('type', 'name'):
            if index + 2 < len(tokens) and tokens[index+1][0] == '=' and tokens[index+2][0] == 'string':
                fields = stack[-1]['fields']
                if value in fields and fields[value] != tokens[index+2][1]:
                    raise ValueError('Conflicting prototype field in a table')
                fields[value] = tokens[index+2][1]
    if stack:
        raise ValueError('Unclosed Lua table in prototype source')
    matches = [t for t in tables if t['fields'].get('type') == category and t['fields'].get('name') == name]
    if len(matches) != 1:
        raise ValueError(f'Expected one declared {category}/{name} in {source}, found {len(matches)}')
    return {'source': str(source), 'declared_type': category, 'declared_name': name, 'source_sha256': filehash(source)}


def validate_target(job, mod, repo_root):
    target = job.get('prototype')
    if not isinstance(target, dict):
        raise ValueError('An explicit prototype target object is required to attach')
    if target.get('type') not in SUPPORTED:
        raise ValueError('Unsupported prototype graphics schema; only assembling-machine/furnace graphics_set supported')
    for key in ('name', 'source'):
        if not isinstance(target.get(key), str) or not target[key]:
            raise ValueError(f'Missing prototype.{key}')
    if not SAFE_NAME.fullmatch(target['name']):
        raise ValueError('Invalid prototype.name')
    src = (repo_root / target['source']).resolve()
    if not src.is_relative_to(mod.resolve()) or not src.is_file() or src.suffix != '.lua':
        raise ValueError('Prototype declaration must be an existing Lua file inside the target mod')
    entity_evidence = find_prototype_declaration(src, target['type'], target['name'])
    icon_target = target.get('item_icon')
    icon_evidence = None
    if icon_target is not None:
        if not isinstance(icon_target, dict) or icon_target.get('type') != 'item' or not SAFE_NAME.fullmatch(icon_target.get('name', '')):
            raise ValueError('Only exact item icon targets are supported')
        if not isinstance(icon_target.get('source'), str):
            raise ValueError('Missing item_icon.source')
        icon_src = (repo_root / icon_target['source']).resolve()
        if not icon_src.is_relative_to(mod.resolve()) or not icon_src.is_file() or icon_src.suffix != '.lua':
            raise ValueError('Item declaration must be in an existing Lua file inside target mod')
        icon_evidence = find_prototype_declaration(icon_src, 'item', icon_target['name'])
    return target, entity_evidence, icon_evidence


def require_line(job):
    module_name = f"{job['asset']}-{job['revision']}"
    if not SAFE_NAME.fullmatch(module_name):
        raise ValueError('Unsafe attachment module name')
    return f'require("prototypes.generated_graphics.{module_name}")'


def update_entry(existing, job, *, replace=False):
    """Register exact target once. Changes to an existing target require opt-in."""
    target = job['prototype']
    key = f"{target['type']}/{target['name']}"
    token = f'{MANAGED} {key}'
    lines = existing.splitlines(keepends=True)
    hits = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == token]
    if len(hits) > 1:
        raise ValueError('Duplicate generated attachment target in data-final-fixes.lua')
    entry = token + '\n' + require_line(job) + '\n'
    if hits:
        if not replace:
            raise FileExistsError(f'Existing generated attachment for {key}; set --replace-attachment explicitly')
        idx = hits[0]
        if idx + 1 >= len(lines) or not re.fullmatch(r'require\("prototypes\.generated_graphics\.[a-z0-9_-]+"\)\r?\n?', lines[idx + 1]):
            raise ValueError('Unexpected managed attachment line; refusing replacement')
        lines[idx:idx+2] = [entry]
        return ''.join(lines)
    if not existing:
        return '-- Factorio graphics attachment registry (generated, reviewed)\n' + entry
    if not existing.endswith('\n'):
        existing += '\n'
    return existing + '\n' + entry


def module_code(job, snippet):
    target = job['prototype']
    category, name = target['type'], target['name']
    marker = re.search(r'(?m)^graphics_set\s*=\s*', snippet)
    if not marker or snippet[marker.end():].strip()[-1:] != '}':
        raise ValueError('Expected generated graphics_set in prototype-ready.lua')
    graphic = snippet[marker.end():].strip()
    icon_path = f'__{job["mod_name"]}__/graphics/icons/{job["asset"]}-{job["revision"]}.png'
    text = (
        '-- Automatically generated by tools/art/attach_factorio_prototype.py\n'
        f'-- Exact target: {category}/{name}; authored source validated before deployment.\n'
        f'local target = assert((data.raw["{category}"] or {{}})["{name}"],\n'
        f'  "Missing indicated {category}/{name}; refusing art attachment")\n'
        f'assert(target.type == "{category}" and target.name == "{name}", "Prototype identity changed")\n'
        f'local replacement_graphics_set = {graphic}\n'
        'local previous_graphics = target.graphics_set\n'
        'if previous_graphics and previous_graphics.working_visualisations then\n'
        '  for _, visual in ipairs(previous_graphics.working_visualisations) do\n'
        '    assert(not (visual.animation or visual.north_animation or visual.east_animation\n'
        '      or visual.south_animation or visual.west_animation),\n'
        '      "Previous working animation layer detected: explicit adapter required")\n'
        '  end\n'
        '  replacement_graphics_set.working_visualisations = previous_graphics.working_visualisations\n'
        'end\n'
        'target.graphics_set = replacement_graphics_set\n'
        'target.match_animation_speed_to_activity = false\n'
        f'target.icon = "{icon_path}"\n'
        'target.icons = nil\n'
        'target.icon_size = 64\n'
    )
    icon = target.get('item_icon')
    if icon:
        text += (
            f'local item = assert((data.raw["item"] or {{}})["{icon["name"]}"],\n'
            f'  "Missing indicated item/{icon["name"]}; refusing icon attachment")\n'
            f'assert(item.type == "item" and item.name == "{icon["name"]}", "Item identity changed")\n'
            f'item.icon = "{icon_path}"\n'
            'item.icons = nil\n'
            'item.icon_size = 64\n'
        )
    return text


def attachment_plan(job, mod, repo_root, output, *, replace=False):
    """Validate target and register source → output destinations without writes."""
    target, evidence, item_evidence = validate_target(job, mod, repo_root)
    module = mod / 'prototypes/generated_graphics' / f"{job['asset']}-{job['revision']}.lua"
    if module.exists():
        raise FileExistsError(f'Existing generated module cannot be overwritten: {module}')
    if (mod / 'data-final-fixes.lua').is_symlink():
        raise ValueError('Refusing symlinked mod entry file')
    entry = mod / 'data-final-fixes.lua'
    old = entry.read_text() if entry.exists() else ''
    changed = update_entry(old, job, replace=replace)
    return {'module': module, 'entry': entry, 'entry_old': old, 'entry_new': changed,
            'target_evidence': evidence, 'item_evidence': item_evidence}


def prepare_attachment(job, mod, root, output, *, replace=False):
    """Write generated module and entry preview inside production output only."""
    plan = attachment_plan(job, mod, root, output, replace=replace)
    generated = output / 'prototype_ready/prototypes/generated_graphics' / f"{job['asset']}-{job['revision']}.lua"
    generated.parent.mkdir(parents=True, exist_ok=True)
    generated.write_text(module_code(job, (output / 'prototype-ready.lua').read_text()))
    stage = output / 'prototype_ready/data-final-fixes.lua'
    stage.write_text(plan['entry_new'])
    plan['generated'] = generated
    plan['stage'] = stage
    return plan


def install_attachment(plan):
    """Stage exactly one new module and change the entrypoint; rollback on failure."""
    module, entry = plan['module'], plan['entry']
    if module.exists():
        raise FileExistsError('Module added by concurrent process')
    if (entry.read_text() if entry.exists() else '') != plan['entry_old']:
        raise RuntimeError('data-final-fixes.lua changed since preflight')
    module.parent.mkdir(parents=True, exist_ok=True)
    module.write_bytes(plan['generated'].read_bytes())
    try:
        entry.write_text(plan['entry_new'])
        if filehash(module) != filehash(plan['generated']) or entry.read_text() != plan['entry_new']:
            raise RuntimeError('Attachment install readback failed')
    except Exception:
        module.unlink(missing_ok=True)
        if plan['entry_old'] or entry.exists():
            if plan['entry_old']:
                entry.write_text(plan['entry_old'])
            else:
                entry.unlink(missing_ok=True)
        raise
    return [module, entry]


def verify_lua_attachment(plan, job):
    """Compile generated Lua and execute three isolated data.raw attachment probes.

    Not a Factorio client load. A Lua 5.4 interpreter/compiler is REQUIRED for
    install/deploy, so a broken attachment cannot be published merely because
    text generation succeeded.
    """
    import shutil
    import subprocess
    compiler = shutil.which('luac5.4') or shutil.which('luac')
    runtime = shutil.which('lua5.4') or shutil.which('lua')
    if not compiler or not runtime:
        raise RuntimeError('luac5.4 and lua5.4 are required for prototype attachment verification')
    for path in (plan['generated'], plan['stage']):
        subprocess.run([compiler, '-p', str(path)], check=True, capture_output=True, text=True)
    jobtarget = job['prototype']
    cat, name = jobtarget['type'], jobtarget['name']
    catlua, namelua = json.dumps(cat), json.dumps(name)
    has_icon = jobtarget.get('item_icon') is not None
    item_name = json.dumps(jobtarget['item_icon']['name']) if has_icon else '"unused"'
    module = plan['generated'].read_text()
    scenarios = (
        ('success', f'''data={{raw={{[{catlua}]={{[{namelua}]={{type={catlua},name={namelua},graphics_set={{working_visualisations={{{{light={{intensity=0.4}}}}}}}},collision_box={{1,2}}}}}},["item"]={{[{item_name}]={{type="item",name={item_name}}}}}}}}}\n''', True),
        ('missing_target', f'data={{raw={{[{catlua}]={{}},["item"]={{}}}}}}\n', False),
        ('old_graphic_overlay', f'''data={{raw={{[{catlua}]={{[{namelua}]={{type={catlua},name={namelua},graphics_set={{working_visualisations={{{{animation={{}}}}}}}}}}}},["item"]={{[{item_name}]={{type="item",name={item_name}}}}}}}}}\n''', False),
    )
    for scenario, prefix, should_pass in scenarios:
        suffix = ''
        if should_pass:
            suffix = f'''\nlocal target=data.raw[{catlua}][{namelua}]\nassert(target.graphics_set.animation.north)\nassert((not target.graphics_set.idle_animation) or target.graphics_set.idle_animation.north)\nassert(target.collision_box[1]==1)\nassert(target.graphics_set.working_visualisations[1].light.intensity==0.4)\nassert(target.icon:find("graphics/icons/",1,true))\n'''
            if has_icon:
                suffix += f'assert(data.raw["item"][{item_name}].icon==target.icon)\n'
        result = subprocess.run([runtime, '-'], input=prefix + module + suffix,
                                capture_output=True, text=True)
        if (result.returncode == 0) != should_pass:
            raise RuntimeError(f'Lua attachment probe {scenario} gave unexpected result: {result.stderr[-1000:]}')
    return {'luac_passed': True, 'lua_probes': 3,
            'factorio_client_tested': False}

