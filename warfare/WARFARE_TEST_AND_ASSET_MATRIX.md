# Warfare — assets, test matrix, phased exit criteria and implementation hold

**Branch:** `feature/warfare-module-planning`. **State:** PLANNING ONLY. No code, entities, sprites, models, research, crafting recipes, AAI patches or custom CI jobs have been created by this plan.
**Reference evidence:** native Factorio 2.1.24 [run #42151378921](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921) and [Control interface audit](CONTROL_INTERFACE_AUDIT.md). The existing 123,000-tick smoke does not exercise these future warfare assertions.

## A. Asset registry — actual now versus proposed later

| ID | Asset | Current status | Planned Warfare role | Control authority | New game content required? |
| --- | --- | --- | --- | --- | --- |
| `vanilla/gun-turret` | Native Factorio ammo turret | **Exists** | Perimeter line, local emergency response, initial remote *target designation feasibility* | Factorio turret targeting; existing Tech-Priests defense and ammo owner | No |
| `vanilla/laser-turret` | Native Factorio energy turret | **Exists** | Sustained powered defense, redundant coverage | Factorio turret targeting and native power network | No |
| `vanilla/flamethrower-turret` | Native Factorio fluid turret | **Exists** | Area-denial defensive line | Factorio fluid turret and verified fluid network | No |
| `vanilla/artillery-turret` | Native Factorio long-range artillery | **Exists** | Later siege/counter-battery doctrine, not early remote gun | Native artillery remote/targeting; existing artillery owners | No |
| `vanilla/car` / `vanilla/tank` | Native Factorio vehicle | **Exists** | Scout, escort, fire support, prototype for human/AAI command comparison | Native car player controls / AAI's AI conversion | No |
| `vanilla/spidertron` | Space Age/base vehicle, installed in unified pack | **Exists** | Future recon/escort and existing remote waypoint contrast | Native SpiderVehicle command and player remote where available | No |
| `warfare/skitarii-infantry` | **Does not exist**; Mechanicus Reborn **engineer retexture provisionally designated as temporary visual stand-in** (installed-mod dependency, no new sprite copied) | Future core infantry, guard, field patrol, direct observation/teleoperation | Proposed Warfare unit arbiter; native `UnitPrototype` movement/attack if validated | **Yes — future new entity, item, proper original Skitarii 3D model/rig/animations/directional sprites, recipes and actual behavior** |
| `warfare/network-defense-cannon` | **Does not exist** | Future hardened, remotely designated static defense cannon | Proposed Warfare turret/command-network arbiter; native turret/AmmoType | **Yes — new turret, ammunition/feed requirements, sensing and control node** |
| `warfare/bunker` | **Does not exist** as a released original Tech-Priests entity | Heavy armored housing/functional facility, mount for a remote cannon | Native structure, possibly a linked gun; only after prototyping | **Yes — original armor/structure entity and render** |
| `kj/baneblade` | Installed `kj_40kbaneblade` 2.1.0 | **Exists** | Heavy assault and area control (doctrinal *intention*, not proven benchmark) | Native car or AAI single-weapon AI derivative | No |
| `kj/predator` | Installed `kj_40kpredator` 2.1.0 | **Exists** | Mobile fire support | Native car or AAI variant | No |
| `kj/leman-russ` | Installed `kj_40klemanruss` 2.1.0 | **Exists** | Armored breakthrough | Native car or AAI variant | No |
| `kj/dreadnought` | Installed `kj_40kdreadnought` 2.1.0 | **Exists** | Armored line escort/fire support | Native car or AAI variant | No |
| `tanks-for-bob/vehicles` | Installed `tanks_for_bob_fork` 1.8.95 (disposable 2.1 metadata probe) | **Mod and prototypes load** | Broader native offensive options | Native vehicle and AAI variants as supported | No for existing; may need actual 2.1 release before shipping |
| `warfare/anti-air` | **No original asset approved/built** | Future AA/point-defense if native targets exist | Native turret/protected target model with real sensor input | Conditional; not W0–W3 |
| `warfare/network-command-bastion` | **No original asset approved/built** | Later communications/power/network relay | Native electric/circuit network authority | Conditional |

### Asset identification rule

This is a **design registry**, not a manifest of `data.raw` prototypes. IDs beginning with `warfare/` are **planning labels only**, not files, Factorio internal prototype IDs or promises of publicly licensed art. For 40K vehicles, actual car/entity/item/AI derivative identifiers must be observed from Factorio; don't infer from Mod Portal ID or weapon name. All original models follow [construction doctrine](../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md): visible geometry only, readable at game camera, believable ferrocrete mounts, functional sensors and proper turret clearance.

## B. Control capability and ownership matrix

| Asset type | Native movement | Native attack | Observation | Remote tactical order | Direct teleoperation | Key unknown |
| --- | --- | --- | --- | --- | --- | --- |
| Vanilla ammo/laser/flame turret | Static | Automatic native turret | Live ammo, power/fluid, target, health | Target-priority filters and turret target designation where supported | **Not yet proven**; entity-target-only `shooting_target`, no `nil` clear | Target-release, operator veto, friendly fire |
| Vanilla car/tank | `riding_state` / human driver | Native selected gun | Driver, fuel, cargo, guns | AAI may convert to commandable AI variant | **Unproven**; player camera is not driving | Controller handoff without destroying AI state |
| AAI-derived AI tank | AAI/biter-type unit AI | One gun per generated variant | Native entity and supported AAI telemetry | AAI remote / waypoints / zones | **Unproven**, no assumed car driver | Whether AAI exposes a safe external control bridge |
| Native SpiderVehicle | Native spider behavior and built-in remote path features | Native spider weapon configuration | Vehicle/grids/gun prototype | Native waypoint/remote | **Unproven direct shooting**, not equivalent to remote waypoint | Multiple launchers versus valid AI gun count |
| Future Skitarii | Planned native `unit` `LuaCommandable` | Planned native `attack_parameters`, possibly validated owned turret proxy | Explicit player remote view and read-only status | Planned guard/move/attack order | **New game feature**, no prototype yet | Input arbitration and possession mechanism |
| Future network cannon | Static | Planned native ammo/energy turret | Real circuit/power/vision telemetry | Planned sensor/target designation | **New game feature**, no prototype yet | Safe target clear, control-link proof, manual aim legality |
| Existing Tech-Priest worker | Existing own movement controller | Existing hidden ammo-turret proxy | Existing internal status | Existing hierarchy / orders | **Out of Warfare scope** | Do not take control of autonomous factory labor |

### Human-controllable modes (future UX spec)

- **Watch**: select a source/target, camera centers on current surface; no control lease; can release with one action.
- **Order**: click asset, click map/enemy, queue one native-supported action; observe accepted/rejected state; action persists only as the owning system allows.
- **Operate**: take an explicit, exclusive and time-bounded control lease; controls vary by asset. Skitarii should feel like directly commanding a soldier, bunker like directly operating a fixed gun. **Direct teleoperation does not yet exist.**
- **Release**: always available, including player disconnect/death, GUI close, surface change, device destruction and power loss; safe fallback to prior owner or hold if restore impossible.
- **Status HUD**: current mode, controlled entity, weapon slot/mode, ammo/energy, health, true link coverage, target, cooldown, current operator, error reason. Compact mobile/touch-friendly design later.

## C. Source/prototype inspection acceptance, before any implementation

Every future experiment must record **actual** engine 2.1.24 observations:

| Check ID | Required observation | PASS condition |
| --- | --- | --- |
| `WAR-CAP-001` | Baseline vanilla gun/laser/flame/artillery entity prototypes & actual fuel/energy/circuit fields | Supported entity types and normal firing/targeting semantics recorded |
| `WAR-CAP-002` | Each KJ source car and AAI derivative, item/recipe/tech IDs | Same-force actual IDs and complete accepted modes; no guessing from Mod Portal ID |
| `WAR-CAP-003` | Source car `indexed_guns` and selected slot versus AAI one-weapon configurations | Full gun->AI mapping; a 2-gun source is *not* misreported as 2 simultaneous AI guns |
| `WAR-CAP-004` | Live `remote.interfaces` for AAI **0.9.2** | Only discovered methods and their verified signatures may be considered; missing = unsupported |
| `WAR-CAP-005` | `unit.commandable` versus ordinary `car.commandable` | Explicit true/nil readback; no illegal method invocation |
| `WAR-CAP-006` | `LuaEntity.shooting_target` and target reset on native turrets | Recognize documented `nil`-clear limitation; safe release design demonstrated before writing teleop |
| `WAR-CAP-007` | Native player remote camera and actual button/key event compatibility | Watch succeeds; steer/shoot not falsely inferred from camera |
| `WAR-CAP-008` | Native red/green circuit connector/networks and electric grid IDs | Emplacement remote control permitted only by physically connected and energized local control infrastructure |
| `WAR-CAP-009` | Existing Tech-Priest proxy-target and defensive scheduler ownership | A separate Warfare unit can't steal `proxy_turret_alignment`, `single_dispatcher` or event registry |
| `WAR-CAP-010` | KJ `Turret not found` nonfatal warnings in shared module | Identify cause and test actual weapons; no assumption that loaded means operational |

**Planning-only branch:** the above are **future test case specifications**, not currently executed acceptance checks. There must be no false PASS claim for any `WAR-CAP` identifier.

## D. Future functional test matrix — one native isolated test environment

| ID | Scenario | Native signals proving PASS | Explicit negative/failure case |
| --- | --- | --- | --- |
| `WAR-FUNC-001` | Gun/laser/flame defense reacts to a real enemy and spends its supply | Native damage/projectiles, ammo/energy/fluid delta, actual target | Friendly/protected target never auto-engaged incorrectly |
| `WAR-FUNC-002` | Vanilla turret is remotely designated a **live enemy entity** | Supported targeting request acknowledged, turret turns/fires and consumes stock | Invalid/expired/foreign target is rejected; releasing lease restores AI targeting without stale lock |
| `WAR-FUNC-003` | Skitarii moves via legal unit command to guarded position | Actual unit moves through obstacles, retains force, takes native damage | Failed path doesn't delete unit; obstruction does not teleport it |
| `WAR-FUNC-004` | Player observes Skitarii and takes exclusive teleop control | Camera and input both work; unit movement/damage/fire evidenced; safe operator return | Simultaneous second operator denied; close/disconnect/death safe |
| `WAR-FUNC-005` | Powered network bunker/cannon targets designated enemy | Real circuit/link + power + ammo, native target and fire, clear link/readiness telemetry | Unwired or unpowered cannon cannot be remotely driven; fallback consistent |
| `WAR-FUNC-006` | Remote cannon releases and switches back to autonomous defense | Engine target and control state read back; no lingering forced target | `shooting_target=nil` cannot be used as a fake reset success |
| `WAR-FUNC-007` | Native AAI waypoint/stop/resume on vanilla tank and one KJ variant | Actual travel progress, stop and resume, saved order/position/readback | Unsupported external remote API is not guessed and no teleport permitted |
| `WAR-FUNC-008` | Same vehicle under human/AAI takeover and release | No duplicate driving command writer; expected AI mode continues or clear hold | Lost inventory/cargo/equipment/quality or self-collision => FAIL |
| `WAR-FUNC-009` | Four KJ cars + one vanilla tank under valid offensive mission | Weapon-specific native fire, real fuel and ammo consumption, retained car identity | Do not count a zero-prototype smoke test as this |
| `WAR-FUNC-010` | Rapid target deaths/destruction/missing controller | Claims canceled, no script exception, no ghost target or orphan proxy | Nil target/invalid entity, own-force damage, or persistent lease |
| `WAR-FUNC-011` | 2 human players contest single cannon/Skitarii | One deterministic controller lease, visible denial/release, multiplayer replay determinism | Double controlling same entity or bypassing force/security |
| `WAR-FUNC-012` | Save/reload with live teleoperation and native AAI orders | Safe reclamation/release and stable asset registry, no duplicate entity/proxy | A loaded save restoring stale invalid commands must be blocked |
| `WAR-FUNC-013` | 1/10/50/200 active combat units over bounded native 123k run | No unbounded scans, measured UPS/CPU, accurate ammo/fuel counts and no fatal errors | Full-map tick scan or frame-to-frame teleport accepted as regression |
| `WAR-FUNC-014` | Destroyed network node mid-bunker firing | Immediate lease invalidation and safe no-fire/autonomous fallback | Remote ghost commands continue without real wire/power |
| `WAR-FUNC-015` | Multi-gun source car converted into one-gun AAI variant | Exact chosen gun recognized; remaining ammo/cargo/equipment handled per documented native transformation | Accidental assumption that 2 guns fire at once |
| `WAR-FUNC-016` | Later alternate independent secondary-weapon design | No duplicate damage, native ammo, ballistic/energy restriction, restored identity after reload | Composition that fakes hits/free reloads cannot be accepted |

**No automatic implementation of these cases now.** They are future experiment definitions to be executed only after an explicit Warfare implementation request.

## E. Branch and milestone gates

| Milestone | Required work | Exit criterion | Current |
| --- | --- | --- | --- |
| **M0 — isolated planning** | Branch created, technical evidence checked, architecture, asset roster, test matrix and tracking issue recorded | Readback of branch-only docs and issue, main unchanged | **Work in progress during planning request** |
| M1 — isolated runtime interface inventory | Read-only probe installed AAI `remote.interfaces`, native entity/guns/connectors | WAR-CAP-001…010 factually reported | Not started / no approval to write runtime probes |
| M2 — vanilla turret remote target trial | Branch-only, behind off-by-default flag | WAR-FUNC-001,002,006 passed with explicit target release semantics | Not started |
| M3 — Skitarii prototype + direct operator | Original asset development, branch-only | WAR-FUNC-003,004,010,011,012 | Not started |
| M4 — connected defense cannon/bunker | Native controlled turret with circuit/power and source-authored asset | WAR-FUNC-005,006,014 | Not started |
| M5 — vehicle-led offensive warfare | Existing vanilla & KJ; AAI nav support; reserve real ammo/fuel | WAR-FUNC-007–009,015; 016 only if multi-gun is authorized | Not started |
| M6 — sensor doctrine, anti-air and advanced force composition | Only if target type and dedicated models exist | Deterministic anti-friendly fire, accurate target signals and UPS | Not started |
| M7 — integration request | User explicitly approves merge and defaults | One isolated Warfare native job plus unchanged factory regression, no surprise feature activation | Not approved |

The current main-branch release-blocking policy remains separate: **runtime build/launch failures, required multiplayer/updater errors** are hard blockers; visual/balance/style are diagnostic only. For future Warfare experiment acceptance, tests may fail a *Warfare feature-development gate* without blocking unrelated factory shipping. Do not give a completed release label for an asset that has never been built.

## F. State, scope and ownership rules

1. No changes to `tech-priests_src/control.lua`, game prototypes, `info.json` dependencies or factory CI workflows during this **planning-only** period.
2. No speculative implementation hidden inside a placeholder installer or automatic startup route.
3. AAI's one-weapon policy remains as shipped until its documented interfaces and identity/custody consequences are tested; retired `40kvehicles-AAI-fix` stays retired.
4. A future module uses separate storage under a distinct `warfare` namespace, event broker and original dispatcher through narrow contracts.
5. No fork or repackaging of AAI's limited-distribution source; use public docs, observed prototypes, allowed runtime inspections and independently authored code.
6. A new release, branch merge, or rebase of main is a separate explicit authorization.
7. User-visible builds must use original source art or verified licensed assets and obey the established visible-geometry modeling rule.

## G. Current evidence caveats

- All 13-mod ZIPs successfully loaded in the smoke but no deployed Skitarii or defense bunker exists yet.
- AAI log contains gun-specific AI conversion lines, **not** a firing/turning/movement trace.
- AAI public docs say one weapon type per AI unit, and biter AI paths are sometimes unreliable.
- AAI API function signatures / actual weapon-mode switching are **unknown** until read-only introspection.
- There is no current gameplay telemetry that proves 40K guns/armor operate properly despite the four nonfatal KJ `Turret not found` warnings.
- Factorio native remote camera ≠ Skitarii possession ≠ native gun fire control.
