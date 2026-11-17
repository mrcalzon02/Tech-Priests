"""Pack checked source poses into heading-specific native rendering atlases."""
import argparse,bisect,hashlib,json,math
from pathlib import Path
from PIL import Image,ImageChops,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--capture',type=Path,default=ROOT/'build/artillery-native/animation-v19');p.add_argument('--shadows',type=Path);p.add_argument('--output',type=Path,default=ROOT/'build/artillery-native/animated-art-v19');p.add_argument('--pilot',action='store_true');a=p.parse_args()
receipt=json.loads((a.capture/'capture.json').read_text());identity=receipt['identity'];headings=sorted(receipt['completed_headings'])
shadow_identity=None
if a.shadows:
    shadow_receipt=json.loads((a.shadows/'capture.json').read_text());shadow_identity=shadow_receipt['identity']
    assert shadow_identity['source_sha256']==identity['source_sha256'] and shadow_identity['ticks']==identity['ticks']
    headings=sorted(set(headings)&set(shadow_receipt['completed_headings']))
assert a.pilot or (len(headings)==64 and shadow_identity),'All body and moving-shadow headings are required for production'
a.output.mkdir(parents=True,exist_ok=True)
cell=identity['cell'];scale=identity['scale'];ticks=identity['ticks'];records={}
envelope=Image.new('L',(cell,cell));envelope.putdata([round(255*min(1,x/8,y/8,(cell-1-x)/8,(cell-1-y)/8))for y in range(cell)for x in range(cell)])
for d in headings:
    layers={}
    for layer in ('body','shell0','shell1','shell2')+(('shadow',)if shadow_identity else ()):
        layer_identity=shadow_identity if layer=='shadow'else identity
        layer_scale=layer_identity['scale'];layer_capture=a.shadows if layer=='shadow'else a.capture
        frames=[];union=None
        for i in range(len(ticks)):
            with Image.open(layer_capture/f'd{d:02}-{layer}-{i:03}.png') as src:im=src.convert('RGBA')
            assert im.size==(cell,cell)
            if layer=='shadow':
                # The shadow-catcher ratio has low amplitude background noise.
                # Fade only the outer eight pixels to a genuinely empty border.
                im.putalpha(ImageChops.multiply(im.getchannel('A'),envelope))
            alpha=im.getchannel('A');b=alpha.getbbox()
            if b:
                assert b[0]>0 and b[1]>0 and b[2]<cell and b[3]<cell,(d,layer,i,b)
                union=b if union is None else (min(union[0],b[0]),min(union[1],b[1]),max(union[2],b[2]),max(union[3],b[3]))
            frames.append(im)
        b=(max(0,union[0]-2),max(0,union[1]-2),min(cell,union[2]+2),min(cell,union[3]+2)) if union else (0,0,1,1)
        w,h=b[2]-b[0],b[3]-b[1];cols=max(8,math.ceil(len(frames)/max(1,8192//h)));rows=math.ceil(len(frames)/cols)
        atlas=Image.new('RGBA',(w*cols,h*rows));assert max(atlas.size)<=8192
        for i,im in enumerate(frames):atlas.paste(im.crop(b),(i%cols*w,i//cols*h))
        filename=f'd{d:02}-{layer}.png';atlas.save(a.output/filename)
        with Image.open(a.output/filename) as packed:
            for i,im in enumerate(frames):assert packed.crop((i%cols*w,i//cols*h,(i%cols+1)*w,(i//cols+1)*h)).tobytes()==im.crop(b).tobytes()
        shift=[layer_identity['shift'][0]+((b[0]+b[2])/2-cell/2)*layer_scale/32,layer_identity['shift'][1]+((b[1]+b[3])/2-cell/2)*layer_scale/32]
        layers[layer]={'file':filename,'width':w,'height':h,'line_length':cols,'frame_count':len(frames),'scale':layer_scale,'shift':shift,'sha256':hashlib.sha256((a.output/filename).read_bytes()).hexdigest()}
    records[str(d)]=layers
    print('PACKED_ARTILLERY_DIRECTION',d,flush=True)
lookup=[max(0,bisect.bisect_right(ticks,t)-1) for t in range(601)]
data={'source_sha256':identity['source_sha256'],'complete':len(headings)==64 and bool(shadow_identity),'cell':cell,'scale':scale,'shift':identity['shift'],'ticks':ticks,'lookup':lookup,'headings':records}
def lua(v):
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,str):return json.dumps(v)
    if isinstance(v,(float,int)):return str(v)
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    return '{'+','.join('['+lua(k)+']='+lua(val) for k,val in v.items())+'}'
(a.output/'visuals.json').write_text(json.dumps(data,indent=2)+'\n')
(a.output/'artillery_barrage_visuals.lua').write_text('-- Generated checked source-pose atlases. Frame indices are zero based.\nreturn '+lua(data)+'\n')
geometry={'source_sha256':identity['source_sha256'],'scale':scale,'shift':identity['shift'],'muzzle':identity['muzzle_source'],'cell':cell}
(a.output/'artillery_barrage_geometry.lua').write_text('-- Generated actual source muzzle socket and projection.\nreturn '+lua(geometry)+'\n')
(a.output/'artillery_barrage_geometry.json').write_text(json.dumps(geometry,indent=2)+'\n')
heading=24 if 24 in headings else 16 if 16 in headings else headings[0]
canvas=Image.new('RGBA',(1024,1024));anchor=(512,800)
for filename in ('base-north-shadow.png','base-north.png'):
    with Image.open(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon'/filename)as source:
        im=source.convert('RGBA');s=.315463840961;im=im.resize((round(im.width*s*2),round(im.height*s*2)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(im,(round(anchor[0]-im.width/2),round(anchor[1]-1.110906552544*64-im.height/2)))
for layer in ('body','shell0','shell1','shell2'):
    with Image.open(a.capture/f'd{heading:02}-{layer}-000.png')as source:
        im=source.convert('RGBA').resize((round(cell*scale*2),)*2,Image.Resampling.LANCZOS)
        canvas.alpha_composite(im,(round(anchor[0]+identity['shift'][0]*64-im.width/2),round(anchor[1]+identity['shift'][1]*64-im.height/2)))
crop=canvas.crop(canvas.getchannel('A').getbbox());crop.thumbnail((120,120),Image.Resampling.LANCZOS)
icon=Image.new('RGBA',(128,128));icon.alpha_composite(crop,((128-crop.width)//2,(128-crop.height)//2));icon.save(a.output/'icon.png')
files=[record['file']for layers in records.values()for record in layers.values()]+['icon.png','visuals.json','artillery_barrage_visuals.lua','artillery_barrage_geometry.lua','artillery_barrage_geometry.json']
manifest={'status':'PACKED_ALL_DIRECTIONS'if data['complete']else 'ANIMATED_PILOT','source_sha256':data['source_sha256'],
 'directions':headings,'frames':len(ticks),'base_included':False,'native_static_cap_included':False,
 'shadow_processing':'Neutral family shadow-catcher ratio, outer eight pixels fade to an empty border.',
 'files':{filename:hashlib.sha256((a.output/filename).read_bytes()).hexdigest()for filename in files}}
(a.output/'assets.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ARTILLERY_ANIMATION_PACKED',len(headings),'headings; production complete:',data['complete'])
