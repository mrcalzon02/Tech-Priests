# Thetazine V03 pressure and containment study

Owner-directed refinement of the verified V02 working pilot: taller platform-mounted gantry, raised pump/manifold machinery, real hollow sight glass around visible magenta fuel and blue water, animated pressure fronts/gauges, six heavy hydraulic restraint cylinders, interleaved sealing leaves, hot/charred bell and separate tinted oscillating exhaust geometry.

This is editable **local refinement source**, not the ordinary game sprite. The prior source and imported interfaces remain preserved. See `source-export-plan.json` for fixed ports, exact source-to-sprite registration, layer packing proposal and native visual gates. [Independent technical/visual evidence](../../../../../docs/art/thetazine-thruster-v03/README.md).

`thetazine-v03-pressure-study.blend` packs its images. GLB contains all working transform/morph poses and packed PBR textures. Dynamic heat-strength keys and the cold frame remain native Blender states; no glTF material-animation claim. `source-captures.zip` preserves all 66 combined body+FX source PNGs and their capture receipt; these are not final segmented runtime layers.

Rebuild locally in compatible Blender 5.0.1 using `make_textures.py --out <new-texture-directory>`, then background `--python build_model.py -- --source <verified-v02.blend> --textures <new-texture-directory> --out <new-study-directory>`. Input V02 hash is guarded. Outputs must be new directories. Use the independent validators and render/capture tools under `tools/art/thetazine_v03`; keep expensive phases checkpointed and never mix source hashes. No GitHub Actions are needed.
