"""Present the actual registered Factorio RGBA samples as looping inspection films."""
from argparse import ArgumentParser
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from fmpl_adapter import ANGLE_FOR_HEADING, NAMES, RADII, profile, project, registration

FRAME_COUNT = 16
FPS = 8
INK = (29, 31, 31)
TEXT = (238, 232, 218)
METAL = (207, 170, 123)
RULE = (108, 98, 83)
HEADINGS = ('north', 'east', 'south', 'west')


def font(size, heading=False):
    choices = (['/usr/share/fonts/opentype/urw-base35/P052-Roman.otf', 'DejaVuSerif.ttf']
               if heading else ['/usr/share/fonts/truetype/open-sans/OpenSans-Semibold.ttf',
                                'DejaVuSans.ttf'])
    for path in choices:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def background(width, height):
    # Static neutral ground keeps transparent steam and moving metals legible.
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    rgb = np.array([92, 95, 95]) * (1.0 - y) + np.array([63, 64, 64]) * y
    strip = np.uint8(rgb).reshape(height, 1, 3)
    return Image.fromarray(np.repeat(strip, width, axis=1)).convert('RGBA')


def rgba(path):
    with Image.open(path) as image:
        if image.mode != 'RGBA':
            raise ValueError(f'{path} is {image.mode}; registered straight RGBA is required')
        return image.copy()


def frames(root, name, direction):
    base = root / name.lower() / direction
    shadow = rgba(base / 'shadow.png')
    images = [Image.alpha_composite(shadow, rgba(base / f'{i:02}.png'))
              for i in range(1, FRAME_COUNT + 1)]
    cfg = profile(name)
    expected = (cfg['source_size'], cfg['source_size'])
    if any(image.size != expected for image in images):
        raise ValueError(f'Unexpected {name} {direction} frame size')
    return images


def bounds(images):
    # One union for the complete loop; translucent puffs cannot shift its crop.
    boxes = []
    for im in images:
        b = im.getchannel('A').point(lambda alpha: 255 if alpha >= 2 else 0).getbbox()
        if b:
            boxes.append(b)
    if not boxes:
        raise ValueError('Empty image sequence')
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def even(number):
    return int(np.ceil(number / 2.0)) * 2


def heading(draw, width, title, spec):
    draw.rectangle((0, 0, width, 70), fill=INK)
    draw.text((28, 36), title, font=font(35, True), anchor='lm', fill=TEXT)
    draw.text((width - 28, 36), spec, font=font(15), anchor='rm', fill=METAL)
    draw.line((0, 70, width, 70), fill=RULE, width=1)


