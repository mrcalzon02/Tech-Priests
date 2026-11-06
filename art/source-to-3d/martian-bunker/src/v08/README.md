# v0.8 — Actual Blender asset: visual reference-based hard-surface modeling

Actual mesh modifications: large circular gun mantlet with 12 fasteners; curved and screw-fixed barrel service cover; machined collar family; flanking 6-bolt optical instruments with status lights; periscope hood; amber status panel; roof service armor; own original machine-purity cog seal; mounted hydraulic recoil details; anchored small panel-edge abrasions. Source is rebuilt from v0.7 and retains the genuinely round barrel jacket.

No screenshot/photo pixels have been embedded in materials; albedo, normal and ORM textures are procedural and original. User-provided reference image used for *design comparison only*. Art is a deliberate approximation that must be judged against rendered Blender outputs.

Run: `python build_blockout.py && python make_textures.py && python verify_visual_target_v08.py && python verify_barrel_v08.py` followed by Blender `--python setup_blender.py -- --render` and independent export test.

No production Factorio asset replaced.
