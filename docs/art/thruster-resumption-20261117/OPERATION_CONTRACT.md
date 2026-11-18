# Fusion drive operating variation

The owner requested substantial sinusoidal plus/minus random variation in both
power draw and simulated fluid inputs for the long and short fusion drives, and
approved a 50–150% range around their current 12 MW nominal demand on 2026-11-17.

The ordinary `void-fusion-thruster` and `large-void-fusion-thruster` service uses
the same operating model, with a separate saved phase and noise seed per entity:

| Parameter | Current implementation |
|---|---|
| Nominal electric demand | 12 MW |
| Operating factor | `1 + 0.35*sin(phase) + noise`, bounded to 0.5–1.5 |
| Sine period | 480 game ticks, eight seconds at 60 UPS |
| Random component | ±0.15, independent per drive; new values every 60 ticks with smooth interpolation |
| Actual hidden-sink demand | 6–18 MW; `power_usage` receives watts divided by 60 |
| Native internal fluid charging | Both actual native stores receive the same 300–900 unit target, 600 nominal |
| Servicing cadence | Every ten game ticks through an explicit owner/route registration |
| Power gate | Native buffer must hold at least 250 kJ or one demand tick, whichever is greater |

The range is a bound; a short capture need not reach both exact extremes. Fluid
charging sets real native working-fluid inventories rather than varying only a
display value. It maintains the existing 1:1 charge/reaction-fluid policy and
15°C internal temperature. These are internal drive stores, not player-supplied
pipe inputs. No new visible port or wire connector is introduced.

The power sink retains the existing continuous-load policy while the drive is
registered. A disconnected network supplies no actual energy; stored buffer may
continue operation until it falls below the gate. The service does not refill
fluids after that point. Remaining internal fluid and platform momentum can
persist, so immediate zero speed is not the power-cut acceptance criterion.

Phase, seed and start tick live in `record.operation` in the normal persisted
fusion registry. Native sink replacement and registration repair preserve that
record. Noise is a private deterministic hash of the drive seed and game-tick
segment, so save/reload does not restart the waveform or consume other systems'
random stream. There is no loop over missed ticks after a long service gap.

The normal source also repairs the pre-existing zero-thrust causes: liquid
hydrogen/oxygen and both hidden fusion fluids now carry the native donor's
50 kJ fuel-energy value; fusion records wake the dormant gate on priest-free
platforms; an explicit fusion service route avoids replacement of its anonymous
legacy callback. The old 100-unit fusion charge sat at the native curve's 10%
boundary. Existing per-drive performance scales and Thetazine's fuel definition
remain unchanged.

The implementation is in
`tech-priests_src/scripts/core/void_fusion_operation.lua`, called by the actual
fusion service in generated control part 002. Final native evidence must measure
the real sink and real fluid stores, independent phases, significant variation,
unpowered refusal, recovery and matching uninterrupted/reloaded ticks. A
constant-fill diagnostic is historical evidence and cannot certify this feature.

## Owner-requested visual coupling

The owner subsequently required the whole engine to crackle with green energy
and its brightness pulses to track the electrical draw. This supersedes the
earlier source-only independent two-second brightness envelope. The existing
actual per-engine operating sample remains the authority; do not add a second
sine or independent random power model for the artwork.

The native visual implementation is added alongside the source effect capture.
Its normalized peak image is multiplied by `operation.factor / 1.5`, yielding
one-third peak intensity at 6 MW and full intensity at 18 MW. Factorio's tint is
premultiplied: apply the same level to RGB and alpha. A real unpowered state
suppresses the energy; the actual working/thrust/platform state additionally
gates the particle plume. Crackle and ejecta motion can remain cyclic, while
their overall intensity follows the current saved per-drive demand sample.

The actual 2.1.24 [native power-coupling evidence](animation-capture/native-power/README.md)
now passes render-object tint/visibility against the real sink demand, distinct
drive phases, power cut/recovery, sink replacement, cleanup and real save/reload.
It also proves normal servicing when optional animation assets are absent. These
tests use private animation stubs to exercise actual native render objects; the
new particle/arcing pixels and current detailed body fit retain their own source
and graphical-client acceptance gates. The earlier propulsion tests continue to
establish their original hash-bound state independently.

The final detailed source captures and actual high-quality graphical-client
reviews now pass for [narrow V11e](animation-capture/native-narrow-v11e/visual-fit-review.json)
and [wide V18g/V19e](animation-capture/native-wide-v18g/visual-fit-review.json).
The [final integration receipt](animation-capture/final-integration.json) verifies
both active local-source graphics blocks, all14 exact PNGs and the same tested
runtime helpers. Owner artistic acceptance and normal-profile release remain open.

The later universe-v01 visual-strength revision leaves these two runtime helper
hashes and the6–18MW demand envelope unchanged. Both final source sequences are
integrated after the user observed firing and directed proceeding; no additional
native rerun is implied. [Current integration scope](animation-capture/universe-v01-integration.json)
separates that observation, new source64 checks and the existing native control proof.
