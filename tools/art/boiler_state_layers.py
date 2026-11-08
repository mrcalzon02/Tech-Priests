"""Native boiler cold/working decomposition, retaining all source working poses.

A normal source-over overlay cannot erase the cold body's alpha. Lower only the
cold alpha to the largest value compatible with every working pose and RGB
channel, then solve each activity pixel. Never replace the authored source files.
"""
import math
from PIL import Image


def split_boiler_state_layers(idle, working, frames, columns, rows):
    import numpy as np
    size = idle.width
    if (idle.mode != 'RGBA' or working.mode != 'RGBA' or idle.height != size*4
            or frames < 1 or rows != math.ceil(frames/columns)
            or working.size != (columns*size, rows*4*size)):
        raise ValueError('Boiler layer source dimensions/layout invalid')
    cold = np.array(idle)
    source = np.array(working)
    activity = np.zeros_like(source)
    directions = []
    for direction, name in enumerate(('north', 'east', 'south', 'west')):
        base = cold[direction*size:(direction+1)*size].astype(np.float64)/255
        color = base[:, :, :3]
        compatible_alpha = base[:, :, 3].copy()

        def cell(frame):
            x = frame % columns*size
            y = (direction*rows+frame//columns)*size
            return x, y, source[y:y+size, x:x+size].astype(np.float64)/255

        for frame in range(frames):
            _, _, target = cell(frame)
            alpha = target[:, :, 3]
            premult = target[:, :, :3]*alpha[:, :, None]
            # Bounds ensuring each solved overlay channel remains in [0, 1].
            low = premult+color*(1-alpha[:, :, None])
            high = 1-premult-color*(1-alpha[:, :, None])
            low_bound = np.divide(premult, low, out=np.ones_like(low), where=low > 1e-12)
            high_bound = np.divide(alpha[:, :, None]-premult, high,
                                   out=np.ones_like(high), where=high > 1e-12)
            compatible_alpha = np.minimum(compatible_alpha,
                np.minimum(alpha, np.minimum(low_bound.min(axis=2), high_bound.min(axis=2))))
        base_alpha = np.floor(np.clip(compatible_alpha, 0, 1)*255+1e-9)/255
        cold[direction*size:(direction+1)*size, :, 3] = np.rint(base_alpha*255).astype(np.uint8)
        cold_cell = Image.fromarray(cold[direction*size:(direction+1)*size])
        max_error = 0.
        mean_error = 0.
        for frame in range(frames):
            x, y, target = cell(frame)
            alpha = target[:, :, 3]
            premult = target[:, :, :3]*alpha[:, :, None]
            overlay_alpha = np.divide(alpha-base_alpha, 1-base_alpha,
                out=np.ones_like(alpha), where=base_alpha < 1-1e-12)
            # Keep opaque body regions continuous even where RGB is unchanged.
            # Sparse holes reconstruct at 1:1 but break native bilinear scaling.
            # Round upward so quantization cannot reveal a missing body edge.
            overlay_alpha = np.ceil(np.clip(overlay_alpha, 0, 1)*255-1e-9)/255
            overlay_premult = premult-color*base_alpha[:, :, None]*(1-overlay_alpha[:, :, None])
            overlay_color = np.divide(overlay_premult, overlay_alpha[:, :, None],
                out=np.zeros_like(overlay_premult), where=overlay_alpha[:, :, None] > 0)
            overlay = np.concatenate([np.rint(np.clip(overlay_color, 0, 1)*255),
                np.rint(overlay_alpha[:, :, None]*255)], axis=2).astype(np.uint8)
            activity[y:y+size, x:x+size] = overlay
            composite = np.array(Image.alpha_composite(cold_cell,
                Image.fromarray(overlay))).astype(np.float64)/255
            errors = []
            for background in (0., 1.):
                displayed = composite[:, :, :3]*composite[:, :, 3:4]+background*(1-composite[:, :, 3:4])
                expected = target[:, :, :3]*target[:, :, 3:4]+background*(1-target[:, :, 3:4])
                errors.append(np.abs(displayed-expected)*255)
            max_error = max(max_error, *(float(e.max()) for e in errors))
            mean_error += max(float(e.mean()) for e in errors)/frames
        loss = base[:, :, 3]*255-base_alpha*255
        fraction = float(loss.sum()/max(1, (base[:, :, 3]*255).sum()))
        if max_error > 2.01:
            raise ValueError(f'{name}: working composite error exceeds 2/255: {max_error}')
        if fraction > .002:
            raise ValueError(f'{name}: cold coverage loss exceeds 0.2%: {fraction}')
        directions.append({'direction': name, 'cold_alpha_changed_pixels': int((loss > .1).sum()),
            'cold_original_occupied_pixels': int((base[:, :, 3] > 0).sum()),
            'cold_max_alpha_reduction': float(loss.max()),
            'cold_alpha_coverage_reduction_fraction': fraction,
            'working_composite_black_white_max_channel_error': max_error,
            'working_composite_black_white_mean_channel_error': mean_error})
    return Image.fromarray(cold), Image.fromarray(activity), {
        'method': 'source-over-v1', 'size': size, 'frames_per_direction': frames,
        'columns': columns, 'rows_per_direction': rows, 'directions': directions,
        'visual_acceptance': 'Native inspection required; numerical bounds alone are not art acceptance.'}
