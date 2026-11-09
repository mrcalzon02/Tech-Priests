#!/usr/bin/env python3
"""Produce two-view visual inventory pages of the extracted geometry-only GLBs."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import argparse,json,math
import numpy as np
import trimesh
from extract_native_geometry import preview

fontfile='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',required=True)
 p.add_argument('--offset',type=int,default=0);p.add_argument('--limit',type=int,default=32)
 p.add_argument('--face-budget',type=int,default=30000)
 a=p.parse_args();root=Path(a.root);allreceipts=sorted(root.glob('parts/*/receipt.json'))
 for receipt in allreceipts[a.offset:a.offset+a.limit]:
  r=json.loads(receipt.read_text());pid=r['id'];folder=receipt.parent
  if all((folder/(v+'.png')).is_file() for v in ('front','rear')):continue
  mesh=trimesh.load(folder/(pid+'.glb'),force='mesh',process=False)
  faces=np.asarray(mesh.faces,dtype=np.int32)
  verts=np.asarray(mesh.vertices,dtype=np.float64)
  if len(faces)>a.face_budget:
   # Deterministic preview-only sampling; never changes donor meshes.
   # Keep evenly spaced triangles across the surface for a low-cost thumbnail.
   indices=np.linspace(0,len(faces)-1,a.face_budget).astype(np.int64)
   faces=faces[indices]
  for angle,label in [(45,'front'),(225,'rear')]:
   img=folder/(label+'.png')
   if not img.is_file():preview(img,verts,faces,azimuth=angle,w=320,h=240)
  print('RENDERED',pid,flush=True)
 print('RENDER_BATCH_DONE',a.offset,flush=True)

if __name__=='__main__':main()
