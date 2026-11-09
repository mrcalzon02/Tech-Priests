#!/usr/bin/env python3
"""Assemble private two-view diagnostic greeble previews into labeled review pages.
Requires Pillow in the local runner environment. Never claims semantic recognition.
"""
import argparse
import json
from pathlib import Path


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--root',required=True)
    p.add_argument('--columns',type=int,default=3)
    p.add_argument('--rows',type=int,default=5)
    a=p.parse_args()
    if not 1<=a.columns<=8 or not 1<=a.rows<=12:
        p.error('Bounded page dimensions required')
    try:
        from PIL import Image,ImageDraw,ImageFont
    except ImportError as exc:
        raise SystemExit('Install Pillow in runner Python; no Blender dependency') from exc
    root=Path(a.root).resolve()
    entries=[]
    for file in sorted(root.glob('parts/*/receipt.json')):
        data=json.loads(file.read_text(encoding='utf-8'))
        front=root/'previews'/(data['id']+'_front.png')
        rear=root/'previews'/(data['id']+'_rear.png')
        if front.is_file() and rear.is_file():
            entries.append((data,front,rear))
    if not entries:
        raise SystemExit('No paired previews yet; render previews before classification')
    target=root/'contact_sheets'
    target.mkdir(parents=True,exist_ok=True)
    cell_width=560
    cell_height=338
    page_size=a.columns*a.rows
    font=ImageFont.load_default()
    for n,start in enumerate(range(0,len(entries),page_size),1):
        data=entries[start:start+page_size]
        sheet=Image.new('RGB',(a.columns*cell_width,a.rows*cell_height),(35,38,40))
        draw=ImageDraw.Draw(sheet)
        for index,(record,front,rear) in enumerate(data):
            x=(index%a.columns)*cell_width
            y=(index//a.columns)*cell_height
            with Image.open(front) as f,Image.open(rear) as r:
                f=f.convert('RGBA').resize((256,256))
                r=r.convert('RGBA').resize((256,256))
                sheet.paste(f,(x+12,y+44),f)
                sheet.paste(r,(x+276,y+44),r)
            draw.text((x+12,y+8),record['id'],fill=(240,240,240),font=font)
            draw.text((x+12,y+25),'Source: '+record['source_object']+'  |  UNCLASSIFIED',fill=(190,190,190),font=font)
            draw.text((x+12,y+308),'Front',fill=(225,225,225),font=font)
            draw.text((x+276,y+308),'Rear',fill=(225,225,225),font=font)
        out=target/f'greebles_contact_{n:03d}.png'
        sheet.save(out)
        print('FMPL_CONTACT_SHEET',out,flush=True)
    print('FMPL_CONTACT_SHEETS_DONE',len(entries),flush=True)

if __name__=='__main__':main()
