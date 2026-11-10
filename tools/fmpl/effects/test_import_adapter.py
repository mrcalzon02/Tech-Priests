#!/usr/bin/env python3
"""No-Blender static checks for the import API and supported source surface."""
from pathlib import Path
import ast
from test_presets import main as check_registry

def main():
    check_registry()
    file=Path(__file__).with_name("import_effects.py")
    tree=ast.parse(file.read_text(encoding="utf-8"))
    public={n.name for n in tree.body if isinstance(n,ast.FunctionDef)}
    assert {"import_materials","append_rig"}.issubset(public)
    assert not any(isinstance(n,ast.Import) and any(a.name=="bpy" for a in n.names) for n in tree.body)
    print("FMPL_EFFECTS_IMPORT_ADAPTER_CONTRACT_PASS")

if __name__=="__main__":main()
