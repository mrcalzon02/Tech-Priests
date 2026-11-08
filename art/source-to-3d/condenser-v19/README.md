# Condenser V19 — adjacent pipe fit

Open `tech_priests_water_condenser_v19.blend`. It contains the actual editable condenser, its new hollow water outlet, two adjacent reference pipe meshes, tile grid, and inspection cameras. This is a Blender geometry revision; the supplied gameplay image is a reference only.

One Blender unit equals one Factorio tile. The foundation's longest ground dimension is 1.9 tiles within a 2×2 footprint; the original proportions are preserved by uniform scaling. Blender +Y corresponds to Factorio north (negative map Y). The outlet mouth is at Blender `(1, -0.5, 0.36)`, facing east on the front/south tile row. The adjacent pipe's tile center is Factorio `(1.5, 0.5)` relative to the machine center. The body diameter is 0.57 tile, the flange diameter 0.68, and the open bore diameter 0.49. These are visual calibration estimates from the reference, not dimensions from an original Wube model.

All 141 existing V18 mesh vertex arrays remain unchanged. Uniform placement and 13 new outlet meshes provide the fit. The prior source finish review remains open; this revision does not imply acceptance of unrelated detail or materials. The boiler has not been edited.

`REFERENCE_ADJACENT_PIPES` and `REFERENCE_TILE_GRID` are separate Blender collections. Hide them for asset-only inspection. The GLB contains the condenser and outlet only, without pipe or grid references.

The included prototype patch explicitly places the east output at `(0.5, 0.5)`. It is supplied for later integration, and has not been applied to the live mod. No Factorio runtime validation or production sprite replacement is claimed.

The PNGs are actual Blender renders: game angle, oblique, overhead, and height inspection. Validation reopens the native file, checks unchanged source vertices, checks closed added meshes, compares the complete bore and barrel rings at the joint, and imports the GLB to compare bounds. Cardinal rotation results are mathematical transforms of the joined assembly, not four in-game captures.

The complete ZIP also includes the preserved V18 source model and build/validation scripts. From the extracted ZIP root:

```
blender --background --threads 6 --python build_condenser_v19.py
blender --background --threads 6 --python validate_condenser_v19.py
blender --background --threads 4 --python readback_condenser_v19.py
```

Validated locally with Blender 4.3.2. The `.blend` contains packed image textures. `Pipe.png` is Wube's Factorio reference image, recovered from the prior boiler package, and is not used as a model texture.

## Saved editable assets

- [Native Blender fit scene](https://chatgpt.com/library?file_id=libfile_334339b507e88191beab3d64326ec58c&account_id=personal)
- [Complete package, including preserved V18 source](https://chatgpt.com/library?file_id=libfile_c1ef224386708191988ce66a15aadf9f&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_fbe6d37df4cc81918cbc57d3b61d3701&account_id=personal)

The repository stores the reconstruction scripts, measurements, proposed integration patch, and validation evidence. The packed native and GLB binaries are linked above. The archive has the directory layout expected by the scripts.
