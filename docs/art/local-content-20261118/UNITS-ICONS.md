# Synced local character, armory and factory content

The 44 indexed local-only records are integrated in this overlay: 15 character
skins, 25 weapon/ammunition icons and four material/factory icons. There are zero
skipped or unbound icon targets. See `units-icons-disposition.json` for every
record, exact runtime hashes and evidence scope.

Character appearance keeps existing native worker identities and behavioral
owners. A native player picker and inventory-preserving host transfer provide
the 15 models; five priest ranks map to the existing skin catalog. Startup skin
permissions and the disabled-picker option retain the implemented behavior.
Original Gladius attribution and rights notices remain with all donor sheets.

The 29 icon targets did not exist on the base main. Their existing local
dependencies are now explicit: three independent authored faction factories,
their original recipes/research, and the original weapon/ammo/supply armory
definitions. The armory preserves local balance, recipes and firing effects.
It does not activate combat cars or add new weapon behavior. A native data-dump
comparison against the unchanged original roster found zero differences across
99 shared armory/factory/research prototypes after excluding actor-only unlocks.

The complete original actor/AAI slice and separately tested finished arsenal
are retained under `wip/combat-roster-local`. Their registration, AAI adapters,
actor production, reinforcement, muster GUI and orders remain unenabled.
Mapping the finished weapon definitions onto actual AAI actors remains pending.
The Ranger/Officer/Commissar donor equipment adjustments are also pending.

Fresh full-source Factorio 2.1.24 evidence covers the default player picker,
15 skins, five ranks, two forces, native player state preservation, screenshot
rendering, autosave and independent-process reload. Restricted and disabled
cases passed fresh full-source native headless tests. Factories passed native
research, 12 directional placements, power, physical item/fluid accounting,
active smoke/glow capture and independent-process reload. Owner visual acceptance
and multiplayer remain separate. Evidence records its exact source scope.

Reproduce with `tools/run_character_skin_native.py --full --output-root <short-path>`
and its `--case restricted|disabled --headless-only` cases;
`tools/run_faction_factories_native.py --output-root <short-path>`; and
`tools/run_armory_equivalence_native.py --output-root <short-path>`.
Short output paths avoid the engine's Windows graphical sprite-loader limit.

Selected editable current icon/factory sources, actual exports, textures,
attribution and QA are retained. Superseded art poses, raw Gladius source models,
private comparison panels, build caches and redundant review scenes are omitted.
