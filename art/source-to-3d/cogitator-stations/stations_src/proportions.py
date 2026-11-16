"""Station-specific cast-body, mast and crown heights in shared Blender units."""
import numpy as np
LEVELS=[-.02,0,.19,.81,1.22,1.67,2.70,3.52]
PROFILES={
    'junior':       (.965,[-.02,0,.22,1.13,1.625,2.075,2.87,3.56]),
    'intermediate': (.985,[-.02,0,.20,1.05,1.59,2.040,2.67,3.22]),
    'senior':       (.985,[-.02,0,.21,.96,1.455,2.06,2.88,3.54]),
    'planetary':    (.965,[-.02,0,.21,.92,1.425,2.06,2.87,3.52]),
    'void':         (1.01,[-.02,0,.22,1.01,1.475,2.05,2.77,3.41])}

def point(p,kind):
    sx,z=PROFILES[kind]
    return (p[0]*sx,p[1],float(np.interp(p[2],LEVELS,z)))

def fit(ob,kind):
    if ob.type!='MESH':return
    sx,z=PROFILES[kind]
    # The rack is fitted as an assembled casting. Give each instance local mesh
    # data before projecting a non-affine set of stations into its local frame.
    if ob.data.users>1:ob.data=ob.data.copy()
    me=ob.data
    coords=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get('co',coords)
    m=np.asarray(ob.matrix_world)
    v=coords.reshape((-1,3))@m[:3,:3].T+m[:3,3]
    v[:,0]*=sx
    center=ob.get('station_rigid_center_z')
    if center is None:
        v[:,2]=np.interp(v[:,2],LEVELS,z)
    else:
        v[:,2]=np.interp(center,LEVELS,z)+(v[:,2]-center)*sx
    origin=point(m[:3,3],kind)
    local=(v-origin)@np.linalg.inv(m[:3,:3]).T
    mw=ob.matrix_world.copy();mw.translation=origin;ob.matrix_world=mw
    me.vertices.foreach_set('co',local.astype(np.float32).ravel());me.update()
    for prop in ('fmpl_pipette_socket_start_bu','fmpl_pipette_socket_end_bu'):
        if prop in ob:ob[prop]=list(point(ob[prop],kind))
