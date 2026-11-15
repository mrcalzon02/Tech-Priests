"""Check actual native URI references; headless Factorio skips bitmap loading."""
from pathlib import Path


def verify_references(raw,mod):
    mod=Path(mod);prefix='__tp-hydrogen-production__/';found=set()
    def walk(value):
        if isinstance(value,dict):
            for v in value.values():walk(v)
        elif isinstance(value,list):
            for v in value:walk(v)
        elif isinstance(value,str) and value.startswith(prefix):found.add(value[len(prefix):])
    walk(raw)
    missing=[p for p in sorted(found) if not (mod/p).is_file()]
    if missing:raise RuntimeError('Native asset URIs reference missing files: '+str(missing))
    return sorted(found)
