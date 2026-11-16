"""Cast skull escutcheons, cogitator instruments and operator consoles."""
import math
from functools import lru_cache
import bpy
import numpy as np
from mathutils import Vector
from common import box, rod, path, ball, mesh, mat, torus, part_snapshot, preserve_round_parts


def _smin(a, b, k):
    h=np.maximum(k-np.abs(a-b),0.0)/k
    return np.minimum(a,b)-h*h*k*.25


def _cranium_field(x,y,z):
    def ell(px,py,pz,rx,ry,rz):
        return (np.sqrt((px/rx)**2+(py/ry)**2+(pz/rz)**2)-1.0)*np.minimum(np.minimum(rx,ry),rz)
    a=np.abs(x)
    # The vault bulges behind the frontal bone. Cheeks bridge its temporal hollow.
    f=ell(x,y-.07,z-.28,.78,.57,.76)
    f=_smin(f,ell(x,y+.20,z+.15,.52,.36,.56),.14)
    f=_smin(f,ell(a-.49,y+.22,z+.18,.25,.23,.18),.09)
    f=_smin(f,ell(a-.63,y-.00,z+.12,.095,.28,.13),.06)
    f=_smin(f,ell(x,y+.28,z+.35,.337,.259,.275),.07)
    # Projecting supraorbital arch and vertical bridge of the nose.
    brow_z=.36+.13*(a-.32)
    f=_smin(f,ell(a-.32,y+.37,z-brow_z,.326,.17,.131),.105)
    f=_smin(f,ell(x,y+.449,z+.065,.117,.175,.355),.07)
    # Actual recessed eye sockets, narrower toward the temples, with fixed brows.
    eye_z=.095+.25*(a-.33)
    orbit=ell(a-.329,y+.535,z-eye_z,.243,.328,.196)
    f=np.maximum(f,-orbit)
    # Clipped double-lobed nasal cavity tapers to a single aperture above.
    wide=.038+.077*np.clip((-.07-z)/.265,0,1)
    nose=ell(a-.037,y+.530,z+.200,wide,.228,.174)
    f=np.maximum(f,-nose)
    # The upper jaw sinks below the broad malar process, leaving an articulated arch.
    inframalar=ell(a-.399,y+.334,z+.354,.099,.145,.091)
    f=np.maximum(f,-inframalar)
    # Temporal hollows behind cheekbones.
    temporal=ell(a-.625,y+.08,z+.255,.158,.14,.128)
    f=np.maximum(f,-temporal)
    # Root sockets and individual upper teeth. A human skull without a mandible.
    f=_smin(f,ell(x,y+.347,z+.533,.315,.164,.086),.035)
    for cx,cz,r in ((.046,-.613,.043),(.135,-.610,.040),(.219,-.605,.037),(.285,-.574,.033)):
        # Boxier incisors clearly project from the tapering maxillary alveolus.
        tx=(a-cx)/r
        ty=(y+.443-cx*.185)/.070
        tz=(z-cz)/(.107 if cx==.219 else .087)
        tooth=((abs(tx)**3+abs(ty)**3+abs(tz)**3)**(1/3)-1)*r
        f=_smin(f,tooth,.013)
    return f


@lru_cache(maxsize=1)
def _skull_surface():
    # Split every cube into the same six tetrahedra. Shared lattice-edge IDs
    # weld the orbit, malar hollows, narrow nasal opening and tooth interstices.
    from itertools import permutations
    n=46
    axis=np.linspace(-1.14,1.14,n)
    coords=np.stack(np.meshgrid(axis,axis,axis,indexing='ij'),axis=-1).reshape(-1,3)
    sdf=_cranium_field(*coords.T)
    vox=sdf.reshape((n,n,n))
    ids=np.arange(n**3,dtype=np.int64).reshape((n,n,n))
    corners=np.array([(a,b,c) for a in range(2) for b in range(2) for c in range(2)])
    corner_dist=np.stack([vox[a:n-1+a,b:n-1+b,c:n-1+c] for a,b,c in corners],axis=-1)
    active=(corner_dist.min(-1)<0)&(corner_dist.max(-1)>0)
    cells=ids[:-1,:-1,:-1][active]
    strides=np.array([n*n,n,1])
    triangles=[]
    for i,j,k in permutations(range(3)):
        offsets=np.array([0,strides[i],strides[i]+strides[j],sum(strides)])
        tet=cells[:,None]+offsets
        mask=np.sum((sdf[tet]<0)*np.array([1,2,4,8]),axis=1)
        for case in range(1,15):
            cut=tet[mask==case]
            if not len(cut): continue
            ins=[t for t in range(4) if case&(1<<t)]
            out=[t for t in range(4) if t not in ins]
            pairs=[(a,b) for a in ins for b in out]
            if len(pairs)==4: pairs=[pairs[idx] for idx in (0,1,3,2)]
            tris=[(0,1,2),(0,2,3)] if len(pairs)==4 else [(0,1,2)]
            outward=coords[cut[0,out]].mean(0)-coords[cut[0,ins]].mean(0)
            centers=coords[cut[0][np.array(pairs)]].mean(1)
            reverse=np.dot(np.cross(centers[1]-centers[0],centers[2]-centers[0]),outward)<0
            for tri in tris:
                kp=np.array([pairs[t] for t in (tri[::-1] if reverse else tri)])
                end_indices=np.sort(cut[:,kp],axis=-1)
                triangles.append(end_indices[:,:,0]*(n**3)+end_indices[:,:,1])
    tri=np.concatenate(triangles)
    edgekeys,ff=np.unique(tri.ravel(),return_inverse=True)
    a=edgekeys//(n**3); b=edgekeys%(n**3)
    t=sdf[a]/(sdf[a]-sdf[b])
    verts=coords[a]+t[:,None]*(coords[b]-coords[a])
    verts[:,2]-=.160
    verts/=1.782
    faces=ff.reshape(-1,3).tolist()
    # Collapse coplanar sampling triangles. Preserve the socket rims for close render views.
    original=bpy.data.meshes.new('Casting grid')
    original.from_pydata(verts.tolist(),[],faces)
    temp=bpy.data.objects.new('Casting grid reduction',original)
    bpy.context.collection.objects.link(temp)
    mod=temp.modifiers.new('Foundry pattern reduction','DECIMATE')
    mod.ratio=.27
    evaluated=temp.evaluated_get(bpy.context.evaluated_depsgraph_get())
    reduced=evaluated.to_mesh()
    verts=np.empty(len(reduced.vertices)*3,dtype=np.float32)
    reduced.vertices.foreach_get('co',verts)
    faces=[tuple(p.vertices) for p in reduced.polygons]
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(temp,do_unlink=True)
    bpy.data.meshes.remove(original)
    return verts.reshape(-1,3),faces


