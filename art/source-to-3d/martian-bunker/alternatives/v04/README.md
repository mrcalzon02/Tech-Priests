# Six cast iron lobber cannons — V04

The owner revised the lobber to three cannons per side of a shared central fin, six total. Each casting is short and bulbous, has a thick rounded ring muzzle and an open bore, and receives a large feeder tube directly into its bottom breech. Three source cannons and their connected feeders mirror across X=0. The central fin is shared.

This pass builds and renders the turret by itself. It does not load, replace or approximate the established bunker. Its bearing interface remains world Z=1.70. The existing oxide-red, dark-gunmetal and machined-steel texture tiles are reused from the committed V02 material files; the cast-iron shader uses high roughness.

Run Blender 5.0.1 from the repository root:

```sh
blender -b --factory-startup -t 2 --python-exit-code 12 --python art/source-to-3d/martian-bunker/alternatives/v04/build_six_lobber.py
```

The Actions workflow builds an editable packed Blender file, exports/reimports the GLB, verifies the three mirrored pairs and six bottom feeders, and renders front, side, oblique and feeder views. The output review PNG and complete ZIP are published here after a successful run. This remains a modeling review pass, not installed Factorio art or final visual acceptance.
