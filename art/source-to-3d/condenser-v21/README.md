# Condenser V21 — integrated outlet and matching metal finish

The condenser's right side cheek, cast receiver and hollow outlet neck are now one connected, closed mesh. The receiver has been seated visibly against the housing, replacing the partly buried V20 collar. Boolean joins are welded and checked for open or multiply connected edges. The pipe connection plane remains X=1, Y=-0.5, Z=0.36 in Blender tile units.

The root uses the condenser's actual `iron` material and texture maps. The neck grades from that warm dark iron toward the adjacent pipe's lighter silver/green steel, with a matching roughness transition. Packed UV textures preserve this finish in the GLB. The outer flange and inner rim share the exact material used by the adjacent pipe collar. The small seating gasket is dark iron.

The adjacent reference pipe geometry, 2×2 footprint and V20 housing height are preserved. Reference pipes and ground grid are separate collections and excluded from the asset-only GLB. All preview PNGs are Blender renders.

Validation checks one connected closed housing/root/neck mesh, 128 corresponding joint-ring vertices, unchanged reference geometry, shared collar material, native reopen and GLB mesh/bounds readback. Tiny float rounding at the joint is within 0.00001 tile. No Factorio runtime integration or production sprite replacement is claimed.

The archive includes the V20 source and scripts. From the extracted root:

```
blender --background --threads 6 --python build_condenser_v21.py
blender --background --threads 4 --python readback_condenser_v21.py
```

Validated with Blender 4.3.2. The final asset contains 152 meshes; the receiver and neck were merged into the existing side cheek.

## Saved assets

- [Editable Blender model](https://chatgpt.com/library?file_id=libfile_334339b507e88191beab3d64326ec58c&account_id=personal)
- [Complete V21 package with preserved V20 source](https://chatgpt.com/library?file_id=libfile_a0e5a008866881919cf7c32c9a7aab0c&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_fbe6d37df4cc81918cbc57d3b61d3701&account_id=personal)

Native binaries are linked above. This directory contains the scripts, hashes and validation records.

## Approved V21 Blender source — now recoverable directly from Git

The owner-accepted V21 native source was recovered from ChatGPT Library, verified as exactly **39,369,602 bytes** with SHA-256 `1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b`, and added byte-for-byte to `source-parts/` as 19 Git binary blobs. Each part has an independent SHA-256 and a Git blob SHA-1 recorded in `source_manifest.json`. There is no reconstructed geometry and no dependency on future Library access.

Restore from any ordinary Git checkout:

```sh
python3 art/source-to-3d/condenser-v21/restore_condenser_v21_source.py --out /tmp/tech_priests_water_condenser_v21.blend
```

Run the real native V22 Blender animation/review using only the checked-out source:

```sh
python3 art/source-to-3d/condenser-v21/run_condenser_v22_review.py --repo-source --blender blender --out /tmp/condenser-v22-review-01
```

On the Windows Blender host, run `Run-Condenser-V22-Review.ps1` with no source arguments; its default is now this verified Git backup, not a best-effort filesystem scan. Native Blender rendering, human visual approval and in-game sprite integration are separate gates.