def skull(name, center, height, material='brass', augmetic=False):
    material=mat(material)
    meshname='Mortuary foundry | upper cranium | '+material.name
    data=bpy.data.meshes.get(meshname)
    if data is None:
        verts,faces=_skull_surface()
        data=bpy.data.meshes.new(meshname)
        data.from_pydata(verts.tolist(),[],faces)
        data.materials.append(material)
        data.materials.append(mat('dark'))
        data.update()
        for p in data.polygons:
            p.use_smooth=True
            x,y,z=p.center
            # The blind floors of the cavities retain blackened casting patina.
            a=abs(x)*1.782; y*=1.782; z=z*1.782+.158
            socket=((a-.329)/.244)**2+((z-.095-.25*(a-.33))/.195)**2
            if (socket<.86 and y<.02 and y>-.39) or (a<.133 and -.34<z<-.08 and -.46<y<-.29):
                p.material_index=1
    o=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(o)
    o.location=center; o.scale=(height,)*3
    if augmetic:
        x,y,z=center
        r=.067*height
        p=(x+height*.19,y-height*.231,z-height*.034)
        torus(name+' · optic ferrule',p,r,r*.22,(0,-1,0),'copper')
        ball(name+' · red augmetic lens',(p[0],p[1]-.006*height,p[2]),(r*.78,r*.41,r*.78),'red')
    return o


def plate(name, profile, yback, yfront, material, bevel=.008):
    """Extrusion of a frontal profile given counterclockwise in X/Z."""
    k=len(profile)
    verts=[(x,y,z) for y in (yback,yfront) for x,z in profile]
    faces=[tuple(reversed(range(k))),tuple(range(k,2*k))]
    faces.extend((i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k))
    return mesh(name,verts,faces,material,bevel)


def _shield(name,x,y,z,w,h,material):
    profile=[(-.5,.40),(-.38,.5),(.38,.5),(.5,.40),(.48,-.25),(0,-.5),(-.48,-.25)]
    profile=[(x+a*w,z+b*h) for a,b in reversed(profile)]
    return plate(name,profile,y+.032,y-.018,material,.008)


def _round(name,x,y,z,r,thick,material,facets=32):
    return rod(name,(x,y+thick*.5,z),(x,y-thick*.5,z),r,material,facets)


def cog(name,x,y,z,r,back,face):
    teeth=16 if r>.15 else 12
    points=[]
    for i in range(teeth):
        for a,s in ((-.5,.798),(-.33,.823),(-.08,1.02),(.012,1.025),(.17,.848),(.35,.812)):
            t=2*math.pi*(i+a)/teeth
            points.append((x+s*r*math.cos(t),z+s*r*math.sin(t)))
    plate(name+' · cut wheel',points,y+.028,y-.034,back,.005)
    _round(name+' · inset seat',x,y-.040,z,r*.795,.027,'dark')
    torus(name+' · retaining ring',(x,y-.056,z),r*.761,r*.055,(0,-1,0),face)


def _crest(name,x,y,z,r,material='brass',augmetic=False):
    start=part_snapshot()
    cog(name,x,y,z,r,'bronze' if material not in ('steel','gunmetal') else 'steel',material)
    skull(name+' · cast skull',(x,y-.059-r*.14,z+r*.012),r*1.29,material,augmetic)
    preserve_round_parts(start,z)


def _pins(name,xs,y,z,r=.018,material='brass'):
    for i,x in enumerate(xs): _round(name+str(i+1),x,y,z,r,.012,material,6)


def _wings(name,x,y,z,width,material):
    # Five overlapping forged vanes sweep back to the hinge pin. The stamped
    # central fold raises a highlight along each engraved feather.
    for side in (-1,1):
        for i in reversed(range(5)):
            a=i/4
            root=(.105+.018*i,.06-.021*i)
            tip=(.985-.120*i,.22-.058*i)
            mid=((root[0]+tip[0])*.5+.034, .128-.063*i)
            width_v=.048-.002*i
            out=[(root[0]-.016,root[1]+width_v),(mid[0],mid[1]+width_v),
                 tip,(tip[0]-.097,tip[1]-.052),(mid[0]+.025,mid[1]-width_v),
                 (root[0]+.024,root[1]-width_v)]
            # Faceted centre fold and heavier flange at each root.
            poly=[(x+side*u*width,y-.015+i*.0018,z+v*width) for u,v in out]
            ridge=(x+side*(mid[0]+.018)*width,y-.035+i*.0018,z+(mid[1]+.004)*width)
            vs=poly+[ridge]+[(px,y+.009,pz) for px,_,pz in poly]
            fs=[]
            for j in range(6):
                k=(j+1)%6
                fs.extend(((j,k,6),(j,7+j,7+k,k)))
            fs.append(tuple(range(12,6,-1)))
            if side==1:fs=[tuple(reversed(f)) for f in fs]
            mesh(name+' · folded quill '+str(i+1),vs,fs,material,.0015)
        torus(name+' · hinge ring',(x+side*width*.171,y-.04,z+.052*width),.047,.011,(0,-1,0),'bronze')
        ball(name+' · fillet boss',(x+side*width*.171,y-.046,z+.055*width),(.027,.018,.027),material)
        points=[(x+side*.028,z+.005),(x+side*.095,z-.043),
                (x+side*.115,z-.099),(x+side*.061,z-.082),(x+side*.026,z-.041)]
        plate(name+' · pendant petal',points if side<0 else list(reversed(points)),y+.007,y-.028,material,.004)
    _shield(name+' · central drop',x,y-.033,z-.048,.087,.156,material)
    ball(name+' · central boss',(x,y-.057,z+.012),(.045,.021,.045),material)


