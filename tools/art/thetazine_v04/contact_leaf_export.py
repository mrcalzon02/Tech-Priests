from PIL import Image,ImageDraw
import pathlib,sys
R=pathlib.Path(sys.argv[1]).resolve() if len(sys.argv)>1 else pathlib.Path(__file__).parent/'pilot-33';out=pathlib.Path(__file__).parents[2]/'outputs/thetazine-v04-current-export-contact.png';im=Image.new('RGB',(1200,1275),'#171717');d=ImageDraw.Draw(im)
for i,p in enumerate(sorted(R.glob('export-*.png'))):
 a=Image.open(p).convert('RGB');a.thumbnail((400,400));x=(i%3)*400;y=(i//3)*425;im.paste(a,(x,y+25));d.text((x+8,y+5),p.stem,fill='white')
im.save(out)
