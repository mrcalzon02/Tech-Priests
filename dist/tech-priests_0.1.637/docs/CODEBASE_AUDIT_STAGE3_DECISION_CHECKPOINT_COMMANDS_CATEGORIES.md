# Stage 3 Decision Checkpoint — Direct Commands and Work Categories

This checkpoint records the interpretation of the locally regenerated Stage 3 direct-command and work-category reports.

This is documentation-only. No runtime behavior has been changed by this note.

## Direct command report result

Current report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE3_DIRECT_COMMAND_SITES.md
```

Important totals:

- Direct command issue sites: `142`

Classification counts:

| Classification | Count |
|---|---:|
| `direct-stop-command` | 54 |
| `route-first-or-movement-request-fallback` | 49 |
| `direct-go-to-location-command` | 22 |
| `canonical-movement-controller` | 10 |
| `combat-attack-command-wrapper` | 4 |
| `issue-priest-command-wrapper-or-call` | 3 |

Kind counts:

| Kind | Count |
|---|---:|
| `entity.set_command` | 64 |
| `commandable.set_command` | 32 |
| `entity.commandable.set_command` | 22 |
| `global issue_priest_command call` | 22 |
| `global issue_priest_command assignment` | 2 |

## Direct command interpretation

The first scanner reported `302` command-related references. The second scanner reduced that to `142` likely command issue sites, which is still a large real ownership surface.

The movement command surface is not clean enough to migrate casually. There are direct stop and go-to-location issue sites outside `movement_controller.lua`, but many are likely safety stops, fallback branches, emergency movement requests, or route-first wrappers.

Current decision:

```text
Do not migrate direct command sites yet.
Do not remove direct stops yet.
Do not fold command fallbacks into movement_controller until Stage 4/5 inventories explain lifecycle and stale-state behavior.
```

Reason:

Some direct commands likely exist to prevent remote beams, stop stuck commands, suppress friendly-fire attacks, or recover from stale motion. Removing them before lifecycle/dead-end audit risks reintroducing disappearing/stuck/stalled-priest behavior.

## Work category report result

Current report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE3_WORK_CATEGORY_USAGE.md
```

Important totals:

- Total category hits: `550`
- Emergency category hits: `50`

Category counts:

| Category | Count |
|---|---:|
| `repair` | 171 |
| `combat` | 126 |
| `resource` | 97 |
| `logistics` | 53 |
| `emergency` | 50 |
| `construction` | 26 |
| `pickup` | 11 |
| `sanctify` | 11 |
| `machine-logistics` | 5 |

Usage-kind counts:

| Kind | Count |
|---|---:|
| `literal_category` | 545 |
| `work_queue_claim_nearest` | 2 |
| `work_queue_submit` | 2 |
| `reservation_claim` | 1 |

## Emergency reservation mismatch decision

The earlier mismatch remains real in static definitions:

```text
work_queue_authority categories include emergency.
work_reservations categories omit emergency.
```

However, the refreshed category report did not confirm that `emergency` is actually submitted to the work queue or claimed through `work_reservations` as a shared reservation category. The emergency hits visible in the report are mostly mode/state/status/scheduler literals, not concrete emergency work reservations.

Current decision:

```text
Do not patch work_reservations.lua yet.
Keep the emergency category mismatch documented as a probable tiny repair candidate only if a reachable emergency reservation path is later found.
```

Safe repair shape if later confirmed reachable:

```lua
M.categories = { "repair", "sanctify", "resource", "construction", "pickup", "emergency", "combat" }
```

But do not apply that simply because the literal exists in work queue categories.

## Updated Stage 3 conclusion

Stage 3 has now mapped the main behavior stack, logistics/machine-logistics, construction, ordinary combat, direct command ownership, and work category usage enough to justify moving forward.

The key result is not a code patch. The key result is a boundary:

```text
No behavior-critical command/movement/lifecycle migration until Stage 4 and Stage 5 explain destruction, recall, stuck, stale command, and dead-end state behavior.
```

## Next stage

Proceed to Stage 4:

```text
Pair lifecycle, recovery, and destruction audit
```

Stage 4 should inventory all paths that can destroy, replace, recall, teleport, respawn, invalidate, or strand a Tech-Priest pair.

The first tool should be a read-only lifecycle/destruction scanner covering:

- `.destroy(`
- `raise_destroy`
- `create_entity`
- `respawn_pair_priest`
- `remove_pair_for_entity`
- `create_pair`
- `stuck`
- `recall`
- `orphan`
- `missing_priest`
- `teleport`
- `destructible`
- `active = false`
- proxy entity lifecycle
- priest lifecycle seal paths
