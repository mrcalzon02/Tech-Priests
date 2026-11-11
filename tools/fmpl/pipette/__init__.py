"""FMPL Pipette: importable pure-Python geometry and typed connection library.

A safe Python library; importing Pipette does not start Blender or modify
source scenes. Native bpy export is an explicit command via library_blender.py.
"""
from .core import PipetteError, SIZE_PRESETS, infer_family_candidates, plan
from .library_geometry import RECIPES, build_demo, export_obj, line_segment
from .library_fittings import FITTING_RECIPES, build as build_fitting
from .library_branches import build_eight_wire_y

__all__ = [
    "PipetteError", "SIZE_PRESETS", "infer_family_candidates", "plan",
    "RECIPES", "build_demo", "export_obj", "line_segment",
    "FITTING_RECIPES", "build_fitting", "build_eight_wire_y"
]
