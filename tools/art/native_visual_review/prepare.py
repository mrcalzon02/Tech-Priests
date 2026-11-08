import pathlib,subprocess,json,shutil,hashlib,argparse
p=argparse.ArgumentParser(description='Prepare an isolated exact working-tree copy for native graphics review.');p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--workdir',type=pathlib.Path,required=True);p.add_argument('--sprite-dependency',type=pathlib.Path,help='Optional installed Mechanicus ZIP for coexistence review; standalone is the default');p.add_argument('--factorio-data',type=pathlib.Path,default=pathlib.Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data'));a=p.parse_args()
repo=a.repo.resolve();root=a.workdir.resolve();root.mkdir(parents=True,exist_ok=True)
source=repo/'tech-priests_src';info=json.loads((source/'info.json').read_text());dest=root/'mods'/('tech-priests_'+info['version']);dest.mkdir(parents=True,exist_ok=True)
tracked=subprocess.check_output(['git','-C',str(repo),'ls-files','-z','tech-priests_src'],text=True).split('\0');files=[]
for name in tracked:
 if not name:continue
 rel=pathlib.Path(name).relative_to('tech-priests_src');target=dest/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(repo/name,target);files.append({'path':rel.as_posix(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
review=root/'mods/model-visual-review_0.1.0';scenario=review/'scenarios/model-placement';scenario.mkdir(parents=True,exist_ok=True)
(review/'info.json').write_text(json.dumps({'name':'model-visual-review','version':'0.1.0','title':'Local structure graphics review','author':'Local review','factorio_version':'2.1','dependencies':['base >= 2.1.0','space-age >= 2.1.0','tech-priests']},indent=2)+'\n')
shutil.copy2(pathlib.Path(__file__).with_name('model-placement-control.lua'),scenario/'control.lua')
names=['base','quality','elevated-rails','recycler','space-age','tech-priests','model-visual-review']
if a.sprite_dependency is not None:
 dependency=a.sprite_dependency.resolve();assert dependency.is_file(),'Requested coexistence dependency is missing';shutil.copy2(dependency,root/'mods'/dependency.name);names.append('mechanicus-reborn')
(root/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in names]},indent=2)+'\n')
userdata=root/'userdata';userdata.mkdir(exist_ok=True)
(root/'config.ini').write_text('[path]\nread-data='+a.factorio_data.resolve().as_posix()+'\nwrite-data='+userdata.as_posix()+'\n[general]\nlocale=en\n[graphics]\nfull-screen=false\ngraphics-quality=high\nvideo-memory-usage=low\ntexture-compression-level=high-quality\n[other]\nautosave-interval=0\n')
(root/'source-checkpoint.json').write_text(json.dumps({'repo_head':subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip(),'scope':'Exact tracked mod copy, separate new single-player graphical review scenario. No user saves/config modified, no behavior/regression assertions.','files':files},indent=2)+'\n');print('VISUAL_FIXTURE_PREPARED',len(files))
