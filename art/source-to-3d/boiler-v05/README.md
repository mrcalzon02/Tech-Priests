# Boiler V05 — matching external pipe scale

The native V04 boiler has been calibrated to one Blender unit per tile, with a 1.9-tile foundation inside its intended 2×2 footprint. All 202 original core mesh vertex arrays are preserved under one uniform placement transform. The previous 30 undersized external-port meshes are replaced by two full-size hollow reducing elbows and seated unions.

Both mouths use the established condenser standard: 0.57-tile barrel, 0.68-tile flange, 0.49-tile bore, and Z=0.36-tile centerline. Water enters at Blender (-1, 0.5, 0.36); steam exits at (1, 0.5, 0.36). These are the rear/north tile row, with adjacent Factorio pipe centers (-1.5,-0.5) and (1.5,-0.5). The large external barrels taper to the smaller original vessel connections. Water seats into the main horizontal vessel and steam into the separate right pressure chamber.

The elbows reuse the condenser's packed body-to-pipe metal colour and roughness textures; the flanges use its exact matching adjacent-collar material. Original boiler materials and UVs remain on the preserved core.

The native `.blend` includes a separate `BOILER_REFERENCE_ADJACENT_PIPES` collection and a 45° orthographic camera. Reference pipes are excluded from the GLB. PNG previews are actual Blender renders.

This revision is ready for model review. The earlier two-port prototype patch is included unchanged for later integration; it has not been applied to the live mod, and no game runtime validation is claimed. Animation remains pending.

The complete archive includes V04 source and the condenser V21 source used for its shared pipe materials. From the extracted root:

```
blender --background --threads 6 --python build_boiler_v05.py
blender --background --threads 4 --python readback_boiler_v05.py
```

Validated with Blender 4.3.2.

## Saved assets

- [Editable boiler V05](https://chatgpt.com/library?file_id=libfile_a76488dcaadc8191a3a38ae50b31f8ab&account_id=personal)
- [Complete package with source models](https://chatgpt.com/library?file_id=libfile_74f5f6f92d2481919753dba9398f9af8&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_28690160587081918b57fc963558ecca&account_id=personal)

The repository stores reproducible source scripts and validation records; packed native binaries are linked above.
