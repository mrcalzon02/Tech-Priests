# Workbench V5 animation inspection

Approved V4 bench geometry with a baked eight-second work cycle at 24 fps:

- Frames 1–25: hammer picks up and draws back.
- Frames 32, 48, 64, 80, 96, 112: six strikes at the sheet center. Each impact emits short ballistic sparks.
- Heat accumulates in the sheet around the impact point, peaking after the final strike.
- Frame 143: hammer is laid down in its original pose.
- Frames 143–192: local heat fades to cold metal. First and final resting states match.

Native animation is fully keyframed and needs no physics bake, addon, or frame handler. The metal remains one continuous sheet. The original bench geometry and materials are preserved except the sheet's animated heat shader. One camera.

The inspection preview samples every second animation frame (96 images at 12 fps). This is a visual-review cycle; engine sprite registration, four-direction captures and gameplay working/idle transition integration follow approval.

Rebuild from the V4 source model in this folder:

    blender -b --python animate_workbench.py -- --render
