# FMPL Process Machinery Construction Standard — V1

Machine identity is determined by visible materials processing. At ordinary Factorio camera scale, a reviewer should identify raw input, real transport/pump or feeder, filtration/treatment and the separate finished output without relying on signs or decorative arrows.

## Foundation first, equipment second

The oldest layer is an installed structural concrete footing or equipment plinth. Use only already-committed FMPL PBR families ferrocrete, ferrocrete_light and ferrocrete_dark (albedo, ORM, normal). Place iron/steel supports, bolted mounting shoes, pump brackets and pressure pipe supports on top of it with actual contact.

Where service paving is appropriate, build an actual staggered brick apron with discrete geometry using those existing concrete PBR materials. A distinct approved paving-brick bitmap was NOT confirmed in the indexed library; do not claim such a preset until its original file and material are identified and hash-verified.

## Visible process and service logic

Separate raw/fluid inlet from product outlet. Trace continuous, physically supported pipe routes through real pump and serviceable filter housings to a working treatment unit. Use sight glass and different material appearance to show incoming contaminated fluid versus clean discharge. Do not fabricate additional native prototype ports.

For Water Purifier the centered provisional Blender raw mouth is at (-1.5,0,0.36) facing WEST, and clean mouth at (1.5,0,0.36) facing EAST, inside a 3x3 pad. Its native fluidbox prototype is **not yet declared**, so these must be mapped and checked against the actual prototype before game integration. Hide the historical opaque tank and overlapping filters in the derivative instead of deleting originals. Build a true open-walled treatment chamber under a transparent glass observation lid, with supported geared agitator shaft and turning paddles. Key working and idle positions, visible fluid churn markers, and short steam at a real relief nozzle.

## Required evidence

Preserve original named mesh geometry and SHA-256. Save a new editable native .blend with PBR maps packed and actual animation keys, a clean GLB that excludes reference/measurement fixtures, independently reopen and reimport both files, render genuine idle and active screenshots, then capture **one canonical fixed-camera** 64/128/256px static direction for this nonrotating machine; the export should not rotate the whole structure. Four cardinal captures are only for prototypes that actually rotate, and must be individually authored and justified. Animated atlas integration is a separate gate.

Never equate a Blender pipe-mouth plane with the native Factorio pipe connection cell. Only the actual target prototype and real game placement can approve port alignments, gameplay and the visual machine. Keep the single self-hosted runner; no workflow matrix, destructive source edits or output-overwriting reruns.

## Corrected machine camera and standard physical pipe hardware

The canonical camera comes from the verified emergency boiler V08 production: **45-degree elevation, zero azimuth, orthographic**, with the entire machine aligned to the Factorio X/Y world grid. There is one authored camera and one production direction for Water Purifier. Never substitute a diagonal item-icon inspection camera or rotate the entire fixed machine through N/E/S/W to fake additional states.

Each Water Purifier model-space boundary uses the existing reusable `factorio-fluid-interface-v1` geometry: 0.57 tile OD pipe barrel, 0.49 tile open bore, 0.68 tile OD full-size mounting collar, axial 0.075 tile collar, and centre Z0.36. Copy the **actual machine_collar and machine_throat meshes** as machine geometry and leave the adjacent reference barrel hidden from export. Complete the connection with a cast hollow reducer into the pump or processing vessel, supported shoe, and physically seated bolt pattern. Reject brass-ring-only outlets and arbitrary Y-offset mouths. The exterior mating annulus must coincide with the adjacent reference collar to within 1e-5 tile; this does not by itself prove native Factorio pipe-cell connectivity.

## V11: Open side bores and distinctive fluid samples

No structural mesh may cross the internal passage of a side fluid connection, even when the 0.49-tile-ID canonical annular throat/collar looks correct. Check chassis rails, concrete foundations, raised plinths, pipe-footing shoes and braces. The original 0.49-ID/0.68-OD full-size flange, 8 real bolts, cardinal centerline and one fixed Factorio camera remain immutable.

When an old source component intrudes into the bore, retain its exact original mesh/transform as a render-hidden source and construct a new visible supported derivative. Split rails around the bore, relocate braced load-bearing feet outside the tube cavity, and cut circular passages through copies of source concrete mesh using real Blender booleans. Never delete the historical source, replace the pipe with a closed brass cap, fabricate native fluidbox ports, or hide the entire foundation without a physically supported replacement.

Pass only after independent real Blender/GLB ray intersection tests find **zero visible mesh hits** across both connection bores at multiple inner-core offsets. An annulus's reported diameter alone is insufficient. Native Factorio pipe-cell alignment remains a separate unverified gate until actual game placement.

Water Purifier front witness tanks must be physically enlarged (V11: 0.426 tile OD, 0.712 tile height), with clearly contrasting warm olive-amber raw water and brighter cyan-blue finished water. Propagate source-safe FMPL derivative colors to the liquid body, real glass witness flow, bubble tracers, meniscus and crest, preserving the canonical FMPL material assets. Actual 45° Cycles screenshots decide whether they read distinctly at game scale.
