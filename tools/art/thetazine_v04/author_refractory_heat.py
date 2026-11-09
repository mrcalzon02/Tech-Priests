"""UV-authored refractory heat, cooler behind each leaf's regenerative runs."""
import pathlib,numpy as np,json,hashlib
from PIL import Image
W=pathlib.Path(__file__).parent;R=W/'thermal-study-35';R.mkdir(exist_ok=False);n=1024;y,x=np.mgrid[0:n,0:n]/n;y=1-y;phase=(x*12)%1
def periodic_distance(a,b):return np.minimum(abs(a-b),1-abs(a-b))
cool=sum(np.exp(-(periodic_distance(phase,p)/.035)**2) for p in [.22,.36,.64,.78]);cool=np.clip(cool,0,1)
# Circumferential phase is periodic in U. Axial V follows the authored bell
# throat-to-lip frame, matching the plate and pipe coordinates rather than a
# generic texture applied independently of the model.
axial=.16+.74*np.exp(-((y-.47)/.32)**2);mottled=.62+.19*np.sin(x*np.pi*2*31+y*np.pi*2*6)+.12*np.sin(x*np.pi*2*73-y*np.pi*2*19)+.07*np.cos(x*np.pi*2*137+y*np.pi*2*41);fringe=np.exp(-((y-.94)/.035)**2)*.12
heat=np.clip(axial*mottled*(1-.65*cool)+fringe,0,1);rgb=np.stack((230*heat**1.05,90*heat**1.30,16*heat**1.60),axis=-1).astype(np.uint8);im=Image.fromarray(rgb,'RGB');im.save(R/'refractory-regenerative-heat.png');p=R/'refractory-regenerative-heat.png';receipt={'status':'AUTHORED_MODEL_UV_REFRACTORY_HEAT_REQUIRES_SOURCE_RENDER','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':[n,n],'mapping':'Global circumferential U, axial throat-to-lip V. Twelve leaf repeats; cooler lanes aligned approximately behind four regenerative runs per leaf. This is authored appearance, not thermal simulation.','surface_target':'Dark charred refractory with broken warm incandescence; no uniform pink/white face. Existing cold basecolor/metalrough/normal textures, exterior leaf fringe and full volumetric blue combustion preserved.'};(R/'texture-provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n');print(receipt['sha256'])
