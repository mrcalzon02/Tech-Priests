# FMPL Process Machinery Construction Standard — V1

Machine identity is determined by visible materials processing. At ordinary Factorio camera scale, a reviewer should identify raw input, real transport/pump or feeder, filtration/treatment and the separate finished output without relying on signs or decorative arrows.

## Foundation first, equipment second

The oldest layer is an installed structural concrete footing or equipment plinth. Use only already-committed FMPL PBR families ferrocrete, ferrocrete_light and ferrocrete_dark (albedo, ORM, normal). Place iron/steel supports, bolted mounting shoes, pump brackets and pressure pipe supports on top of it with actual contact.

Where service paving is appropriate, build an actual staggered brick apron with discrete geometry using those existing concrete PBR materials. A distinct approved paving-brick bitmap was NOT confirmed in the indexed library; do not claim such a preset until its original file and material are identified and hash-verified.

## Visible process and service logic

Separate raw/fluid inlet from product outlet. Trace continuous, physically supported pipe routes through real pump and serviceable filter housings to a working treatment unit. Use sight glass and different material appearance to show incoming contaminated fluid versus clean discharge. Do not fabricate additional native prototype ports.

For Water Purifier the existing Blender raw mouth is at (-1.5,-0.78,0.36), clean mouth at (1.5,-0.62,0.36), inside a 3x3 pad. Hide the historical opaque tank and overlapping filters in the derivative instead of deleting originals. Build a true open-walled treatment chamber under a transparent glass observation lid, with supported geared agitator shaft and turning paddles. Key working and idle positions, visible fluid churn markers, and short steam at a real relief nozzle.

## Required evidence

Preserve original named mesh geometry and SHA-256. Save a new editable native .blend with PBR maps packed and actual animation keys, a clean GLB that excludes reference/measurement fixtures, independently reopen and reimport both files, render genuine idle and active screenshots, then capture four fixed-camera 64/128/256px static direction sprites and check alpha/cell order. Animated atlas integration is a separate gate.

Never equate a Blender pipe-mouth plane with the native Factorio pipe connection cell. Only the actual target prototype and real game placement can approve port alignments, gameplay and the visual machine. Keep the single self-hosted runner; no workflow matrix, destructive source edits or output-overwriting reruns.