def _rimbar(name,points,width,depth,metal):
    """Bevelled continuous straps follow a load path around the sloping shell."""
    centers=[Vector(p) for p in points]
    verts=[]
    for i,p in enumerate(centers):
        prior=centers[max(0,i-1)]
        following=centers[min(len(centers)-1,i+1)]
        tangent=(following-prior).normalized()
        cross=Vector((tangent.z,0,-tangent.x)).normalized()
        for side,front in ((-1,-1),(1,-1),(1,1),(-1,1)):
            verts.append(tuple(p+cross*(side*width*.5)+Vector((0,front*depth*.5,0))))
    faces=[(3,2,1,0)]
    for i in range(len(centers)-1):
        for j in range(4):
            a=i*4+j;b=i*4+(j+1)%4;faces.append((a,b,b+4,a+4))
    i=(len(centers)-1)*4;faces.append((i,i+1,i+2,i+3))
    return mesh(name,verts,faces,metal,.010)


def _latch(name,x,y,z,w=.093,material='bronze'):
    box(name+' · stud plate',(x,y,z),(w,.056,w*.87),material,.008)
    _round(name+' · countersink',x,y-.031,z,w*.26,.010,'dark',12)
    _round(name+' · captive stud',x,y-.045,z,w*.208,.028,'brass' if material!='steel' else 'steel',8)



def _lower_hatch(kind,z0=.18,h=.36):
    metal='steel' if kind=='void' else 'bronze'
    y=-.708
    box('Recessed lower service hatch',(0,y,z0+h*.45),(.48,.11,h),'dark',.027)
    box('Inner access plate',(0,y-.062,z0+h*.48),(.318,.032,h*.85),'iron',.018)
    for s in (-1,1):
        box('Door jamb',(s*.212,y-.07,z0+h*.45),(.044,.052,h),metal,.009)
    for z in (z0-.006,z0+h): box('Hatch lintel',(0,y-.072,z),(.465,.058,.039),metal,.008)
    for j in range(4):
        box('Louvred access vent',(0,y-.09,z0+h*(.55+j*.10)),(.212,.022,.018),'steel' if kind=='void' else 'bronze',.004)
    _round('Hatch dog housing',0,y-.098,z0+h*.30,.062,.037,'dark')
    _round('Hatch key spindle',0,y-.115,z0+h*.30,.039,.038,metal,8)
    for s in (-1,1): box('Hinge knuckle',(s*.205,y-.106,z0+h*.13),(.044,.04,.071),'steel',.007)


def _junior():
    # A continuous tapering shrine, with a single green pilot lens above its large seal.
    y=-.709
    frame=[(-.47,.61),(-.47,.91),(-.32,1.30),(-.234,1.57),(.234,1.57),(.32,1.30),(.47,.91),(.47,.61)]
    plate('Junior · tapering reliquary back',list(reversed(frame)),y+.086,y,'iron',.022)
    for s in (-1,1):
        p=[(s*.458,y-.027,.62),(s*.44,y-.027,.87),(s*.315,y-.027,1.24),(s*.232,y-.027,1.55)]
        path('Junior · cast edge bead',p,.026,'bronze')
    for z,w in ((.61,.93),(.995,.66),(1.33,.48),(1.56,.44)):
        box('Junior · fascia band',(0,y-.024,z),(w,.076,.043),'bronze',.007)
    # Cast apron ties the trim under the mast to a rectangular bolted reliquary.
    # Side stiles continue below the red enamel work and land on the front sole.
    for side in (-1,1):
        rail=[(side*.554,-.721,.210),(side*.535,-.735,.528),(side*.477,-.740,.756),
              (side*.383,-.714,1.079),(side*.273,-.637,1.501),(side*.262,-.461,1.605)]
        _rimbar('Junior · deep front load strap',rail,.118,.094,'bronze')
        _rimbar('Junior · worn wear strip',[(x,yy-.052,z) for x,yy,z in rail],.060,.020,'iron')
        for xx,yy,zz in ((.55,-.774,.249),(.530,-.786,.529),(.477,-.798,.756),(.381,-.767,1.08),(.274,-.703,1.493)):
            _latch('Junior · through-bolt',side*xx,yy,zz,.087)
        box('Junior · reliquary door jamb',(side*.289,y-.047,.812),(.049,.073,.445),'bronze',.006)
        for j in range(4):
            box('Junior · shrine side louvers',(side*.355,y-.032,.728+j*.074),(.102,.057,.031),'iron',.005)
        for zz in (.606,1.019):
            _latch('Junior · shrine corner nut',side*.297,y-.079,zz,.079)
        _latch('Junior · upper transom bolt',side*.176,y-.070,1.485,.053)
    for zz,ww in ((.516,.990),(.603,.745),(1.026,.883),(1.452,.472)):
        box('Junior · stepped shrine transom',(0,y-.043,zz),(ww,.107,.043),'bronze',.006)
        box('Junior · worn transom lip',(0,y-.097,zz+.012),(ww*.96,.018,.013),'brass',.002)
    _crest('Junior · consecration seal',0,y-.066,.816,.250,'brass')
    _wings('Junior · small winged drop',0,y-.122,.570,.294,'brass')
    start=part_snapshot()
    _round('Junior · optical well',0,y-.025,1.220,.160,.095,'gunmetal')
    torus('Junior · machined lens bezel',(0,y-.080,1.220),.136,.021,(0,-1,0),'brass')
    torus('Junior · optical gasket',(0,y-.089,1.220),.115,.012,(0,-1,0),'rubber')
    lens=ball('Junior · jade pilot glass',(0,y-.085,1.22),(.109,.055,.109),_lensmat())
    layer=lens.data.uv_layers.new(name='Pilot lens face')
    for loop in lens.data.loops:
        p=lens.data.vertices[loop.vertex_index].co
        layer.data[loop.index].uv=(.5+p.x/.218,.5+p.z/.218)
    preserve_round_parts(start,1.220)
    _pins('Junior · seat fastener',[-.38,.38],y-.054,.63)
    _lower_hatch('junior',.132,.335)


