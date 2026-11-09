#!/usr/bin/env python3
"""Read a pinned FMPL checkout from an external Factorio repository. No network or writes."""
import argparse
import json
import subprocess
from pathlib import Path
from fmpl import validate, records


def check_consumer(config_path, library_root, item_id=None):
    config = json.loads(Path(config_path).read_text(encoding="utf-8"))
    library_root = Path(library_root).resolve()
    if config.get("schema") != "fmpl.consumer.v1":
        raise ValueError("Invalid FMPL consumer contract")
    if config.get("module_repo") != "mrcalzon02/Tech-Priests":
        raise ValueError("Unexpected FMPL canonical repository")
    pin = config.get("module_commit")
    if not isinstance(pin,str) or len(pin) != 40:
        raise ValueError("An exact 40-character module SHA is required")
    manifest = library_root / "tools" / "fmpl" / "FMPL.json"
    if not manifest.is_file():
        raise FileNotFoundError("FMPL source checkout missing; acquire pinned checkout first")
    if (library_root/".git").exists():
        proc=subprocess.run(["git","-C",str(library_root),"rev-parse","HEAD"],
                            stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                            text=True,check=True,timeout=15)
        actual=proc.stdout.strip()
        if actual != pin:
            raise RuntimeError(f"FMPL checkout pin mismatch: expected {pin}, got {actual}")
    else:
        raise RuntimeError("Missing .git provenance; cannot verify FMPL source revision")
    registry = validate(library_root)
    if registry["version"] != config.get("module_version"):
        raise RuntimeError("FMPL manifest version mismatch")
    required=config.get("uses",[])
    if not isinstance(required,list):
        raise ValueError("FMPL uses must be a list")
    known={x["id"] for x in records(registry)}
    for wanted in required:
        if wanted not in known:
            raise RuntimeError("Unknown FMPL asset: "+str(wanted))
    if item_id:
        if item_id not in known:
            raise ValueError("Unknown FMPL source item: "+item_id)
        selected=next(x for x in records(registry) if x["id"]==item_id)
        return {"consumer":config.get("consumer_repo"),"module_version":registry["version"],
                "module_commit":actual,"entry":selected}
    return {"consumer":config.get("consumer_repo"),"module_version":registry["version"],
            "module_commit":actual,"uses":required,"valid":True}


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--config",required=True)
    p.add_argument("--library-root",required=True)
    p.add_argument("--asset-id")
    a=p.parse_args()
    print(json.dumps(check_consumer(a.config,a.library_root,a.asset_id),indent=2,sort_keys=True))


if __name__=="__main__":
    main()