def write_animation(images, output, name):
    output.mkdir(parents=True, exist_ok=True)
    rgb = [im.convert('RGB') for im in images]
    with TemporaryDirectory() as scratch:
        scratch = Path(scratch)
        for i, img in enumerate(rgb):
            img.save(scratch / f'{i:02}.png')
        if not shutil.which('ffmpeg'):
            raise RuntimeError('FFmpeg is required for the GIF palette and H.264 inspection film')
        command = ['ffmpeg', '-v', 'error', '-y', '-filter_complex_threads', '2',
                   '-framerate', str(FPS), '-i', str(scratch / '%02d.png')]
        # Fixed palette and deterministic ordered dithering avoid pumping on stationary armor.
        subprocess.run(command + [
            '-filter_complex', '[0:v]split[a][b];[a]palettegen=stats_mode=full[p];'
            '[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle',
            '-loop', '0', '-final_delay', '12', str(output / f'{name}.gif')], check=True)
        subprocess.run(command + ['-vf', 'loop=loop=2:size=16:start=0', '-t', '6',
                                   '-c:v', 'libx264', '-crf', '16', '-preset', 'fast',
                                   '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                                   str(output / f'{name}.mp4')], check=True)
    with Image.open(output / f'{name}.gif') as gif:
        if gif.n_frames != FRAME_COUNT or gif.info.get('loop') != 0:
            raise ValueError(f'Incomplete loop in {name}.gif')
        total_ms = 0
        for i in range(FRAME_COUNT):
            gif.seek(i)
            total_ms += gif.info['duration']
        if total_ms != FRAME_COUNT * 1000 // FPS:
            raise ValueError(f'Incorrect playback time in {name}.gif: {total_ms} ms')


def family(root, output):
    tracks = [frames(root, n, 'south') for n in NAMES]
    boxes = [bounds(track) for track in tracks]
    pivots = [registration(profile(n))['origin_px'] for n in NAMES]
    gap, pad, footer = 27, 27, 51
    top = 88
    above = max(p[1] - b[1] for p, b in zip(pivots, boxes))
    below = max(b[3] - p[1] for p, b in zip(pivots, boxes))
    ground = round(top + above)
    bottom = round(ground + below + 15)
    widths = [b[2] - b[0] for b in boxes]
    width = even(sum(widths) + 2 * gap + 2 * pad)
    height = even(bottom + footer)
    base = background(width, height)
    d = ImageDraw.Draw(base)
    heading(d, width, 'Plasma reactors in operation', 'SOUTH   /   64 PX PER TILE   /   8 FPS')
    d.rectangle((0, bottom, width, height), fill=INK)
    d.line((0, bottom, width, bottom), fill=RULE)
    places = []
    left = pad
    for name, pivot, box, span in zip(NAMES, pivots, boxes, widths):
        # All three true model ground pivots share a baseline at their authored spatial scale.
        places.append((round(left - box[0]), round(ground - pivot[1])))
        d.text((round(left + span / 2), bottom + footer // 2), name,
               font=font(19), fill=TEXT, anchor='mm')
        left += span + gap
    images = []
    for i in range(FRAME_COUNT):
        page = base.copy()
        for source, pos in zip(tracks, places):
            page.alpha_composite(source[i], dest=pos)
        images.append(page)
    write_animation(images, output, 'Reactor_Family_Operating')


def detail_crop(cfg, relative_xyz, span_in_radii, heading_name, aspect):
    radius = RADII[2]
    point = [v * radius for v in relative_xyz]
    cx, cy = project(cfg, point, ANGLE_FOR_HEADING[heading_name])
    px_per_unit = cfg['source_size'] / cfg['camera_override']['ortho_scale']
    width = round(span_in_radii * radius * px_per_unit)
    height = round(width / aspect)
    x, y = round(cx - width / 2), round(cy - height / 2)
    return (x, y, x + width, y + height)


def details(root, output):
    directions = {d: frames(root, 'Maximus', d) for d in ('south', 'east', 'west')}
    cfg = profile('Maximus')
    card_w, card_h = 386, 302
    pad, gap, top, footer = 13, 8, 84, 50
    width, height = even(2*pad + 3*card_w + 2*gap), even(top + card_h + footer)
    page = Image.new('RGBA', (width, height), INK)
    d = ImageDraw.Draw(page)
    heading(d, width, 'Maximus in operation', 'MECHANICAL DETAIL   /   8 FPS')
    panels = [
        ('Containment ports', 'south', (0, -.51, 1.15), 2.28),
        ('Vaulted exhaust', 'east', (-.025, -.66, 2.39), 1.80),
        ('Thermic regulators', 'west', (1.295, .75, 1.14), 2.30),
    ]
    crops = []
    for i,(title, view, center, width_r) in enumerate(panels):
        box = detail_crop(cfg, center, width_r, view, card_w/card_h)
        x = pad + i*(card_w+gap)
        crops.append((view, box, x))
        page.alpha_composite(background(card_w, card_h), (x,top))
        d.line((x, top+card_h, x+card_w-1, top+card_h), fill=RULE)
        d.text((x+card_w//2, top+card_h+footer//2), title,
               font=font(18), anchor='mm', fill=TEXT)
    rendered = []
    for i in range(FRAME_COUNT):
        out = page.copy()
        for view, box, x in crops:
            cut = directions[view][i].crop(box).resize((card_w,card_h),Image.Resampling.LANCZOS)
            out.alpha_composite(cut, (x,top))
        rendered.append(out)
    write_animation(rendered, output, 'Maximus_Operating_Details')


def state_sheet(root, output):
    data = {}
    for direction in HEADINGS:
        base = root / 'maximus' / direction
        shadow = rgba(base / 'shadow.png')
        data[direction] = tuple(Image.alpha_composite(shadow, rgba(base / name))
                                for name in ('off.png', '05.png'))
    # Share one square-camera transform over all eight images to preserve registration.
    box = bounds([im for pair in data.values() for im in pair])
    box = (box[0]-5, box[1]-5, box[2]+5, box[3]+5)
    card_width = 322
    card_height = round((box[3]-box[1])*card_width/(box[2]-box[0]))
    pad, gap, label = 12, 6, 35
    width = 2*pad + 4*card_width + 3*gap
    height = 74 + 2*(label+card_height+gap) + 36
    img=Image.new('RGBA',(width,height),INK)
    d=ImageDraw.Draw(img)
    heading(d,width,'Maximus • four headings','REGISTERED FACTORIO SPRITES')
    for row, title in enumerate(('Powered down','Operating')):
        y=74+row*(label+card_height+gap)
        d.text((pad,y+label//2),title,fill=METAL,font=font(16),anchor='lm')
        for i,direction in enumerate(HEADINGS):
            x=pad+i*(card_width+gap)
            image=data[direction][row].crop(box).resize((card_width,card_height),Image.Resampling.LANCZOS)
            card=background(card_width,card_height)
            card.alpha_composite(image)
            img.alpha_composite(card,(x,y+label))
            if row:
                d.text((x+card_width//2,y+label+card_height+20),direction.title(),fill=TEXT,
                       font=font(18),anchor='mm')
    output.mkdir(parents=True,exist_ok=True)
    img.convert('RGB').save(output/'Maximus_Four_Headings.jpg',quality=94,subsampling=0,optimize=True)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='capture folder containing frames/')
    parser.add_argument('--proof', choices=('family','details','states','all'), default='all')
    args = parser.parse_args()
    render = {'family':family,'details':details,'states':state_sheet}
    selected = tuple(render) if args.proof=='all' else (args.proof,)
    for name in selected:
        render[name](args.output/'frames',args.output/'Previews')


if __name__ == '__main__':
    main()
