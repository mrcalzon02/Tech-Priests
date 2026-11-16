# Mars Plasma Reactors

Drop the mod ZIP into your Factorio 2.1 mods folder, then enable **Mars Plasma Reactors — Animation Preview**. The three preview machines are available in the energy crafting category. Each costs one iron plate to make.

Supply chemical fuel and connect the unit to a network with electrical demand. Minoris, Majoris and Maximus deliver 1, 2 and 4 MW respectively in this preview. When fuel runs out, the machine returns to its dark, stationary pose. All four cardinal directions have independent sprite sheets.

The startup setting **Reactor sprite resolution** selects high-resolution (64 px per tile) or standard-resolution (32 px per tile) artwork. Both settings use the same world scale and anchor. The working animation is a two-second, sixteen-frame loop with a separate additive light layer. Steam and coil distortion are baked into the machine sprites.

With the mod enabled, the included headless scenario checks all three machines in four directions under electrical load.

```sh
factorio --test-scenario mars-reactor-visuals/reactor-power-cycle
```

To check the exact distribution ZIP at both resolutions, run the following from the source kit’s `animation/factorio_preview` directory with Python 3.11+, Pillow and a Factorio 2.1 executable. The verifier creates temporary game profiles, tests 24 power cycles, and inspects all 816 sprite cells. Add `--frames /path/to/frames` to compare the exported alpha against the uncropped captures.

```sh
python verify_install.py /path/to/factorio /path/to/mars-reactor-visuals_1.0.0.zip --receipt verification.json
```
