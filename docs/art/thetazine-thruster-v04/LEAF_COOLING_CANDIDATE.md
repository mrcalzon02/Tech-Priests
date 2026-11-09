# Thetazine V04 leaf-cooling construction candidate

Editable source and actual physical GLB are preserved here as a **review candidate**, not final runtime art. Ordinary gameplay still uses V03. No behavior tests, gameplay/prototype changes or workflow edits are part of this slice.

Twelve articulated exterior plates each carry a four-pass serpentine coolant tube, twelve seated saddles and separate flexible inlet/outlet roots. The two coolant lanes remain separate; the large cold bulk tank injection stays parallel to regenerative pre-injection. External platform frame/interfaces stay rigid while the chamber and its fitted machinery move inside it. Plate centers remain dark with restrained edge fringing.

Current source: `art/source-to-3d/space-platform-engines/thetazine-thruster/v04-regenerative-study/`. Open the packed `.blend` in local Blender5.0.1; physical `.glb` is independently reimported. Render-only combustion volume stays in Blender and must be baked into separate heat/light sprites. Source is fixed north; external attachment positions are unchanged.

The current32 export fixes stale base mesh buffers in two edited flex hoses. Actual oriented triangles, UV/material/socket correspondence pass for3022parts/533304triangles; all animation bounds pass. Exact evaluated geometry/transforms at66poses match31, whose all-pose route measurements are retained with original hashes. **Clearance is not accepted:** no actual crossing violations were recorded, but fourteen poses retain unresolved containment classifications near an inner overlap seal. Failed receipts are deliberately included. Do not reinterpret zero crossing count as a pass.

`previews/source-pilot31-bell-cooling.png` is a source render of31, geometrically identical32 across66poses. Seven `export-*.png` images are current32 actual-GLB reimports; no combustion FX in those physical inspection views. These are proof of work, not owner approval. Historical20 safety checkpoint remains historical.

Next: resolve the seal containment question, review current cooling/heat/motion appearance, then capture current body/light states and verify atlas/registration/native animation clocks. Independently isolate baked flame, native jet and smoke to fix the contrail boundary. No final runtime promotion until these gates pass. The complete goal and issue13 remain open.

Authored repair/audit scripts are under `tools/art/thetazine_v04/`. They retain input SHA provenance; historical intermediate inputs22/28/29/31 remain in the local work directory. The committed current packed source is independently editable and does not require rebuilding those historical inputs to inspect or continue it.
