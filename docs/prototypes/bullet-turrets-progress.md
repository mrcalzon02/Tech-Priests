# Bullet turret prototypes — complete

Both original weapons are working in the isolated Bunker Family Prototypes
0.3.0 add-on. Final masters and actual GLB inspections are in
`build/bullet-turrets/candidate-v5/`; final captures are in `captures-v5/`.
The owner accepted the latest in-game result: “yerp its good”.

The piano has four lower side-entry belt feeds and fires four staggered
shots followed by the agreed half-second recycle. The twin has two rotary
guns at stock cadence with twice the ammunition use and damage. Each rotary
gun now flashes from one fixed muzzle point. Inherited native muzzle
effects are suppressed only for these two mounts. Both caps traverse above
their stationary bunker foundations and remain visible in native previews.

The hashed completion audit is `bullet-turrets-completion.json`. It covers
actual exported geometry, exact sprite-cell readback, all 64 native facing
mappings, 24 combat sites, research upgrades, physical inserter supply,
actual graphical firing and native previews, save/reload into a fresh
process, and regression of the older bunker family. Six actual game firing
captures confirm both fixed minigun flash positions. The twin FX repair
proves all body poses unchanged before reusing body and shadow images;
every twin muzzle-effect frame was rendered again.

Local delivery: `build/bullet-turrets/delivery-0.3.0/` contains the playable
`tech-priests-bunker-family-prototype_0.3.0.zip` and
`bullet-turrets-editable-sources.zip`. The archive matches current source
and packed graphics and contains no combat fixture controls or scenarios.
The protected full-mod release and unrelated concurrent work were preserved.

Balance and recipes remain provisional. Fractional speed research quantizes
the piano recycle to 29–31 ticks, averaging 30. Twin volleys use one doubled
native impact, so flat armor applies once. These limits are documented in
the included README. This is a local prototype delivery, not a published
full-mod release.

## Historical working notes — superseded by the completed audit above

The owner accepted candidate-v3's mechanical direction on 2026-11-14,
with one correction: the Chicago piano needs belt tracks rising from below
and entering the side of each gun, replacing the sloping rear bullet ramps.

Candidate-v4 implements that correction in
`tools/art/build_bullet_turrets.py`: four lower ammunition trunks, curved
segmented tracks, linked cartridges parallel to the bores, and left-side
feed throats opposite the right-side ejectors. The feeds traverse with the
cap; no bunker geometry is part of either animated model.

Editable models, GLBs, front/rear/quarter renders and independent reimport
inspection are in `build/bullet-turrets/candidate-v4/`. Both exports passed
the independent geometry/UV/bounds checks. The piano has 64,652 triangles,
335 meshes with UVs and zero degenerate triangles. Front, rear and quarter
source renders were visually reviewed. Candidate-v4 has not yet received
specific owner acceptance.

Full 64-direction captures are running into
`build/bullet-turrets/captures-v4/`, with logs
`build/bullet-capture-piano-v4.log` and
`build/bullet-capture-twin-v4.log`. They must finish with COMPLETE metadata
before packing. Earlier captures-v3 contain rejected candidate-v2 geometry
and must not be promoted. Current small icons still use that old geometry;
regenerate them from captures-v4 after the full capture completes.

Remaining: pack real sprites and native preview cores; regenerate icons;
run native combat tests with real graphics; inspect firing and previews
graphically; package the isolated 0.3.0 prototype add-on. The existing
behavior-first tests passed with placeholder graphics and establish no
visual acceptance. Keep the full-mod baseline and unrelated concurrent
work untouched.

Gameplay contract: Chicago piano fires four rounds six ticks apart, then
recycles for 30 ticks; twin minigun follows stock cadence at twice the ammo
and twice the damage. Speed research introduces native fractional cooldown
quantization: piano recycle gaps are 29–31 ticks, averaging 30. Twin damage
currently uses one doubled native impact, so armor is applied once rather
than independently to two bullets. Both limitations require honest release
notes. Ordinary bullet magazines and vanilla damage/speed research work
in the isolated behavior fixture.

Follow-up checks: `behavior-continued` now passes all 24 sites through tick
3350, including fresh resupply and continued firing. This is still placeholder
graphics and is NOT a save/reload claim: benchmark mode ignores auto-save.
The graphical fixture requests an autosave at tick 3000; once a real save
exists, the runner's `--reload-save PATH --scenario bullet-turrets` option
requires a fresh continued-firing log message after loading in a new process.

Native underlay `apply_projection=false` now uses the same uniform direction
index as the script and prevents a differently facing native core from
showing through. Actual aiming at diagonal targets still needs visual review:
the source camera is precisely 45 degrees, while entity.orientation is in
map space. A disposable 64-heading marker probe was implemented in
`tools/run_bullet_projection_probe.py`; its first graphical run exited with
`user-quit` before producing screenshots, so it establishes no mapping.
Do not repeatedly relaunch this probe. Check the complete turret fixture
with real graphics first and correct projection consistently if necessary.

The packing tool's manifest-name shadowing bug was fixed. Production builder
now requires the packed bullet manifest, describes all five weapons, verifies
the exact shipping controller and rejects stale fixture scenario directories.
The preview-only runner now opens the correct bullet turret when requested.
Independent clay renders now have an actual gray Principled material and
were reviewed after the export reimport; the previous white clay lighting
was too bright to assess details.
