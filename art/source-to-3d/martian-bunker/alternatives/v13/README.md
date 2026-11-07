# V13 selected corner chamfers

Adds broad flat chamfers along the two lower side corners of the main optical sensor box and both rear upright outer corners of the ammunition pillar. These are single-plane chamfers with a small secondary edge finish, retained as editable weighted-edge bevel modifiers. The rest of each housing keeps its existing shape.

Pillar side panel assemblies are narrowed slightly in depth to sit ahead of the new rear corner cuts. All other geometry, transforms and material assignments are checked against V12. Corrugated air hoses, cannon positions, conveyors, hatches, hoppers, inset front plates, sensors and antennas are retained.

Run build_corner_chamfers.py in Blender 5.0.1, then make_review.py with Pillow. Includes native Blender, evaluated GLB and four actual Blender renders, including dedicated sensor and rear cabinet close-ups. GLB reimport and preservation checks must pass before packaging.
