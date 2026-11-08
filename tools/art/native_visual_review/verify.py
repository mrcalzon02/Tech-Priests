from PIL import Image,ImageDraw,ImageFont,ImageChops
import pathlib,json,hashlib,math,argparse
p=argparse.ArgumentParser(description='Verify actual native attachment receipts and build unaltered-screenshot proof boards.');p.add_argument('--fixture-root',type=pathlib.Path,default=pathlib.Path('work/factorio-visual-review'));p.add_argument('--baseline',type=pathlib.Path);p.add_argument('--candidate',type=pathlib.Path);p.add_argument('--repo',type=pathlib.Path,default=pathlib.Path('C:/GITS/Tech-Priests'));p.add_argument('--outputs',type=pathlib.Path,default=pathlib.Path('outputs'));args=p.parse_args();R=args.fixture_root;B=args.baseline or R/'original-expanded-sweep';A=args.candidate or R/'verified-final';args.outputs.mkdir(parents=True,exist_ok=True)
before=json.loads((B/'attachment-readback.json').read_text());after=json.loads((A/'attachment-readback.json').read_text());disconnected=json.loads((A/'disconnected-readback.json').read_text())
old={e['name']:e for e in before['entities'] if e['name'].endswith('thruster')};new={e['name']:e for e in after['entities'] if e['name'].endswith('thruster')}
expected_edges={'thruster':2,'hydrogen-thruster':1,'thetazine-thruster':2,'void-fusion-thruster':4,'large-void-fusion-thruster':1};probes={}
for name,edge in expected_edges.items():
 successful=[p['last_foundation_tile_y'] for p in new[name]['platform_edge_geometry'] if p['can_place']]
 assert successful==[edge],(name,successful)
 probes[name]={'original_legal_edges':[p['last_foundation_tile_y'] for p in old[name]['platform_edge_geometry'] if p['can_place']],'corrected_legal_edges':successful}
 if name not in ('thruster','thetazine-thruster'):assert probes[name]['original_legal_edges']==[],name
endpoint_error={}
for name in ('hydrogen-thruster','thetazine-thruster'):
 assert len(new[name]['connections'])==2
 for c in new[name]['connections']:
  assert c['connected_name']=='pipe'
  assert max(abs(c['target_position'][k]-c['connected_position'][k]) for k in ('x','y'))<1e-9
 endpoint_error[name]={'original_max_axis_offset_tiles':max(abs(c['target_position'][k]-c['connected_position'][k]) for c in old[name]['connections'] for k in ('x','y')),'corrected_max_axis_offset_tiles':0}
for e in disconnected['entities']:assert all('connected_name' not in c for c in e['connections'])
boilers=[e for e in after['entities'] if e['label'].startswith('boiler-connected')];assert len(boilers)==4
for e in boilers:
 assert len(e['connections'])==2
 for c in e['connections']:assert c['connected_name']=='pipe' and c['target_position']==c['connected_position']
files={}
for label,folder in [('baseline',B),('corrected',A)]:
 for p in folder.glob('*.png'):
  with Image.open(p) as image:image.verify()
  files[label+'/'+p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);board=Image.new('RGB',(1500,790),(36,40,45));draw=ImageDraw.Draw(board);draw.text((12,10),'Native Factorio 2.1.24 — actual pipe-cap rendering, connected and disconnected',font=font,fill='white')
for row,name in enumerate(('hydrogen-thruster','thetazine-thruster')):
 for col,(folder,state,label) in enumerate([(B,'connected','Before: bare pipe ends'),(A,'connected','Corrected: native connector caps'),(A,'disconnected','Corrected: pipes disconnected')]):
  with Image.open(folder/(name+'-'+state+'.png')) as im:tile=im.crop((80,170,720,610)).resize((500,344),Image.Resampling.LANCZOS);board.paste(tile,(col*500,44+row*370))
  draw.text((col*500+10,44+row*370+346),name+' / '+label,font=font,fill='white')
board.save(args.outputs/'native-thruster-cap-proof.png')
boiler=Image.open(A/'boiler-four-directions.png').convert('RGB');bb=Image.new('RGB',(1600,1044),(36,40,45));bb.paste(boiler,(0,44));d=ImageDraw.Draw(bb);d.text((12,10),'Native boiler V08 — N / E / S / W; disconnected top row, connected bottom row',font=font,fill='white');bb.save(args.outputs/'native-boiler-four-directions-proof.png')
module=args.repo/'tech-priests_src/prototypes/compatibility/thruster-mounting-visuals.lua';version=json.loads((args.repo/'tech-priests_src/info.json').read_text())['version'];installed=R/f'mods/tech-priests_{version}/prototypes/compatibility/thruster-mounting-visuals.lua';assert module.read_bytes()==installed.read_bytes()
report={'status':'PASS_ATTACHMENT_GEOMETRY_AND_CAPTURE_INTEGRITY_VISUAL_REVIEW_REQUIRED','client':'Factorio 2.1.24 graphical / high quality / low VRAM residency','module_sha256':hashlib.sha256(module.read_bytes()).hexdigest(),'baseline_module_sha256':hashlib.sha256((R/'baseline-original-thruster-mounting.lua').read_bytes()).hexdigest(),'scope':'Native prototype/render/attachment checks only; no fuel use, thrust, AI, logistics, combat or behavior/regression suite invoked','placement_sweep':{'last_foundation_tile_y_tested':list(range(-1,7)),'results':probes},'pipe_endpoint_alignment':endpoint_error,'boiler_four_directions_eight_pipe_connections_match':True,'disconnected_states_have_no_connected_pipe_targets':True,'screenshots_sha256':files,'full_model_completion':False,'remaining':'Thruster authored 3D geometry/surfacing and final model-to-sprite export remain open; this slice fixes native attachment geometry and connector graphics.'}
(args.outputs/'native-attachment-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':report['status'],'placement_results':probes,'endpoint_alignment':endpoint_error}))
