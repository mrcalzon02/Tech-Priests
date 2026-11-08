"""Project a measured stationary model mount into the native four-way graphics."""
import math
from pathlib import Path


def circuit_registration(job, cfg):
    attachment = job.get('boiler_circuit_attachment')
    if attachment is None:
        return None
    anchor = attachment['mount_model_space']
    ground = [anchor[0], anchor[1], 0.]
    camera = cfg['camera_override']
    if camera['azimuth_deg'] != 0:
        raise ValueError('Boiler circuit mount requires the calibrated world-aligned camera')
    elevation = math.radians(camera['elevation_deg'])
    target = camera['target']
    pivot = cfg['pivot']
    size = job['primary_size']
    registrations = {}
    for i, name in enumerate(('north', 'east', 'south', 'west')):
        source_index = job.get('source_direction_indices', [0,1,2,3])[i]
        angle = math.radians(cfg['directions'][source_index])
        draw = (job.get('directional_registration') or {}).get(name,
            {'scale':job['scale'], 'shift':job['shift']})
        factor = size*draw['scale']/(32*camera['ortho_scale'])
        entry = {'scale':attachment['native_scale']*factor}
        for key, point in [('main_offset',anchor), ('shadow_offset',ground)]:
            dx,dy = point[0]-pivot[0], point[1]-pivot[1]
            x = pivot[0]+dx*math.cos(angle)-dy*math.sin(angle)
            y = pivot[1]+dx*math.sin(angle)+dy*math.cos(angle)
            up = (y-target[1])*math.sin(elevation)+(point[2]-target[2])*math.cos(elevation)
            entry[key] = [draw['shift'][0]+(x-target[0])*factor,
                          draw['shift'][1]-up*factor]
        registrations[name] = entry
    return registrations


def circuit_attachment_lua(job, cfg):
    registration = circuit_registration(job,cfg)
    if registration is None:
        return ''
    def vector(value):
        return '{'+','.join(f'{v:.12g}' for v in value)+'}'
    entries = []
    for name in ('north','east','south','west'):
        entry = registration[name]
        entries.append('{main_offset='+vector(entry['main_offset'])
            +',shadow_offset='+vector(entry['shadow_offset'])
            +f",scale={entry['scale']:.12g}"+'}')
    template = Path(__file__).with_name('boiler_circuit_attachment.lua').read_text(encoding='utf-8')
    tint = job['boiler_circuit_attachment']['base_tint']
    return template.replace('CIRCUIT_REGISTRATION_TABLE','{\n  '+',\n  '.join(entries)+'\n}').replace(
        'CIRCUIT_BASE_TINT', '{'+','.join(f'{k}={v:.12g}' for k,v in zip(('r','g','b','a'),tint))+'}')
