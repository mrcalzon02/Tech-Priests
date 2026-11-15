"""Private owner-reference comparison plus neutral-background model review."""
from pathlib import Path
import argparse
from PIL import Image,ImageDraw,ImageOps
p=argparse.ArgumentParser();p.add_argument('model',type=Path);p.add_argument('reference',type=Path);a=p.parse_args()
private=a.model.parents[1]/'private-reference-review';private.mkdir(parents=True,exist_ok=True)
bg=(88,94,98)
def rendered(name,size):
    with Image.open(a.model/name) as src:
        src=src.convert('RGBA');src.thumbnail(size,Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',src.size,(*bg,255));canvas.alpha_composite(src)
        return canvas.convert('RGB')
board=Image.new('RGB',(1280,800),(33,37,40));d=ImageDraw.Draw(board)
with Image.open(a.reference) as src:
    ref=ImageOps.exif_transpose(src).convert('RGB');ref.thumbnail((540,720),Image.Resampling.LANCZOS)
    board.paste(ref,((580-ref.width)//2,45))
detail=rendered('feed-detail.png',(700,700));board.paste(detail,(580+(700-detail.width)//2,45))
d.text((25,18),'Owner reference / private working comparison',fill='white')
d.text((605,18),'Actual model / mesh-covered flexible side feed',fill='white')
board.save(private/'feed-reference-comparison.png')
overview=Image.new('RGB',(1440,860),bg);d=ImageDraw.Draw(overview)
for col,name in enumerate(('quarter.png','rear.png')):
    im=rendered(name,(700,700));overview.paste(im,(col*720+10,30))
    d.text((col*720+30,15),'Three-quarter view' if col==0 else 'Rear view / paired enclosed feeders',fill=(245,245,245))
    game=rendered(name,(198,198));overview.paste(game,(col*720+35,645))
    d.text((col*720+250,745),'Extra sensing + three connected aerials',fill=(245,245,245))
d.text((255,825),'Small inset: cap at calibrated base-zoom scale. Model review only; not an in-game capture.',fill=(245,245,245))
overview.save(a.model/'model-review.png')