def _pack_bitmap(im,name):
    import os, tempfile
    fd,fn=tempfile.mkstemp(prefix='cogitator-',suffix='.png')
    try:
        with os.fdopen(fd,'wb') as out: im.save(out,'PNG')
        img=bpy.data.images.load(fn,check_existing=False)
        img.name=name
        img.pack()
    finally: os.unlink(fn)
    return img


@lru_cache(None)
def _lensmat():
    from PIL import Image
    m=bpy.data.materials.new('Jade catoptric pilot glass'); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(.061,.184,.019,1)
    p.inputs['Metallic'].default_value=.28; p.inputs['Roughness'].default_value=.20
    p.inputs['Coat Weight'].default_value=.5
    p.inputs['Emission Strength'].default_value=.23
    m.diffuse_color=(.07,.19,.03,1)
    x,y=np.meshgrid(np.linspace(-1,1,128),np.linspace(-1,1,128))
    r=np.sqrt(x*x+y*y)
    # Bullseye pilot glass over a small warm filament, olive at the rolled edge.
    cone=np.clip(1-r**1.2,0,1)**1.4
    fl=np.exp(-((x+.12)**2+(y+.12)**2)*15)
    ring=(np.sin(r*95)*.5+.5)*np.exp(-((r-.77)/.16)**2)*4
    rgb=np.array([13,34,14])+cone[:,:,None]*np.array([36,69,17])+fl[:,:,None]*np.array([136,114,34])+ring[:,:,None]
    img=_pack_bitmap(Image.fromarray(np.uint8(np.clip(rgb,0,255))),'Glass pilot | filament and Fresnel rings')
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
    for key in ('Base Color','Emission Color'):
        m.node_tree.links.new(tex.outputs['Color'],p.inputs[key])
    return m



def _shoulders(kind):
    silver=kind=='void'
    for s in (-1,1):
        x=s*.609; y=-.515
        _shield(kind+' · side reliquary rim',x,y,1.475,.305,.391,'steel' if silver else 'brass')
        _shield(kind+' · enamel ground',x,y-.025,1.478,.25,.321,'gunmetal' if silver else 'bronze')
        start=part_snapshot()
        _round(kind+' · shoulder seat',x,y-.055,1.49,.118,.025,'dark')
        torus(kind+' · side medal rim',(x,y-.066,1.49),.111,.009,(0,-1,0),'steel' if silver else 'brass')
        skull(kind+' · shoulder badge',(x,y-.072,1.487),.19,'steel' if silver else 'brass',silver)
        preserve_round_parts(start,1.49)
        _pins(kind+' · shoulder pin',[x-.107,x+.107],y-.030,1.605,.011)


def _intermediate():
    y=-.711
    _shoulders('intermediate')
    p=[(-.542,.60),(-.52,.92),(-.375,1.20),(-.297,1.55),(.297,1.55),(.375,1.20),(.52,.92),(.542,.60)]
    plate('Fallback · stepped chapel face',list(reversed(p)),y+.07,y,'gunmetal',.022)
    for s in (-1,1):
        pts=[(s*.52,y-.024,.605),(s*.495,y-.024,.89),(s*.377,y-.024,1.155),(s*.277,y-.024,1.48)]
        path('Fallback · raised arch fillet',pts,.035,'bronze')
        path('Fallback · chased bright fillet',[(x-s*.034,yy-.022,z) for x,yy,z in pts],.010,'brass')
        box('Fallback · russet fuse cassette',(s*.397,y-.016,.487),(.215,.057,.26),'rust',.016)
        _pins('Fallback · cassette rivet',[s*.397-.079,s*.397+.079],y-.054,.56,.012,'bronze')
    for z,w in ((.645,1.0),(1.08,.76),(1.345,.59),(1.52,.53)):
        box('Fallback · casting step',(0,y-.024,z),(w,.08,.054),'bronze',.012)
    for i in range(4):
        box('Fallback · transformer fins',(0,y-.048,1.175+i*.042),(.42-i*.032,.060,.023),'steel',.004)
    # The field altar has a stepped, ribbed opening around the disk. Its relief
    # brackets bridge the outer buttresses, and the knee work flanks the hatch below.
    for side in (-1,1):
        path('Fallback · shoulder return',[(side*.474,y-.036,.738),(side*.460,y-.052,.914),(side*.349,y-.052,1.152),(side*.238,y-.061,1.210)],.034,'iron')
        for j in range(4):
            inner=.171+abs(j-1.5)*.025
            outer=.462-j*.030
            box('Fallback · ribbed shrine aperture',(side*(inner+outer)*.5,y-.065,.817+j*.070),
                (outer-inner,.077,.033),'bronze' if j%2 else 'iron',.006)
        box('Fallback · cast cartridge bezel',(side*.441,y-.014,.44),(.233,.092,.293),'bronze',.013)
        box('Fallback · vermilion enamel',(side*.441,y-.072,.448),(.174,.032,.216),'oxide',.010)
        for zz in (.37,.525): _pins('Fallback · panel keeper',[side*.441-.059,side*.441+.059],y-.092,zz,.010,'bronze')
        _rimbar('Fallback · cheek brace',[(side*.574,y+.008,.24),(side*.508,y-.050,.335),(side*.333,y-.051,.371)],.073,.066,'bronze')
        _latch('Fallback · lower jack pin',side*.466,y-.096,.341,.075)
        for i in range(3):
            rad=i*.024
            pts=[(side*(.262+rad),y-.028,.320),(side*(.262+rad),y-.028,.429+rad),
                 (side*(.306+rad),y-.028,.465+rad),(side*(.306+rad),y-.028,.614)]
            path('Fallback · nested access duct',pts,.014,'bronze' if i!=1 else 'gunmetal')
        _latch('Fallback · apex fastener',side*.33,y-.072,1.09,.078)
        _latch('Fallback · gilt corner casting',side*.452,y-.085,.756,.101)
        # Stepped plinths on either side of the drop pin leave an open scallop.
        profile=[(side*.455,.722),(side*.462,.676),(side*.401,.622),
                 (side*.316,.620),(side*.328,.651),(side*.369,.674),(side*.390,.719)]
        plate('Fallback · scalloped support',profile if side<0 else list(reversed(profile)),y+.016,y-.074,'bronze',.007)
    _crest('Fallback · large cog and skull',0,y-.080,.949,.239,'gold')
    _wings('Fallback · aquila casting',0,y-.116,.685,.370,'gold')
    _lower_hatch('intermediate',.155,.287)


