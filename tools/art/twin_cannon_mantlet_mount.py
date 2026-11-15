"""Continuous fixed casemates with real clearance for moving mantlets."""
import bpy,math
from mathutils import Vector

def integrate_mantlet(api,hull,cover,x,bank):
    created=api['created'];mats=api['mats'];finish=api['finish']
    # The forward circular seat grows into broad cast shoulders, then flows
    # into the breech roof. This is a solid loft, not a washer hung off a box.
    rings=[(-.77,.98,.98,2.61,1.0),(-.62,1.00,1.00,2.61,.72),
           (-.28,.94,.98,2.61,.50),(.12,.88,.82,2.64,.55),(.43,.82,.56,2.70,.65)]
    n=48;vertices=[];faces=[]
    for y,w,h,z,power in rings:
        for j in range(n):
            a=j*math.tau/n;c=math.cos(a);s=math.sin(a)
            vertices.append((x+math.copysign(abs(c)**power,c)*w/2,y,z+math.copysign(abs(s)**power,s)*h/2))
    faces.append(tuple(reversed(range(n))))
    for r in range(len(rings)-1):
        for j in range(n):faces.append((r*n+j,r*n+(j+1)%n,(r+1)*n+(j+1)%n,(r+1)*n+j))
    faces.append(tuple((len(rings)-1)*n+j for j in range(n)))
    data=bpy.data.meshes.new('Continuous mantlet casemate loft');data.from_pydata(vertices,[],faces);data.update()
    shoulder=bpy.data.objects.new('Integrated mantlet shoulder '+str(bank),data);bpy.context.scene.collection.objects.link(shoulder)
    finish(shoulder,shoulder.name,'red',bevel=.008)

    def apply_modifiers(obj):
        bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    def align_materials(obj,red=False):
        obj.data.materials.clear();obj.data.materials.append(mats['dark']);obj.data.materials.append(mats['red'])
        if red:
            for polygon in obj.data.polygons:polygon.material_index=1
    if len(hull.data.materials)==1:align_materials(hull)
    align_materials(shoulder,True);align_materials(cover,True)
    apply_modifiers(hull)
    for operand in (shoulder,cover):
        apply_modifiers(operand)
        bpy.context.view_layer.objects.active=hull
        modifier=hull.modifiers.new('Welded casemate structural union','BOOLEAN');modifier.operation='UNION';modifier.solver='EXACT';modifier.object=operand
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        created.remove(operand);bpy.data.objects.remove(operand,do_unlink=True)

    # Bore the socket in the complete shared casting, so the hull itself
    # cannot obstruct the moving seat. The rear ends in an enclosed chamber.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.422,depth=1.14,location=(x,-.53,2.61))
    cutter=bpy.context.object;cutter.rotation_euler.x=math.pi/2
    bpy.context.view_layer.objects.active=hull
    modifier=hull.modifiers.new('Recessed mantlet clearance chamber','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
    # A narrower blind tunnel admits the long barrel recoil stroke without
    # cutting through the sloped roof of the rear casemate.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.238,depth=.70,location=(x,.15,2.61))
    cutter=bpy.context.object;cutter.rotation_euler.x=math.pi/2
    bpy.context.view_layer.objects.active=hull
    modifier=hull.modifiers.new('Deep barrel recoil tunnel','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name);bpy.data.objects.remove(cutter,do_unlink=True)
    api['uv'](hull)
    hull.name='Unified turret casting with integrated mantlet sockets'
    api['tube']('Fixed socket journal '+str(bank),(x,-.785,2.61),(x,-.755,2.61),.445,.023,'steel')
    for side in (-1,1):
        api['cylinder']('Seated elevation trunnion '+str(bank),(x+side*.37,-.63,2.61),(x+side*.49,-.63,2.61),.065,'steel')
        api['tube']('Fixed trunnion bearing boss '+str(bank),(x+side*.475,-.63,2.61),(x+side*.515,-.63,2.61),.095,.025,'dark')
    return hull
