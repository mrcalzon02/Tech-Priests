"""Build an evidence index; file presence never implies visual acceptance."""
import argparse, hashlib, json, pathlib, re, subprocess

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo', type=pathlib.Path, required=True)
    ap.add_argument('--pipeline', type=pathlib.Path, required=True)
    ap.add_argument('--out', type=pathlib.Path, required=True)
    a=ap.parse_args(); root=a.repo.resolve(); hb=a.pipeline.resolve()
    def git(where,*args): return subprocess.check_output(['git','-C',str(where),*args],text=True,encoding='utf-8').strip()
    def paths(where): return git(where,'ls-files','-z').split('\0')
    tracked=paths(root); htracked=paths(hb)
    lua={p:(root/p).read_text(encoding='utf-8-sig') for p in tracked if p.startswith('tech-priests_src/') and p.endswith('.lua')}
    refs={}
    for p,s in lua.items():
        for n,line in enumerate(s.splitlines(),1):
            for name in re.findall(r'__tech-priests__/([^"\s]+?\.png)',line):
                refs.setdefault('tech-priests_src/'+name,[]).append({'path':p,'line':n})
    sprites=[]
    for p in tracked:
        if not p.startswith('tech-priests_src/graphics/entity/') or not p.endswith('.png'): continue
        rel=p.split('/')[3:]; family=rel[0] if len(rel)>1 else 'emergency-boiler-v08'
        sprites.append({'path':p,'family':family,'bytes':(root/p).stat().st_size,
                        'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest(),
                        'literal_lua_references':refs.get(p,[]),
                        'reference_limit':'Dynamic Lua paths and inherited fields require prototype readback; an empty list is not proof of orphaning.',
                        'acceptance':'unreviewed_in_this_audit'})
    def assets(where, ps, prefix):
        return [{'path':p,'bytes':(where/p).stat().st_size,'sha256':hashlib.file_digest((where/p).open('rb'),'sha256').hexdigest()} for p in ps if p.startswith(prefix) and p.endswith(('.blend','.glb','.gltf','.zip'))]
    segmented=[]
    for p in tracked:
        if not p.startswith('art/') or not p.endswith('source_manifest.json'):continue
        manifest=json.loads((root/p).read_text(encoding='utf-8-sig'))
        if not isinstance(manifest.get('parts'),list):continue
        combined=hashlib.sha256();parts=[]
        for part in manifest['parts']:
            part_name=part.get('path',part.get('file'))
            part_bytes=part.get('size_bytes',part.get('bytes'))
            if not isinstance(part_name,str) or not isinstance(part_bytes,int):raise ValueError('Unknown source fragment descriptor: '+p)
            path=((root/p).parent/part_name).resolve()
            if not path.is_relative_to(root):raise ValueError('Source fragment escapes repository')
            data=path.read_bytes();actual=hashlib.sha256(data).hexdigest()
            assert len(data)==part_bytes and actual==part['sha256'],str(path)
            combined.update(data);parts.append({'path':path.relative_to(root).as_posix(),'bytes':len(data),'sha256':actual})
        expected_sha=manifest.get('sha256',manifest.get('approved_source_sha256'))
        filename=manifest.get('filename',manifest.get('approved_source_filename'))
        assert filename and combined.hexdigest()==expected_sha,p
        if 'part_count' in manifest:assert len(parts)==manifest['part_count'],p
        if 'approved_source_size_bytes' in manifest:assert sum(v['bytes'] for v in parts)==manifest['approved_source_size_bytes'],p
        segmented.append({'manifest':p,'assembled_filename':filename,'assembled_bytes':sum(v['bytes'] for v in parts),'assembled_sha256':combined.hexdigest(),'fragments_verified':True,'parts':parts,'acceptance':'source availability proven; read linked capture records before assigning animation/export completion'})
    def relevant_hb(p):
        return p.startswith(('tools/factorio-render-pipeline/','tools/refinery-agent/','tools/fmpl/','skills/fmpl-asset-production/')) or (p.startswith('tools/local-worker/') and any(tag in p.lower() for tag in ('fmpl','refinery','workbench','one_tile','dir_map')))
    report={'schema':1,'tech_priests_head':git(root,'rev-parse','HEAD'),'pipeline_head':git(hb,'rev-parse','HEAD'),
      'snapshot_kind':'Tracked working-tree bytes, including staged asset changes; HEAD values identify the reconciled base, not a claim that every staged file already belongs to that commit.',
      'working_tree_delta':git(root,'diff','--name-only','HEAD').splitlines(),
      'scope':'All tracked entity PNGs and authored model/package files; excludes repeated dist/version snapshots, effects, GUI and third-party character replacements.',
      'sprites':sprites,'model_sources_and_exports':assets(root,tracked,'art/'),'segmented_model_sources':segmented,
      'pipeline_sources_and_exports':[v for v in assets(hb,htracked,'tools/') if relevant_hb(v['path'])],
      'integration_sources':sorted(p for p in lua if p.startswith('tech-priests_src/prototypes/') or p in ['tech-priests_src/data.lua','tech-priests_src/data-updates.lua','tech-priests_src/data-final-fixes.lua']),
      'production_scripts':sorted(p for p in tracked if p.startswith(('tools/art/','tools/fmpl/')) or (p.startswith('art/') and p.endswith('.py'))),
      'capture_records':sorted(p for p in tracked if p.startswith('art/') and ('/captures/' in p or 'manifest' in p.lower()) and p.endswith(('.md','.json'))),
      'pipeline_scripts':sorted(p for p in htracked if relevant_hb(p)),
      'design_and_handoff_records':{'tech_priests':sorted(p for p in tracked if p.startswith(('docs/art/metallic-hydrogen-chain/','art/source-to-3d/shared-parts/')) and p.endswith(('.md','.json'))),'hb':sorted(p for p in htracked if p.startswith('docs/handoffs/') and any(tag in p.lower() for tag in ('refinery','mh7','model','fmpl')))},
      'unresolved_requested_assets':['lumberyard actual earlier-chat source','native reactor v14 package bytes','complete source-faithful metallic-hydrogen machine family; tracked designs and purifier iterations are partial work'],
      'no_automatic_done_claims':True}
    source_register=root/'docs/art/external-model-sources.json'
    if source_register.is_file():
        report['external_model_source_register']={'path':source_register.relative_to(root).as_posix(),'sha256':hashlib.sha256(source_register.read_bytes()).hexdigest(),'status':json.loads(source_register.read_text(encoding='utf-8'))['status']}
    a.out.parent.mkdir(parents=True,exist_ok=True); a.out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({'sprites':len(sprites),'families':len(set(r['family'] for r in sprites)), 'models_and_packages':len(report['model_sources_and_exports']), 'heads':[report['tech_priests_head'],report['pipeline_head']]}))
if __name__=='__main__':main()