def _void_pod(name,x,y,z,large=False):
    # A sectioned pipe end forms the skull's P-trap inspection cover. The two
    # annular steel clamping bands are part of this casting, proud of the pipe.
    start=part_snapshot()
    r=.169 if large else .138
    side=-1 if x<0 else 1
    _round(name+' · pipe-end casting',x,y+.043,z,r,.194,'gunmetal')
    _round(name+' · inner retaining band',x,y-.026,z,r*1.115,.033,'steel')
    _round(name+' · black gasket',x,y-.044,z,r*1.037,.022,'dark')
    _round(name+' · polished cover',x,y-.059,z,r*1.045,.031,'steel')
    _round(name+' · vignette',x,y-.078,z,r*.833,.022,'dark')
    torus(name+' · burnished flange',(x,y-.092,z),r*.855,r*.075,(0,-1,0),'bronze')
    skull(name+' · cast optic skull',(x,y-.103,z-.010),r*1.38,'steel',True)
    for sign in (-1,1):
        ax=x+sign*r*.84
        _round(name+' · lock rivet',ax,y-.080,z-.066,.013,.024,'brass',8)
    # Riveted clevis immediately below the ring follows the cheek slope.
    box(name+' · keeper tongue',(x,y-.023,z-r*1.11),(.089,.099,.090),'steel',.013)
    _round(name+' · keeper pin',x,y-.083,z-r*1.11,.018,.022,'bronze',8)
    preserve_round_parts(start,z)
    if not large:
        path(name+' · feed elbow',[(x,y+.022,z+.040),(x-side*.026,y+.090,z+.132),
             (x-side*.070,y+.164,z+.215),(x-side*.104,y+.232,z+.278)],.070,'gunmetal')


def _void_bonnet(y):
    # The arched inspection casting is a single sloping shell. Its hollow crown
    # houses the upper return sight glass. Model the aperture through the shell
    # so oblique views see the bevels and the back of the pocket.
    rows = [
        (.75, .535, y - .005), (.92, .506, y - .014),
        (1.08, .425, y - .022), (1.24, .310, y - .017),
        (1.34, .268, y - .005), (1.405, .266, y + .003),
        (1.510, .245, y + .021), (1.560, .226, y + .040),
        (1.595, .209, y + .073),
    ]
    # Separate face strips share all of their seam vertices. Only the back wall
    # of the sight-glass well crosses the opening.
    verts = []
    for z, half, face in rows:
        for x in (-half, -.142, .142, half):
            verts.append((x, face + (.015 if abs(x) == half else 0), z))
    faces = []
    for level in range(len(rows) - 1):
        for column in range(3):
            if level == 5 and column == 1:
                continue
            a = 4 * level + column
            faces.append((a, a + 1, a + 5, a + 4))
    edge = [0, 1, 2, 3] + [4 * j + 3 for j in range(1, len(rows))]
    edge += [4 * (len(rows) - 1) + k for k in (2, 1, 0)]
    edge += [4 * j for j in range(len(rows) - 2, 0, -1)]
    rear = len(verts)
    for i in edge:
        x, _, z = verts[i]
        verts.append((x, -.530, z))
    faces.append(tuple(reversed(range(rear, rear + len(edge)))))
    for j, a in enumerate(edge):
        k = (j + 1) % len(edge)
        faces.append((a, rear + j, rear + k, edge[k]))
    opening = [21, 22, 26, 25]
    well = len(verts)
    for i in opening:
        x, yy, z = verts[i]
        verts.append((x, yy + .047, z))
    for j, a in enumerate(opening):
        k = (j + 1) % 4
        faces.append((a, opening[k], well + k, well + j))
    faces.append(tuple(range(well, well + 4)))
    mesh('Void · hollow cast inspection bonnet', verts, faces, 'gunmetal', .009)

    # A closed crown joins the two arch legs over the cog wheel. Narrow flutes
    # track the thicker casting and stop in the same bolted spring sockets.
    half_arch = [(.513, -.776, .775), (.509, -.779, .901),
                 (.466, -.786, 1.008), (.332, -.789, 1.162),
                 (.226, -.778, 1.248), (.177, -.775, 1.261)]
    trace = [(-x, yy, z) for x, yy, z in half_arch]
    trace += list(reversed(half_arch))
    _rimbar('Void · continuous barrel arch', trace, .075, .086, 'gunmetal')
    path('Void · burnished arch crown', [(x, yy - .046, z + .011)
         for x, yy, z in trace], .017, 'steel')
    for side in (-1, 1):
        _latch('Void · arch spring clasp', side * .510, -.801, .789, .108, 'steel')
        # The raked brow runs into both shoulder inspection chambers.
        _rimbar('Void · inspection brow cheek', [
            (side * .474, -.710, 1.249), (side * .355, -.735, 1.294),
            (side * .278, -.737, 1.365), (side * .210, -.734, 1.372)],
            .040, .048, 'steel')
    rod('Void · upper return glass', (0, y + .075, 1.413),
        (0, y + .087, 1.502), .071, 'green', 32)
    for zz, yy in ((1.413, .075), (1.499, .087)):
        rod('Void · return glass ferrule', (0, y + yy, zz - .009),
            (0, y + yy, zz + .009), .081, 'bronze', 24)
    for zz, yy in ((1.400, y - .015), (1.521, y + .007)):
        _rimbar('Void · recessed slot reveal',
                [(-.188, yy + .005, zz - .007), (-.143, yy, zz),
                 (.143, yy, zz), (.188, yy + .005, zz - .007)],
                .020, .023, 'steel')


