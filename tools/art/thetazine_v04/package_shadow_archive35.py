import pathlib,json,hashlib,zipfile
W=pathlib.Path(__file__).parent;R=W/'pilot-35';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();c=json.loads((R/'projected-shadow-capture.json').read_text());path=R/'source-package/projected-shadow-captures.zip'
with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for row in c['frames']:
  info=zipfile.ZipInfo(row['file'],(2026,11,9,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(R/row['file']).read_bytes())
 info=zipfile.ZipInfo('projected-shadow-capture.json',(2026,11,9,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,(R/'projected-shadow-capture.json').read_bytes())
with zipfile.ZipFile(path) as z:
 assert z.testzip() is None and len(z.namelist())==67
 for row in c['frames']:assert hashlib.sha256(z.read(row['file'])).hexdigest()==row['sha256']
v=json.loads((R/'projected-shadow-validation.json').read_text());v.update(source_archive_sha256=sha(path),source_archive_bytes=path.stat().st_size,pixel_contract='Original shadow PNG RGB dithering is limited to0/1byte. Runtime shadow atlas RGB is canonical black0; every alpha byte is preserved exactly through the common crop. Exact original RGBA captures remain archived.');(R/'projected-shadow-validation.json').write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8',newline='\n');print(path.stat().st_size,sha(path))
