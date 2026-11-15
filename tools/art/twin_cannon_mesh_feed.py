"""Owner-reference feed: closed woven-wire chute, curved into a rear side port.

All coordinates use the reviewed cap studio. The gun-loading mechanisms
remain armoured; the visible rounds travel inside the enclosed mesh cover.
"""
import bpy,math,bisect
from mathutils import Vector,Matrix

def build_mesh_feeds(api):
    box,cylinder,tube,profile,cut,empty,parent,finish=[api[n] for n in
        ('box','cylinder','tube','profile_body','cut_port','empty','parent_world','finish')]
    root=api['root'];created=api['created'];mats=api['mats'];conduit=api['conduit']
    wire=api['flat']('woven galvanised feed mesh',(.22,.24,.25),.82,.44)
    width,height=.78,.26;perimeter=2*(width+height)
    groups=[];motion=[];review=[];root_inverse=root.matrix_world.inverted().copy()
    # A common foundation carries two enclosed, forward-loading receivers.
    profile('Rear enclosed-loader support bridge',0,2.04,
        [(.55,2.36),(1.48,2.36),(1.56,2.49),(1.42,2.64),(.62,2.64)],'dark')
    box('Armoured central feed controller',(0,1.23,2.81),(.38,.48,.48),'red',bevel=.025)

    def bezier(p,a,b,q,t):
        return (1-t)**3*p+3*(1-t)**2*t*a+3*(1-t)*t*t*b+t**3*q
    def path_for(side):
        p=Vector((side*.83,1.18,1.91));mid=Vector((side*1.46,1.16,2.43));q=Vector((side*.90,1.10,2.86))
        first=[bezier(p,Vector((side*1.22,1.24,1.98)),Vector((side*1.48,1.20,2.19)),mid,j/40) for j in range(41)]
        points=first+[bezier(mid,Vector((side*1.44,1.11,2.69)),Vector((side*1.20,1.10,2.86)),q,j/40) for j in range(1,41)]
        lengths=[0.0]
        for a,b in zip(points,points[1:]):lengths.append(lengths[-1]+(b-a).length)
        def sample(distance):
            if distance<=0:
                tangent=(points[1]-points[0]).normalized();centre=points[0]+tangent*distance
            elif distance>=lengths[-1]:
                tangent=(points[-1]-points[-2]).normalized();centre=points[-1]+tangent*(distance-lengths[-1])
            else:
                i=min(len(points)-2,bisect.bisect_right(lengths,distance)-1)
                f=(distance-lengths[i])/(lengths[i+1]-lengths[i]);centre=points[i].lerp(points[i+1],f)
                j=max(0,i-1);k=min(len(points)-1,i+2);tangent=(points[k]-points[j]).normalized()
            forward=Vector((0,-1,0));w=(forward-tangent*forward.dot(tangent)).normalized();h=tangent.cross(w).normalized()
            return centre,tangent,w,h
        return sample,lengths[-1]

    def polyline_object(name,splines,radius,material):
        data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=0;data.use_fill_caps=True
        for points in splines:
            spline=data.splines.new('POLY');spline.points.add(len(points)-1)
            for v,p in zip(spline.points,points):v.co=(*p,1)
        obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj);data.materials.append(material)
        parent(obj,root);created.append(obj);return obj

    def ring(name,sample,s,w,h,depth,wall):
        c,t,u,v=sample(s);vertices=[];faces=[]
        for z,a,b in ((-depth/2,w,h),(depth/2,w,h),(depth/2,w-2*wall,h-2*wall),(-depth/2,w-2*wall,h-2*wall)):
            for x,y in ((-a/2,-b/2),(a/2,-b/2),(a/2,b/2),(-a/2,b/2)):vertices.append(c+t*z+u*x+v*y)
        for r,n in ((0,1),(1,2),(2,3),(3,0)):
            for j in range(4):faces.append((r*4+j,r*4+(j+1)%4,n*4+(j+1)%4,n*4+j))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);return finish(obj,name,'red',bevel=.003)

    def point_on_perimeter(p):
        p%=perimeter
        if p<width:return -width/2+p,height/2
        p-=width
        if p<height:return width/2,height/2-p
        p-=height
        if p<width:return width/2-p,-height/2
        return -width/2,-height/2+(p-width)

    for bank,side in enumerate((-1,1)):
        first=len(created);sample,length=path_for(side)
        # Enclosed per-barrel loader; a real side opening receives the chute.
        receiver=profile('Enclosed barrel feeder '+str(bank),side*.58,.66,
            [(.58,2.62),(1.50,2.62),(1.60,2.82),(1.48,3.10),(.84,3.10),(.60,2.94)],'dark')
        cut(receiver,(side*.91,1.10,2.86),(.26,.75,.29))
        for y in (.99,1.32):
            box('Loader removable red service panel '+str(bank),(side*.58,y,3.105),(.43,.29,.030),'red',bevel=.006)
            for dx in (-.16,.16):cylinder('Feeder service panel lock',(side*.58+dx,y,3.119),(side*.58+dx,y,3.14),.020,'steel',vertices=6)
        c,t,w,h=sample(0)
        boot=box('Angled base feedthrough housing '+str(bank),(side*.67,1.15,1.90),(.65,.90,.40),'dark',bevel=.025)
        # Carve the boot along the actual entry axis rather than intersecting
        # a solid box with a decorative hose.
        bpy.ops.mesh.primitive_cube_add(size=1,location=c-t*.12);cutter=bpy.context.object
        cutter.dimensions=(width-.02,height-.01,.55);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        cutter.rotation_euler=Matrix((w,h,t)).transposed().to_euler()
        modifier=boot.modifiers.new('Angled ammunition passage','BOOLEAN');modifier.operation='DIFFERENCE';modifier.object=cutter
        bpy.context.view_layer.objects.active=boot;bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
        ring('Bolted lower feed collar '+str(bank),sample,0,.88,.36,.16,.045)
        ring('Bolted side-entry feed collar '+str(bank),sample,length,.88,.36,.16,.045)
        for end in (0,length):
            c,t,w,h=sample(end)
            for u,v in ((-.405,-.145),(.405,-.145),(.405,.145),(-.405,.145)):
                cylinder('Feed collar retaining bolt',c+w*u+h*v-t*.085,c+w*u+h*v-t*.115,.021,'steel',vertices=6)
        for u,v in ((-width/2,-height/2),(width/2,-height/2),(width/2,height/2),(-width/2,height/2)):
            points=[]
            for j in range(81):
                c,t,w,h=sample(length*j/80);points.append(c+w*u+h*v)
            polyline_object('Continuous reinforced chute corner '+str(bank),[points],.022,mats['red'])
        ribs=[]
        for j in range(1,int(length/.18)):
            c,t,w,h=sample(length*j/int(length/.18))
            ribs.append([c+w*u+h*v for u,v in ((-width/2,-height/2),(width/2,-height/2),(width/2,height/2),(-width/2,height/2),(-width/2,-height/2))])
        polyline_object('Articulated rectangular feed ribs '+str(bank),ribs,.012,mats['dark'])
        strands=[];count=math.ceil(perimeter/.09)
        for direction in (-1,1):
            for i in range(count):
                points=[]
                for j in range(73):
                    s=length*j/72;c,t,w,h=sample(s);u,v=point_on_perimeter(i*perimeter/count+direction*s)
                    points.append(c+w*u+h*v)
                strands.append(points)
        polyline_object('Complete woven diamond-wire enclosure '+str(bank),strands,.0065,wire)

        # Rounds are transverse to the moving belt and point forward at the
        # level side-entry port. Their turn and loading happen inside armour.
        hidden=.24;full_length=length+2*hidden;number=max(4,int(full_length/.21));pitch=full_length/number
        for i in range(number):
            start=len(created)
            # Mirror the carrier backing so it remains on the INSIDE of
            # both bends. The outer mesh face exposes the actual cartridges.
            z=side*.01
            box('Linked enclosed carrier shoe',(0,0,-side*.10),(.70,.07,.045),'dark',bevel=.008)
            cylinder('Enclosed brass cannon cartridge',(-.29,0,z),(.13,0,z),.073,'brass')
            cylinder('Cartridge base flange',(-.315,0,z),(-.29,0,z),.085,'steel')
            bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.073,radius2=.012,depth=.18,location=(.22,0,z))
            tip=bpy.context.object;tip.rotation_euler.y=math.pi/2;finish(tip,'Forward-pointing penetrator nose','steel')
            for x in (-.15,.08):tube('Carrier shell retaining strap',(x-.018,0,z),(x+.018,0,z),.088,.013,'dark')
            group=empty('ENCLOSED_FEED_ROUND_'+str(bank)+'_'+str(i),(0,0,0));group.rotation_mode='QUATERNION'
            for obj in created[start:]:
                mw=obj.matrix_world.copy();obj.parent=group;obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=mw
            groups.append(group);motion.append((group,bank,i,pitch,full_length,hidden,sample))
        if bank==0:review.extend(created[first:])

    def update(frame,keyframe=True,shot_schedule=None):
        for group,bank,i,pitch,full_length,hidden,sample in motion:
            if shot_schedule is None:
                phase=(frame-bank*45)%90
                f=max(0,min(1,(phase-10)/18));f=f*f*(3-2*f)
                progress=math.floor((frame-bank*45)/90)+f
            else:
                progress=0.0
                for shot in shot_schedule[bank]:
                    f=max(0,min(1,(frame-shot-10)/18));progress+=f*f*(3-2*f)
            distance=((i+progress)*pitch)%full_length-hidden
            c,t,w,h=sample(distance)
            matrix=Matrix((w,-t,h)).transposed().to_4x4();matrix.translation=c
            group.matrix_basis=root_inverse@matrix
            if keyframe:group.keyframe_insert('location');group.keyframe_insert('rotation_quaternion')
    update(0,False)
    return groups,update,review