def _void():
    y=-.718
    # Their upper sockets seat in the same sealed shoulders as other editions.
    for side in (-1,1):
        _void_pod('Void · upper inspection skull',side*.608,-.556,1.487,True)
        _void_pod('Void · lower inspection skull',side*.798,-.667,.931)
    _void_bonnet(y)
    # The badge beam and its bearing nuts occupy the lower transom only.
    _rimbar('Void · badge beam', [(-.535,y-.030,.750),(-.438,y-.052,.743),
            (.438,y-.052,.743),(.535,y-.030,.750)], .065,.085,'gunmetal')
    for s in (-1,1):
        _latch('Void · beam saddle',s*.304,y-.089,.783,.108,'steel')
    _crest('Void · mortuary seal',0,y-.076,1.00,.243,'brass',True)
    for s in (-1,1):
        box('Void · viewing port side',(s*.206,y-.041,.61),(.052,.086,.18),'steel',.009)
    box('Void · dark viewport',(0,y-.05,.61),(.354,.055,.150),'dark',.012)
    # Green fluid sight glass with actual end caps, gland nuts and protecting ribs.
    yy=y-.098
    rod('Void · sight glass',(0,yy,.532),(0,yy,.697),.074,'green',32)
    for zz in (.525,.696):
        rod('Void · sight-glass gland',(0,yy,zz-.016),(0,yy,zz+.019),.087,'steel',16)
    for side in (-1,1):
        rod('Void · viewport stay',(side*.097,yy-.007,.530),(side*.097,yy-.007,.699),.011,'bronze',10)
        box('Void · field port lintel',(side*.298,y-.036,.692),(.101,.099,.072),'gunmetal',.009)
        _latch('Void · field port pin',side*.302,y-.095,.702,.057,'steel')
        pts=[(side*.245,.485),(side*.302,.495),(side*.373,.565),(side*.437,.565),
             (side*.437,.524),(side*.375,.519),(side*.318,.455),(side*.245,.45)]
        plate('Void · side access sill',pts if side<0 else list(reversed(pts)),y+.015,y-.085,'gunmetal',.009)
    _lower_hatch('void',.133,.32)


