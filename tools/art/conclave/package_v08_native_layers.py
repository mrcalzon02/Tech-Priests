"""Compose real source renders as a static body, ambient replacements and light."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';C=O/'captures';base=np.array(Image.open(C/'placement-base.png').convert('RGBA'),dtype=np.float64)/255;b=base[:,:,3:4];B=base[:,:,:3]*b
normal=Image.new('RGBA',(6144,6144));glow=Image.new('RGBA',(3072,3072));errors=[]
for i in range(144):
 target=np.array(Image.open(O/'motion-frames-clean'/('%03d.png'%i)).convert('RGBA'),dtype=np.float64)/255;a=target[:,:,3:4];A=target[:,:,:3]*a;layer=np.zeros_like(target)
 opaque=b[:,:,0]>.995;empty=b[:,:,0]<.005;edge=~(opaque|empty);changed=np.max(np.abs(A-B),axis=2)>1/255
 # Opaque receivers may be replaced without alpha buildup. New flames/smoke
 # composite against clear pixels. Shared antialiased body edges stay on the
 # static body instead of doubling the silhouette.
 mask=opaque&changed;layer[mask,:3]=target[mask,:3];layer[mask,3]=1;layer[empty]=target[empty]
 gain=np.clip((a-b)/np.maximum(1-b,1e-8),0,1);added=edge&(gain[:,:,0]>.01);L=(A-B*(1-gain))/np.maximum(gain,1e-8);layer[added,:3]=np.clip(L[added],0,1);layer[added,3]=gain[added,0]
 result=layer[:,:,:3]*layer[:,:,3:4]+B*(1-layer[:,:,3:4]);errors.append(float(np.mean(np.abs(result-A))*255));out=Image.fromarray(np.uint8(np.clip(layer*255,0,255)));normal.paste(out,((i%12)*512,(i//12)*512))
 im=Image.open(O/'glow-frames'/('%03d.png'%i)).convert('RGBA');glow.paste(im,((i%12)*256,(i//12)*256))
normal.save(C/'ambient-effects.png');glow.save(C/'ambient-light.png')
receipt=dict(passed=max(errors)<.5,mean_rgb_error_255=max(errors),composition='Porter-Duff replacement on opaque receivers, true new flames/smoke against clear pixels, shared antialiased edges retained once.',light='Actual 256px Cycles ambient emission/illumination pass; native additive light layer, same camera and source frame sequence.',source_sha256=hashlib.sha256((O/'conclave-center-v08.blend').read_bytes()).hexdigest())
(O/'native-layer-composition.json').write_text(json.dumps(receipt,indent=2));assert receipt['passed'];print('V08_SEPARATE_NATIVE_BODY_EFFECTS_LIGHT_PACKED',max(errors))
