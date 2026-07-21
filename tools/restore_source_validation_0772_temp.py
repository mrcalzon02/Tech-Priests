#!/usr/bin/env python3
from pathlib import Path
import subprocess

path = Path('.github/workflows/source-validation.yml')
base = subprocess.check_output([
    'git', 'show',
    '853aaa1fe58e88fbcfdbf26a7dc548e2809e3e6c:.github/workflows/source-validation.yml'
], text=True)
anchor = '''      - name: Audit retired 0500 lifecycle seal
        run: python3 tools/check_lifecycle_seal_0500_boundary_0771.py
'''
insertion = anchor + '''
      - name: Audit retired 0501 vanish guard
        run: python3 tools/check_vanish_guard_0501_boundary_0772.py
'''
if anchor not in base:
    raise SystemExit('validator 0771 anchor missing')
path.write_text(base.replace(anchor, insertion, 1), encoding='utf-8')
Path(__file__).unlink()