@lru_cache(None)
def _display(variant):
    """Paint bespoke phosphor plates, then pack each generated PNG into the blend."""
    from PIL import Image, ImageDraw, ImageFont
    width,height=(384,200) if variant=='mortis' else (290,204)
    rng=np.random.default_rng({'mortis':37,'auspex':112,'telemetry':213}[variant])
    x,y=np.meshgrid(np.arange(width),np.arange(height))
    vignette=(1-.30*((x/(width*.5)-1)**2+(y/(height*.5)-1)**2))
    grain=rng.normal(0,2.2,(height,width))+(np.sin(y*.103)+np.cos(x*.036))*1.3
    arr=np.clip((vignette[:,:,None]*np.array([27,55,21])+grain[:,:,None]),0,255).astype(np.uint8)
    im=Image.fromarray(arr)
    d=ImageDraw.Draw(im)
    dim=(56,88,37); mid=(90,136,61); lime=(136,191,78); pale=(178,210,132)
    def label(p,t,size=11,color=mid):
        try: f=ImageFont.load_default(size=size)
        except TypeError: f=ImageFont.load_default()
        d.text(p,t,font=f,fill=color)
    d.rectangle((5,5,width-6,height-6),outline=dim)
    d.line((9,25,width-10,25),fill=mid)
    d.line((9,height-24,width-10,height-24),fill=mid)
    for j in range(0,width,9): d.line((j,height-17,j,height-14-(j%3)),fill=dim)
    title={'mortis':'MORTIS  /  COGITATOR INTERFACE','auspex':'AUSPEX   SEC / IV','telemetry':'MANIFOLD  /  PRESSURE'}[variant]
    label((12,6),title,14,lime)
    if variant=='mortis':
        def drawcol(x0,x1):
            for j in range(11):
                yy=38+j*12
                d.line((x0,yy,x1,yy),fill=dim)
                for k in range(int(rng.integers(3,9))):
                    x=x0+int(rng.integers(2,max(3,x1-x0-8)))
                    d.line((x,yy+4,min(x1-2,x+int(rng.integers(2,10))),yy+4),fill=mid)
        drawcol(13,76); drawcol(290,368)
        for y0 in range(34,171,12): d.line((86,y0,279,y0),fill=(45,77,31))
        for x0 in range(86,280,12): d.line((x0,32,x0,172),fill=(43,71,31))
        cx,cy=178,97
        def loop(poly,c=lime,w=2,filled=None):
            p=[(cx+px,cy+py) for px,py in poly]
            if filled: d.polygon(p,fill=filled)
            d.line(p+[p[0]],fill=c,width=w,joint='curve')
        loop([(-38,-20),(-34,-38),(-21,-50),(-4,-55),(15,-53),(31,-44),(38,-30),(40,-12),(34,2),(29,7),(31,17),(22,22),(15,20),(11,35),(4,42),(-13,40),(-19,30),(-22,23),(-32,20),(-36,15),(-32,6),(-38,-6)],pale,2,(85,123,51))
        loop([(-26,-12),(-18,-14),(-6,-8),(-7,1),(-12,7),(-22,8),(-29,1)],mid,2,(20,42,18))
        loop([(4,-6),(20,-15),(30,-11),(29,-1),(20,8),(10,6)],mid,2,(20,42,18))
        loop([(-1,4),(-8,19),(-2,17),(2,19),(6,17)],lime,1,(28,46,22))
        for i in range(6): d.line((cx-13+i*5,cy+25,cx-13+i*5,cy+34+int(3*math.cos(i))),fill=(39,62,24),width=2)
        for s in (-1,1):
            bx=cx+s*52
            d.line((bx,cy-33,bx,cy-45,bx-s*10,cy-45),fill=lime,width=2)
            d.line((bx,cy+25,bx,cy+37,bx-s*10,cy+37),fill=lime,width=2)
        d.line((221,82,237,63,277,63),fill=lime)
        d.line((141,110,124,129,89,129),fill=mid)
        label((230,50),'VITA / 08',9,pale)
        label((103,153),'SIGILLUM  0X-07',10,lime)
    elif variant=='auspex':
        cx,cy=107,102
        for yy in range(34,177,15): d.line((20,yy,183,yy),fill=(42,74,33))
        for xx in range(24,182,15): d.line((xx,33,xx,176),fill=(42,74,33))
        for rr in (15,32,51,68): d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),outline=mid,width=1 if rr<65 else 2)
        for i in range(24):
            a=i*math.pi/12
            d.line((cx+math.cos(a)*62,cy+math.sin(a)*62,cx+math.cos(a)*68,cy+math.sin(a)*68),fill=lime)
        d.line((cx-75,cy,cx+75,cy),fill=mid)
        d.line((cx,cy-72,cx,cy+72),fill=mid)
        for off in range(20):
            a=-.65-off*.017
            d.line((cx,cy,cx+math.cos(a)*64,cy+math.sin(a)*64),fill=(75-off,121-off*2,55-off))
        for xx,yy in ((117,92),(93,137),(76,111),(143,70)):
            d.rectangle((xx-2,yy-2,xx+2,yy+2),fill=pale)
        for j in range(8):
            yy=42+j*16
            label((194,yy-3),f'{j:02X}   {21+j*7:02X}',10,mid)
            d.line((196,yy+7,267,yy+7),fill=dim)
            d.line((197,yy+7,198+int(rng.integers(9,62)),yy+7),fill=lime,width=2)
    else:
        for yy in range(37,120,12): d.line((14,yy,275,yy),fill=(43,71,31))
        for xx in range(18,275,13): d.line((xx,34,xx,120),fill=(43,71,31))
        for j in range(7):
            px=52+j*27
            d.ellipse((px-9,63,px+10,95),outline=lime)
            d.line((px-2,63,px+6,57,px+15,57,px+18,64),fill=mid)
        d.rectangle((40,71,247,88),outline=lime,width=2)
        d.line((27,79,254,79),fill=mid)
        for xx in (54,101,172,224):
            d.line((xx,93,xx-5,105,xx-17,105),fill=pale)
        for i in range(3):
            yy=131+i*15
            pts=[(13+k,yy+int(3*math.sin(k*.13+i)+3*math.sin(k*.31+i))) for k in range(141)]
            d.line(pts,fill=lime)
            label((169,yy-5),('FLOW / A1','AMP / B7','COIL / A3')[i],10,mid)
        label((31,34),'TURBINE     /   II - 01',10,lime)
    # Persistent raster scan and slight phosphor falloff at tube edges.
    out=np.asarray(im).astype(float)
    out[::3,:,:]*=.82
    out*=np.clip(vignette, .53, 1)[:,:,None]**.5
    img=_pack_bitmap(Image.fromarray(np.uint8(np.clip(out,0,255))),'Vitreous phosphor | '+variant)
    m=bpy.data.materials.new('Phosphor tube | '+variant); m.use_nodes=True
    m.diffuse_color=(.13,.29,.06,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value=.33;p.inputs['Metallic'].default_value=.06
    p.inputs['Coat Weight'].default_value=.16
    p.inputs['Emission Strength'].default_value=.70
    tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
    return m


def _transform_new(before, origin, yaw=0, tilt=0):
    from mathutils import Matrix
    t=Matrix.Translation(origin)@Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(tilt,4,'X')
    for o in set(bpy.context.collection.objects)-before:
        o.matrix_world=t@o.matrix_basis


def _screen(name,center,w,h,variant,yaw=0):
    before=set(bpy.context.collection.objects)
    metal='bronze' if variant!='telemetry' else 'gunmetal'
    box(name+' · die-cast rear case',(0,.065,0),(w,.173,h),metal,.039)
    box(name+' · bezel gasket',(0,-.015,0),(w-.050,.065,h-.044),'dark',.025)
    # Separate brass corner hardware and bronze crossrails leave a rounded aperture.
    for s in (-1,1):
        box(name+' · edge rail',(s*(w*.5-.026),-.035,0),(.045,.071,h-.038),'brass',.010)
        box(name+' · bezel lip',(0,-.041,s*(h*.5-.023)),(w-.06,.066,.040),'bronze',.009)
        for t in (-1,1):
            box(name+' · corner guard',(s*(w*.5-.035),-.056,t*(h*.5-.039)),(.062,.062,.075),'brass',.011)
            _round(name+' · corner screw',s*(w*.5-.036),-.091,t*(h*.5-.037),.011,.012,'dark',8)
    # Small convex CRT with its own UVs. The relief catches highlights across the glass.
    aw=w-.139; ah=h-.125
    cols,rows=16,10; verts=[]; faces=[]; uv=[]
    for j in range(rows+1):
        v=j/rows
        for i in range(cols+1):
            u=i/cols
            sy=(1-(2*u-1)**2)*(1-(2*v-1)**2)
            verts.append(((u-.5)*aw,-.060-.020*sy,(v-.5)*ah)); uv.append((u,v))
    for j in range(rows):
        for i in range(cols):
            q=j*(cols+1)+i;faces.append((q,q+1,q+cols+2,q+cols+1))
    g=mesh(name+' · bowed phosphor glass',verts,faces,_display(variant))
    layer=g.data.uv_layers.new(name='Phosphor face')
    for p in g.data.polygons:
        p.use_smooth=True
        for li in p.loop_indices: layer.data[li].uv=uv[g.data.loops[li].vertex_index]
    _transform_new(before,center,yaw)


def _keyboard(name,z):
    # A hinged tray with chamfered profile and four staggered rows of keycaps.
    y=-.881
    before=set(bpy.context.collection.objects)
    box(name+' · iron tray',(0,0,0),(.954,.333,.090),'iron',.025)
    box(name+' · bronze surround',(0,-.005,.036),(.899,.297,.045),'bronze',.018)
    box(name+' · black keybed',(0,.002,.057),(.797,.243,.022),'dark',.011)
    box(name+' · grab lip',(0,-.162,-.002),(.831,.040,.044),'brass',.009)
    def cap(verts,faces,cx,cy,sx,sy,zlow=.070,ztop=.084):
        i=len(verts)
        for k,zz in ((1,zlow),(.83,ztop)):
            for dx,dy in ((-1,-1),(1,-1),(1,1),(-1,1)):
                verts.append((cx+dx*sx*k*.5,cy+dy*sy*k*.5,zz))
        faces.extend(tuple(i+a for a in f) for f in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)))
    groups=[([],[]) for _ in range(3)]
    for row in range(4):
        for col in range(15):
            if row==0 and col in (4,5,6,7,8,9):
                if col!=6:continue
                width=.246; cx=-.034
            else:
                width=.042; cx=-.346+col*.048+(.007 if row in (1,3) else 0)
            matidx=1 if col>=13 else (2 if col==0 and row==3 else 0)
            cap(*groups[matidx],cx,-.076+row*.050,width,.039)
    for label,group,m in zip(('ivory brass keycaps','steel function keys','vermilion stop key'),groups,('brass','steel','red')):
        mesh(name+' · '+label,*group,m)
    for s in (-1,1):
        for t in (-1,1): rod(name+' · tray bolt',(s*.430,t*.114,.05),(s*.430,t*.114,.068),.012,'steel',8)
    _transform_new(before,(0,y,z),tilt=math.radians(16))
    for s in (-1,1):
        path(name+' · tray support',[(s*.387,-.694,z-.16),(s*.387,-.818,z-.110),(s*.387,-.964,z-.037)],.024,'bronze')


