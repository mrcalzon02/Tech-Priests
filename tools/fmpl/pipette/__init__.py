"""FMPL Pipette: Blender-unit typed linework planner (prototype interface).

No module import automatically builds machinery or modifies a Blender scene.
"""
from .core import PipetteError, SIZE_PRESETS, infer_family_candidates, plan

__all__ = ["PipetteError", "SIZE_PRESETS", "infer_family_candidates", "plan"]
