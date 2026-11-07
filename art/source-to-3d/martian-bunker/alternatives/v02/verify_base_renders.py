from PIL import Image,ImageChops
from pathlib import Path
import numpy as np,json
O=Path(__file__).resolve().parent;control=np.array(Image.open(O/'Intact_Source_Base_Control.png').convert('RGBA')).astype('float32');r={}
for v in ['energy_dish','grenade_lobber_12']:
 image=np.array(Image.open(O/(v+'_Base_Preservation_Check.png')).convert('RGBA')).astype('float32');diff=np.abs(control-image)
 r[v]={'same_canvas':list(image.shape)==list(control.shape),'identical_pixels':bool((diff==0).all()),'mean_absolute_channel_difference_0_to_255':float(diff.mean()),'maximum_channel_difference_0_to_255':float(diff.max())}
 assert diff.mean()<=.001,r[v]
(O/'base_render_comparison.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
