"""Model-specific UV raster bakes from actual geometry, edge and contact data."""
import bpy,bmesh,math,pathlib,numpy as np
from mathutils import Vector

def mineral_noise(points,frequency):
    """Isotropic smooth lattice grain with analytic world derivatives."""
    q=points*frequency;cell=np.floor(q);f=q-cell;w=f*f*(3-2*f);dw=6*f*(1-f)
    value=np.zeros(len(points));gradient=np.zeros_like(points)
    for x in (0,1):
        for y in (0,1):
            for z in (0,1):
                corner=cell+np.asarray((x,y,z));raw=np.sin(corner@np.asarray((127.1,311.7,74.7)))*43758.5453;h=raw-np.floor(raw)
                wx=w[:,0] if x else 1-w[:,0];wy=w[:,1] if y else 1-w[:,1];wz=w[:,2] if z else 1-w[:,2]
                value+=h*wx*wy*wz
                gradient[:,0]+=h*(dw[:,0] if x else -dw[:,0])*wy*wz*frequency
                gradient[:,1]+=h*wx*(dw[:,1] if y else -dw[:,1])*wz*frequency
                gradient[:,2]+=h*wx*wy*(dw[:,2] if z else -dw[:,2])*frequency
    return value,gradient

def bake(objects,out,label,size,contacts,mineral=False):
    out=pathlib.Path(out);out.mkdir(parents=True,exist_ok=True);rows=[];object_roles={};object_contacts={}
    palette={'rail':((.095,.107,.105),.77,.57),'bronze':((.235,.160,.060),.81,.52),'cast':((.039,.045,.038),.72,.65),'edge':((.15,.16,.135),.76,.54),'green':((.006,.10,.001),.03,.45),'stone':((.018,.022,.012),0,.88),'crushed':((.029,.032,.018),0,.94)}
    for o in objects:
        me=o.data
        # Each baked triangle needs independent corner UVs. Triangulate actual
        # n-gon rim faces first; assigning triangle islands to shared polygon
        # loops otherwise overwrote neighboring UVs in the initial V08 study.
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.calc_loop_triangles();world=[o.matrix_world@v.co for v in me.vertices]
        role=[]
        for m in me.materials:
            n=m.name.lower()
            if mineral:role.append('green' if 'energized' in n or 'cleavage' in n else 'crushed' if 'crushed' in n else 'stone')
            else:role.append('green' if 'green' in n else 'bronze' if 'bronze' in n or 'copper' in n else 'edge' if 'edge' in n else 'cast' if 'cast iron' in n or 'hull' in n else 'rail')
        object_roles[o.name]=role
        cc=[c['point'] for c in contacts if o.name in (c['a'],c['b'])]
        object_contacts[o.name]=np.asarray(cc,dtype=np.float64).reshape((-1,3)) if cc else np.zeros((0,3))
        # Welded rock fragments expose real sharp/chipped edges. Coplanar
        # triangulation diagonals are excluded from the crushed-edge mask.
        adjacency={}
        for p in me.polygons:
            for a,b in zip(p.vertices,p.vertices[1:]+p.vertices[:1]):adjacency.setdefault(tuple(sorted((a,b))),[]).append(p.index)
        sharp=set()
        for key,faces in adjacency.items():
            if len(faces)!=2 or me.polygons[faces[0]].normal.dot(me.polygons[faces[1]].normal)<.82 or me.polygons[faces[0]].material_index!=me.polygons[faces[1]].material_index:sharp.add(key)
        for t in me.loop_triangles:
            vv=[world[i] for i in t.vertices];a,b,c=vv;u=max((b-a,c-a,c-b),key=lambda q:q.length).normalized();normal=(b-a).cross(c-a).normalized();v=normal.cross(u)
            xy=np.asarray([[p.dot(u),p.dot(v)] for p in vv]);lo=xy.min(0);xy-=lo;wh=xy.max(0);edges=[]
            for j,k in ((0,1),(1,2),(2,0)):
                if tuple(sorted((t.vertices[j],t.vertices[k]))) in sharp:edges.append((np.asarray(vv[j]),np.asarray(vv[k])))
            rows.append({'o':o,'loops':list(t.loops),'world':np.asarray(vv),'u':np.asarray(u),'v':np.asarray(v),'xy':xy,'w':float(wh[0]),'h':float(wh[1]),'role':role[t.material_index],'edges':edges})
    pad=.009 if mineral else .006
    area=sum((r['w']+pad*2)*(r['h']+pad*2) for r in rows);width=max(math.sqrt(area)*1.10,max(r['w']+pad*2 for r in rows));x=y=row_h=0
    for r in sorted(rows,key=lambda a:a['h'],reverse=True):
        w=r['w']+2*pad;h=r['h']+2*pad
        if x+w>width and x>0:y+=row_h;x=row_h=0
        r['at']=np.array((x+pad,y+pad));x+=w;row_h=max(row_h,h)
    scale=max(width,y+row_h);occ=np.zeros((size,size),dtype=bool)
    maps={k:np.zeros((size,size,4),dtype=np.float32) for k in ('basecolor','metalrough','normal','grain','crushed','pressure','emission')}
    for a in maps.values():a[:,:,3]=1
    maps['normal'][:,:,:3]=(.5,.5,1);maps['metalrough'][:,:,:3]=(1,.9,0)
    for o in objects:
        # Blender5 removes companion UV selection attributes alongside a map;
        # retaining list references can leave invalid '.uv_select_vert' entries.
        while len(o.data.uv_layers):o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name='AuthoredAtlasUV')
    amps=np.asarray((.0017,.0008,.00045))*(1 if mineral else .075)
    for r in rows:
        uv=(r['xy']+r['at'])/scale;layer=r['o'].data.uv_layers.active
        for li,q in zip(r['loops'],uv):layer.data[li].uv=q
        tri=uv*size;low=np.maximum(0,np.floor(tri.min(0)).astype(int));high=np.minimum(size-1,np.ceil(tri.max(0)).astype(int))
        xx,yy=np.meshgrid(np.arange(low[0],high[0]+1),np.arange(low[1],high[1]+1));pp=np.stack((xx+.5,yy+.5),axis=-1)
        a,b,c=tri;v0=b-a;v1=c-a;den=v0[0]*v1[1]-v0[1]*v1[0]
        if abs(den)<1e-11:continue
        q=pp-a;bb=(q[:,:,0]*v1[1]-q[:,:,1]*v1[0])/den;cc=(v0[0]*q[:,:,1]-v0[1]*q[:,:,0])/den;aa=1-bb-cc;valid=(aa>=-1e-7)&(bb>=-1e-7)&(cc>=-1e-7)
        if not valid.any():continue
        px=xx[valid];py=yy[valid];p=aa[valid,None]*r['world'][0]+bb[valid,None]*r['world'][1]+cc[valid,None]*r['world'][2]
        noises=[mineral_noise(p,f) for f in (35,85,200)];grain=np.clip(.5+sum(weight*(vv-.5)*1.5 for weight,(vv,_) in zip((.57,.28,.15),noises)),0,1)
        edge=np.zeros(len(p))
        for a,b in r['edges']:
            d=b-a;t=np.clip(((p-a)@d)/(d@d),0,1);dist=np.linalg.norm(p-a-t[:,None]*d,axis=1);edge=np.maximum(edge,np.exp(-(dist/(.013 if mineral else .0045))**2))
        ccdata=object_contacts[r['o'].name];pressure=np.zeros(len(p))
        for contact in ccdata:
            dd=np.sum((p-contact)**2,axis=1);pressure=np.maximum(pressure,np.exp(-dd/(.035 if mineral else .016)**2))
        base,metal,rough=palette[r['role']];base=np.asarray(base)[None,:]*(.78+.45*grain[:,None])
        if mineral:
            broad,_=mineral_noise(p,3.7);medium,_=mineral_noise(p,14)
            # Broad olive/charcoal mineral planes and angular sparse ochre
            # fracture web follow the pinned cold legacy sprite, not brass.
            # Distinct cells make broken granular faces legible without glow.
            q=p*19;cell=np.floor(q);best=np.full(len(p),1e9);second=best.copy()
            for ax in (-1,0,1):
                for ay in (-1,0,1):
                    for az in (-1,0,1):
                        cp=cell+np.asarray((ax,ay,az));h=np.sin(cp@np.asarray((127.1,311.7,74.7))+.37)*43758.5453;h-=np.floor(h)
                        site=cp+np.stack((.2+.6*h,.2+.6*np.mod(h*7.13,1),.2+.6*np.mod(h*13.71,1)),axis=1);dd=np.linalg.norm(q-site,axis=1)
                        second=np.minimum(second,np.maximum(best,dd));best=np.minimum(best,dd)
            broken,_=mineral_noise(p,53);width=.025+.07*np.clip(grain*broken,0,1)
            vein=np.exp(-((second-best)/width)**2)*np.clip((medium-.43)*4,0,1)*np.clip((broken-.29)*3,0,1)
            base*=np.clip(.22+1.75*broad[:,None]+.75*(medium[:,None]-.5)+.65*(grain[:,None]-.5),.20,2.15)
            if r['role']!='green':base+=vein[:,None]*np.asarray((.067,.052,.022))*(.5+.5*grain[:,None])
            base+=edge[:,None]*np.asarray((.034,.030,.016))*(.25+.75*grain[:,None]);base*=1-pressure[:,None]*.22
            rr=np.clip(rough+(grain-.5)*.31-pressure*.16,.62,.99)
        else:
            base+=edge[:,None]*np.asarray((.035,.037,.025))*(.25+.75*grain[:,None]);base*=1-pressure[:,None]*.28
            rr=np.clip(rough+(grain-.5)*.10-pressure*.12,.24,.85)
        grad=sum(amp*gg for amp,(_,gg) in zip(amps,noises));du=grad@r['u'];dv=grad@r['v'];nn=np.stack((-du,-dv,np.ones(len(p))),axis=1);nn/=np.linalg.norm(nn,axis=1)[:,None]
        maps['basecolor'][py,px,:3]=base;maps['metalrough'][py,px,:3]=np.stack((np.ones(len(p)),rr,np.full(len(p),metal)),axis=1);maps['normal'][py,px,:3]=nn*.5+.5
        for key,val in [('grain',grain),('crushed',edge),('pressure',pressure)]:maps[key][py,px,:3]=val[:,None]
        if r['role']=='green':maps['emission'][py,px,:3]=np.stack((.025*(.4+.6*grain),.45+.55*grain,np.full(len(p),.001)),axis=1)
        occ[py,px]=True
    # Two-pixel gutters contain nearest painted values, not black atlas seams.
    for _ in range(2):
        base_occ=occ.copy()
        for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
            valid=np.roll(base_occ,(dy,dx),(0,1))&~occ
            if dy==1:valid[0,:]=False
            if dy==-1:valid[-1,:]=False
            if dx==1:valid[:,0]=False
            if dx==-1:valid[:,-1]=False
            for arr in maps.values():arr[valid]=np.roll(arr,(dy,dx),(0,1))[valid]
            occ|=valid
    images={};decoded=[]
    for key,arr in maps.items():
        if key=='basecolor':
            linear=np.clip(arr[:,:,:3],0,1)
            arr[:,:,:3]=np.where(linear<=.0031308,linear*12.92,1.055*np.power(linear,1/2.4)-.055)
        im=bpy.data.images.new(label+' '+key,width=size,height=size,alpha=True);im.filepath_raw=str(out/(label+'-'+key+'.png'));im.file_format='PNG'
        if key not in ('basecolor','emission'):im.colorspace_settings.name='Non-Color'
        # Generated-image colorspace changes clear its buffer. Configure first,
        # THEN write/update/save; the initial V08c black data maps were rejected.
        im.pixels.foreach_set(arr.ravel());im.update();im.save();im.pack();images[key]=im
        loaded=bpy.data.images.load(im.filepath_raw,check_existing=False)
        if key not in ('basecolor','emission'):loaded.colorspace_settings.name='Non-Color'
        pixels=np.asarray(loaded.pixels[:],dtype=np.float32).reshape((size,size,4));rgb=pixels[:,:,:3]
        if key=='normal':assert np.median(rgb[:,:,2])>.9 and .35<np.median(rgb[:,:,0])<.65,(label,key,'invalid tangent normal')
        if key=='metalrough':assert float(rgb[:,:,1].mean())>.25,(label,key,'blank roughness')
        if float(arr[:,:,:3].max())>.1:assert float(rgb.max())>.1,(label,key,'blank decoded data')
        decoded.append({'channel':key,'decoded_rgb_min':rgb.min((0,1)).tolist(),'decoded_rgb_max':rgb.max((0,1)).tolist(),'decoded_rgb_mean':rgb.mean((0,1)).tolist(),'nonblank_expected':float(arr[:,:,:3].max())>.1})
        bpy.data.images.remove(loaded)
    materials=[]
    for is_green in (False,True):
        mat=bpy.data.materials.new(label+(' energized recess' if is_green else ' authored surfaces'));mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
        for key in ('basecolor','metalrough','normal')+ (('emission',) if is_green else ()):
            tex=nt.nodes.new('ShaderNodeTexImage');tex.image=images[key]
            if key=='basecolor':nt.links.new(tex.outputs[0],bs.inputs['Base Color'])
            elif key=='metalrough':sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs[0],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
            elif key=='normal':nn=nt.nodes.new('ShaderNodeNormalMap');nn.uv_map='AuthoredAtlasUV';nt.links.new(tex.outputs[0],nn.inputs['Color']);nt.links.new(nn.outputs[0],bs.inputs['Normal'])
            else:nt.links.new(tex.outputs[0],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=2.8 if mineral else 7
        materials.append(mat)
    for o in objects:
        roles=object_roles[o.name];indices=[1 if roles[p.material_index]=='green' else 0 for p in o.data.polygons]
        o.data.materials.clear()
        for mat in materials:o.data.materials.append(mat)
        for p,i in zip(o.data.polygons,indices):p.material_index=i
    return {'label':label,'size':[size,size],'meshes':[o.name for o in objects],'triangles':len(rows),'coverage_with_gutter':float(occ.mean()),'baked_channels':list(maps),'decoded_map_semantic_checks':decoded,'atlas_uv_bounds':[[float(min(((r['xy']+r['at'])/scale).min() for r in rows))],[float(max(((r['xy']+r['at'])/scale).max() for r in rows))]],'method':'Actual unique geometry UV atlas; world-scale mineral/tool grain, real sharp/chipped edge mask, current measured receiver contact-pressure mask; tangent-space normal derived analytically in each actual triangle UV frame. Not a uniform tiled stripe shader.'}
