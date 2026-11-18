# Native per-engine visual power coupling

`validation.json` reports `PASS_NATIVE_REAL_VISUAL_POWER_RGBA_LIFECYCLE_AND_SAVE_RELOAD`
in the actual installed Factorio 2.1.24 runtime. It binds the current modified
fusion service and new `scripts/core/void_fusion_visuals.lua` to exact hashes.
Ordinary registered narrow and wide drives draw real electrical power, consume
their real internal fluid proxies and drive real native LuaRenderObject
animations. This is a runtime/control proof using private animation stubs,
independent of the current artistic particle/arcing sprite capture.

For each drive, the observer records 165 service samples. Native RGBA tracks the
same actual operating factor divided by 1.5, with maximum float32 readback error
`2.9741e-8`. The sampled operation watts and actual sink `power_usage * 60` agree
within `1.863e-9` watts. Both saved independent phases are exercised. The code does
not introduce a second brightness sine or duplicate random-power model.

Power cut hides the energy and plume, restoration recovers them, and a powered
paused platform retains energy while suppressing the plume. Sink repair retains
valid visual object identities. A real loopback-server autosave and separate
reload retain visual IDs/state; removed entities, sinks and owned render objects
are cleaned up. Native status changes between ten-tick service samples are
recorded explicitly rather than mistaken for same-tick state failures.

`optional-assets-absent.json` proves normal electric/fluid servicing and platform
movement also continue when the optional animation prototypes are absent, with
zero visual objects. This allows the source runtime repair to remain useful while
the authored graphics await their separate source/capture/native fitting gates.

Reproduction tools are in `tools/art/thruster_resumption/visuals_native/`.
The complete disposable profiles, logs and real save remain under the parent
workspace's `local-validation/thruster-visual-power-native-20261117` and
`thruster-visual-no-assets-native-20261117`. Both private servers were stopped by
their runner. No ordinary game profile, normal save, installation or release was
modified. This proof does not establish final particle appearance or sprite fit.
