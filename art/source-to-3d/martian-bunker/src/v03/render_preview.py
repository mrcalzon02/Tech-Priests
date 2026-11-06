"""Fixed camera color-identity diagnostic renderer with actual depth-buffer.
Used only to inspect structure before native Blender PBR rendering."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np, trimesh
from numba import njit
DIR=Path(__file__).resolve().parent
scene=trimesh.load(DIR/'martian_heavy_weapon_bunker_source_geometry_v03.glb',force='scene')
parts=list(scene.geometry.values())

@njit(cache=True)
def raster(points, depths, colors, zbuf, image):
    hh,ww=zbuf.shape
    for k in range(points.shape[0]):
        p0,p1,p2=points[k]
        x0,y0=p0; x1,y1=p1; x2,y2=p2
        minx=max(int(min(x0,x1,x2)),0); maxx=min(int(max(x0,x1,x2))+1,ww-1)
        miny=max(int(min(y0,y1,y2)),0); maxy=min(int(max(y0,y1,y2))+1,hh-1)
        denom=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
        if abs(denom)<.0001: continue
        for yy in range(miny,maxy+1):
            for xx in range(minx,maxx+1):
                x=xx+.5;y=yy+.5
                u=((y1-y2)*(x-x2)+(x2-x1)*(y-y2))/denom
                v=((y2-y0)*(x-x2)+(x0-x2)*(y-y2))/denom
                w=1-u-v
                if u>=0 and v>=0 and w>=0:
                    z=u*depths[k,0]+v*depths[k,1]+w*depths[k,2]
                    if z>zbuf[yy,xx]:
                        zbuf[yy,xx]=z
                        image[yy,xx]=colors[k]

def render(name,look_from,size=1000):
    e=np.asarray(look_from,float);e/=np.linalg.norm(e);look=-e
    right=np.cross(look,[0.,0.,1.]);right/=np.linalg.norm(right)
    up=np.cross(right,look);up/=np.linalg.norm(up)
    target=np.array([0,0,1.16],dtype=float)
    proj=np.array([right,up])
    allv=np.concatenate([m.vertices for m in parts])
    uv=(allv-target)@proj.T
    scale=min(size*.79/max(np.ptp(uv[:,0]),1),size*.78/max(np.ptp(uv[:,1]),1))
    offset=np.array([size*.50,size*.51])
    light=np.array([-0.7,-0.5,1.3]);light/=np.linalg.norm(light)
    triangles=[]; depths=[]; colors=[]
    for mesh in parts:
        v=mesh.vertices; face=mesh.faces;n=mesh.face_normals
        v2=(v-target)@proj.T *np.array([scale,-scale])+offset
        dep=v@e
        col=np.mean(mesh.visual.vertex_colors[:,:3],axis=0)
        for i,f in enumerate(face):
            if np.dot(n[i],e)<-.0001: continue
            k=.51+.56*max(float(np.dot(n[i],light)),0.0)
            k*=.95+.08*np.clip(np.mean(v[f,2])/3,0,1)
            triangles.append(v2[f]);depths.append(dep[f]);colors.append(np.clip(col*k,0,255).astype(np.uint8))
    img=np.empty((size,size,3),dtype=np.uint8);img[:]=(34,37,38)
    # Ground plane is rasterized as geometry behind bunker
    zbuf=np.full((size,size),-1e6)
    raster(np.array(triangles,dtype=np.float64),np.array(depths,dtype=np.float64),np.array(colors,dtype=np.uint8),zbuf,img)
    out=Image.fromarray(img,'RGB')
    d=ImageDraw.Draw(out)
    d.text((36,28),'RED TECH PRIESTS   /   FORTIFIED MARTIAN HEAVY-WEAPON BUNKER',fill=(211,194,162))
    d.text((36,size-43),'3x3 TILE ENGINEERING BLOCKOUT  |  v0.3  |  NO THIRD-PARTY MESHES',fill=(168,168,159))
    out.save(DIR/name)
    return out
render('bunker_front_isometric_v03.png',(5,-7,6))
render('bunker_rear_isometric_v03.png',(-5,7,6))
Image.open(DIR/'bunker_front_isometric_v03.png').resize((256,256),Image.Resampling.LANCZOS).save(DIR/'bunker_at_factorio_scale_preview_v03.png')
print('render complete',len(parts),'meshes')
