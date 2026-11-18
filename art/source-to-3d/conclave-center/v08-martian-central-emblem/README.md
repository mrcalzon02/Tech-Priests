# Conclave Center V08 — central Martian emblem

**Owner accepted the V08 model on 2026-11-16.** Exact source/export hashes are bound in `owner-approval.json`.

The supplied DGordillo low-poly skull remains editable and unchanged beneath three fitted mechanical half-mask plates. A real two-tone 20-tooth cog surrounds the central skull; a recessed red optical lens sits in a flange whose rear edge follows actual source-surface raycasts. Surface-normal retaining bosses and a captured mandibular strut explain assembly. Both side skulls retain their aged ivory finish and original mesh/sculpt normal.

The skull-and-cog direction was checked against the [officially licensed Mars emblem reference](https://merch.warhammer.com/en-de/products/starforged-warhammer-40-000-chapter-icon-pin-badge-adeptus-mechanicus). New geometry was authored here; no reference image is distributed in the asset.

V06 construction is retained: 41 plausible service routes, 62 actual receiving sockets, inward-facing full consoles, panel/vent/buttress refinement and nine individually bracketed arch candles. Receiving planes, bores, insertion and axes were measured in the V06 source/export audits; static construction signatures were preserved in V07.

V07 ambient work is retained: nine independent flame-waver/flicker tracks, 27 faint rising smoke wisps, three slowly scrolling/flickering CRTs and actual source-rendered green keyboard spill. The loop lasts 12 seconds. GLB contains one synchronized geometry clip; independent reimport measures all 36 moving effects. Screen shader UV/emission and local lights are evaluated in the packed Blender source and baked into the native sprites; GLB shader-animation parity is **not** claimed.

## Review artifacts

- `conclave-center-v08.blend`: editable, packed master, frames 1–289 (289 matches 1).
- `conclave-center-v08.glb`: actual animated runtime-model export.
- `inspection/`: independently reimported four facings and clay view; see `inspection.json`.
- `independent-motion-audit.json`: source/export samples, movement, loop closure and numerical parity.
- `captures/`: four real body/shadow facings, inventory icon and 144-frame north atlas.
- `ambient-preview.gif`: actual source-rendered motion preview, 12 fps.
- `native-evidence/`: actual graphical-client motion and native container tests when populated.

## Gate boundaries

Native entity remains the same fixed-north 2×2 container, inventory 1, health 450 and existing crafting/governance behavior. Ambient art uses a static ghost-safe placement body, native `stateless_visualisation` ambient replacement frames and a separate additive light pass; no new player controls, external interfaces, alignment rules or runtime tick script ship. Native graphical proof is distinct from native functional tests and from owner approval. Automated observation of a GUI does not establish physical governance interaction. The actual native night view and placement ghost were viewed after repairing the first failed native pass; both are retained in `native-evidence/`.

Do not declare Conclave or the remaining structure queue complete from these sprites or a successful mod load. The next independent structure is Martian Stone Cache only after the Conclave's applicable gates are closed.

## Panel layout verification

The accepted model is integrated. The production governance panel now separates status from actions, sizes itself in GUI units to the viewport, wraps every table column and keeps scrolling vertical. The vote timer sprite is constrained to 32 GUI units. All five tabs were viewed at 922x599 and 1280x800, UI scale 0.75, with the physical opening event recorded. Current native container, recipe, four-sided ordinary inserters and saved-game reload pass. See `approved-integration-evidence/layout-validation.json`. Overview-button navigation and live-resize tab preservation were not separately exercised.