def _cogitator(kind):
    _shoulders(kind)
    y=-.711
    profile=[(-.50,.40),(-.50,.89),(-.405,1.108),(-.235,1.48),(.235,1.48),(.405,1.108),(.50,.89),(.50,.40)]
    plate(kind+' · console mounting apron',list(reversed(profile)),y+.08,y,'iron',.022)
    for s in (-1,1):
        pts=[(s*.484,y-.031,.62),(s*.469,y-.031,.86),(s*.385,y-.031,1.095),(s*.226,y-.031,1.472)]
        path(kind+' · cast arch moulding',pts,.031,'bronze')
    for z,w in ((.91,.88),(1.20,.62),(1.37,.46),(1.47,.44)):
        box(kind+' · transom casting',(0,y-.022,z),(w,.071,.039),'bronze',.008)
    for i in range(3):
        box(kind+' · upper transom vents',(0,y-.049,1.28+i*.042),(.393-i*.045,.055,.021),'steel',.005)
    _crest(kind+' · cogitator seal',0,y-.066,1.115,.223,'brass')
    _screen(kind+' · command monitor',(0,-.780,.711),.884,.403,'mortis')
    _keyboard(kind+' · operator keys',.455)
    _lower_hatch(kind,.125,.237)
    if kind=='planetary':
        for s,variant in ((-1,'auspex'),(1,'telemetry')):
            x=s*1.068
            path('Planetary · yoke arm',[(s*.70,-.166,.924),(s*.85,-.166,.924),(s*1.022,-.136,1.069),(x,-.192,1.103)],.052,'gunmetal')
            rod('Planetary · hinge axle',(x,-.196,1.07),(x,-.080,1.07),.086,'bronze')
            path('Planetary · display umbilical',[(s*.70,-.074,.78),(s*.864,-.074,.735),(s*.978,-.083,.748),(s*1.109,-.115,.88),(s*1.109,-.150,1.005)],.028,'rubber')
            _screen('Planetary · '+variant+' wing',(x,-.219,1.123),.683,.491,variant,s*math.radians(-13))


def build_fascia(kind):
    if kind=='junior': _junior()
    elif kind=='intermediate': _intermediate()
    elif kind=='void': _void()
    elif kind in ('senior','planetary'): _cogitator(kind)
    else: raise ValueError('Unknown station '+repr(kind))
