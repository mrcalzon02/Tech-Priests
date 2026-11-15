# Ordinary hydrogen-chain integration checkpoint

The seven accepted machine sources now have a composed addon candidate under `build/model-completion/metallic-hydrogen-chain/production-addon-v07-clean`. This is not installed into the real mod or accepted as a finished player-facing release.

Actual native runs supply only water, steel plates and electricity to a connected seven-machine line. Real pipes and inserters produce six collected contained pellets; formation and sealing retain health, quality, decay phase and remaining lifetime. All machines stop advancing during the measured electricity interruption. Complete histories match after an actual tick-3500 save/reload. A separate critical-pellet probe expires natively in a chest and then travels through actual forge/assembler inserters as inert material, without consuming a shell or reviving the contents.

These runs pass both standalone and alongside Tech Priests/Space Age. The published-main snapshot is pinned in `build/hc-main-published/SOURCE.json`; latest complete behavior evidence is in `build/hc-final-published-01` and `build/hc-final-published-02-reload`. Production code includes no world creation/clearing or fixture stock. Native URI checks now catch missing graphics files that headless Factorio does not load. Early namespace and Windows long-path graphical studies are retained privately.

The candidate uses real electric sources, research-gated machine construction recipes and existing original machinery audio. The compressor retains its 1.15 gain, widest reach and priority 16. Resource icons are exact copied own-project renders, with origin hashes. Initial power, construction cost and science values are tuning candidates, not final balance approval.

## Demonstrated remaining work

- **Purifier native rotations:** the original fixed-north prototype had not established rotated pipe seating. The first normal-addon views expose a short front mouth and a rear pipe drawing over the bowl. The accepted V16 body and camera remain locked. `purifier_native_fittings.py` moves each original ten-mesh mouth rigidly and adds two real constant-bore sleeves to compensate native foreshortening; the capture derivative and new object-layer placement require native review. Staging captures are `purifier-native-fitting-captures-02`. No whole-body stretch or bitmap pipe patch is allowed.
- **Purifier clock:** six machine clocks pass private native counter decoding. The purifier counter repeats one boundary cell late in the sampled run. Preserve `build/hc-clock-02/clock-readback.json` as failed evidence; distinguish boundary sampling from actual drift with an offset probe before asserting a pass. Do not relax the period gate.
- **Player controls:** the forge/assembler retain private clock/intake/presentation recipes internally. A normal player interface must hide those implementation details while allowing real input/output interactions without healing, quality gain or timer reset. This is not yet complete.
- **Final balance and presentation:** complete the normal player/research flow and final energy/recipe tuning; retain the known limitation that native graphics and sound have per-entity phase offsets rather than proven process synchronization.

The reactor V14 ZIP/reference recovery, three reactor refinements and remaining sprite-only buildings remain in the original active goal. The linked Library currently requires sign-in in the available browser; a local path was requested once. Continue independent integration work while that source is unresolved, without substituting a new supposedly preserved ring.

## Resume reconciliation — 2026-11-15

The owner requested reconciliation and continuation of the existing goal. Preserve the fabricator's exposed welded sheets, edge clamps and open frame. The seven saved machine sources are not seven finished ordinary-game integrations; player controls, tuning, native review and the reactor/building follow-on remain open.

The purifier fitting adapter was moving hidden historical collar/throat meshes while leaving their rendered UV-surfaced replacements behind. The bolts moved without their visible supports. The corrected adapter explicitly selects the two visible surfaced fittings and eight original bolts per mouth and rejects hidden components. `build/purifier-native-fitting-readback-05.json` passes all four rigid world-transform checks, unchanged accepted mesh/body/camera checks and 72 bounded bore rays. The four-angle `purifier-native-fitting-pilot-05` was rendered, reopened and visually inspected; bolts now seat on the actual flanges. Full 36-frame captures are in progress under `purifier-native-fitting-captures-03`; actual game pipe seating remains a separate gate. Failed earlier capture studies are retained and must not be promoted.

The ordinary addon builder now requires a complete fitted purifier capture, checks its source/camera, frame hashes and capture/reopen gates, and records the actual derivative capture manifest instead of the old accepted-source manifest. This prevents silent fallback to the known unfitted rotations. Native fitting review is still required before delivery.
