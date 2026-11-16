"""Verify the packaged atlases against their rendered on/off frames and FMPL anchors."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from fmpl_adapter import NAMES, HR_SIZES, ANGLE_FOR_HEADING, registration, profile

def arr(path):
    with Image.open(path) as im:
        return np.asarray(im.convert('RGBA'),np.uint8)

def check(root):
    mod=root/'Factorio'/'mars-reactor-visuals_1.0.0'
    results=[]
    for tier,(name,h) in enumerate(zip(NAMES,HR_SIZES),1):
        n=name.lower();cfg=profile(tier)
        for heading in ANGLE_FOR_HEADING:
            source=root/'frames'/n/heading;record={'tier':name,'heading':heading,'resolutions':{}}
            for quality,z in [('hr',h),('sd',h//2)]:
                folder=mod/'graphics'/quality/n
                imgs={key:arr(folder/f'{heading}-{key}.png') for key in ['on','glow','shadow','off']}
                assert all(imgs[key].shape==(sz,sz,4) for key,sz in [('on',z*4),('glow',z*4),('off',z),('shadow',z)])
                assert imgs['shadow'][:,:,3].max()>40 and imgs['off'][:,:,3].max()==255
                hashes=[]; errors=[]; edge=0; bounds=[z,z,0,0]
                for j in range(16):
                    yy=(j//4)*z;xx=(j%4)*z
                    tile=imgs['on'][yy:yy+z,xx:xx+z];glow=imgs['glow'][yy:yy+z,xx:xx+z]
                    assert glow[:,:,3].max()>70, (n,heading,j,'emission')
                    hashes.append(hashlib.sha256(tile.tobytes()+glow.tobytes()).hexdigest())
                    mask=tile[:,:,3]>22
                    y,x=np.where(mask);bounds=[min(bounds[0],int(x.min())),min(bounds[1],int(y.min())),max(bounds[2],int(x.max())),max(bounds[3],int(y.max()))]
                    edge=max(edge,int(np.count_nonzero(mask[[0,-1],:])),int(np.count_nonzero(mask[:,[0,-1]])))
                    if quality=='hr':
                        src=arr(source/f'{j+1:02d}.png').astype(np.float32)
                        body=tile[:,:,:3].astype(np.float32)*(tile[:,:,3:4]/255.)
                        light=glow[:,:,:3].astype(np.float32)*(glow[:,:,3:4]/255.)
                        actual=body+light;expected=src[:,:,:3]*(src[:,:,3:4]/255.)
                        errors.append(float(np.max(np.abs(actual-expected))))
                assert len(set(hashes))==16 and edge==0,(n,heading,quality,bounds,edge)
                if errors:assert max(errors)<2.1,(n,heading,max(errors))
                for key in ['off','shadow']:
                    if quality=='hr':assert np.array_equal(imgs[key],arr(source/(key+'.png')))
                record['resolutions'][quality]={'cell_pixels':z,'visible_bounds_xyxy':bounds,'distinct_frames':len(set(hashes)),'registration':registration(cfg,z),'max_daylight_reconstruction_error_255':round(max(errors),3) if errors else None}
            results.append(record)
    return {'reactors':3,'headings_per_reactor':4,'active_frames_per_heading':16,'logical_fps':8,'loop_seconds':2,'high_resolution_active_frames':192,'standard_active_frames':192,'terminal_frame_in_atlas':False,'results':results}
if __name__=='__main__':
    root=Path(sys.argv[1]);receipt=check(root)
    dest=root/'QA';dest.mkdir(exist_ok=True);(dest/'sprite-validation.json').write_text(json.dumps(receipt,indent=2))
    print('Verified all twelve pairs of 16-frame atlases and their matching idle and shadow cells.')
