import bpy,json,hashlib
import numpy as np
from pathlib import Path
R=Path(__file__).resolve().parent;O=R/'client-fmpl-v02';A=R/'authored-v02'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def pixels(p):
 im=bpy.data.images.load(str(p),check_existing=False);w,h=im.size;data=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)[::-1].copy();bpy.data.images.remove(im);return data
def crop(p,roi):
 x,y,w,h=roi;return pixels(p)[y:y+h,x:x+w,:3]

for face,rois in {'north':[[316,335,30,55],[422,335,30,55]],'east':[[363,390,50,55]]}.items():
 def feature(name):
  im=pixels(O/(face+'-'+name+'.png'));vv=[]
  for x,y,w,h in rois:
   a=im[y:y+h,x:x+w,:3];vv.append((a-a.mean((0,1),keepdims=True)).ravel())
  return np.concatenate(vv)
 refs=np.stack([feature('motion-%02d'%i)for i in range(32)])
 for a,b in [('empty-a','empty-b'),('stopped-a','stopped-b'),('full-a','full-b'),('starved-a','starved-b'),('cold-steam-a','cold-steam-b')]:
  out=[]
  for label in [a,b]:
   d=((refs-feature(label))**2).mean(1);order=np.argsort(d);out.append([(int(i),round(float(d[i]),7))for i in order[:3]])
  print(face,a,b,out,flush=True)
