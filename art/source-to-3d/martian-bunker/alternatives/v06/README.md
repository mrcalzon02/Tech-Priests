# V06 central ammunition arm

Enlarged central fin and continuous armoured rear spine. Three paired outlet castings connect that spine to the six existing cradle backs. The bottom casting connects visually to the central arm and turret mount. V05 cannon, pneumatic and cradle meshes and transforms are preserved and checked before export. The external guides and staged grenades are raised to the new open hopper lips; opaque loading hoods are replaced by hollow tapered hoppers.

The housing implies a concealed fictional distribution mechanism for this game asset; hidden functional weapon internals and fuze operation are not constructed. Exterior housing, service cover, braces, bolt heads and feed port shadows provide the visible model detail.

Animation staging: approve static geometry first; test a single intact grenade prop on one station next; animate its visible route from the arm outlet through the open guide and hopper, concealing the prop inside opaque housings; review spoon/ring clearance from the game camera; then instance the approved motion to the other five stations. Named RELOAD_PATH markers are planning handles only. No reload animation or hidden operating mechanism is authored in this revision.

Run build_central_feed.py in Blender 5.0.1 from the repository root, then run make_review.py using Python with Pillow. Native .blend, GLB, four actual Blender renders and review board are included. GLB reimport and preservation checks must pass before packaging. Bunker base is untouched.
