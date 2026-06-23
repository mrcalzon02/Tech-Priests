# ALT Claimed-Resource Fields and Cogitator Range Authority — 0.1.663

Scope: replacement of the old per-resource ALT debug markers, repair of the apparent single-station ownership display, aggregation of all same-force station claims, and a centralized Cogitator operating-range increase.

## Current status

- Aggregate all-station claim collection: **implemented**
- Resource-field clustering: **implemented**
- Glowing boundary rendering: **implemented**
- Field-level icon and summary label: **implemented**
- Legacy per-node ALT markers: **disabled and cleared during installation**
- Force/surface filtering: **implemented**
- Catalog ownership validation: **implemented**
- Station operating-range buff: **implemented at +5 tiles**
- Technology and quality range bonuses: **preserved**
- Direct-acquisition personal travel caps: **intentionally unchanged**
- Runtime Factorio validation: **pending**

---

## Root cause of the “single station” display

The old ALT renderer did technically iterate the catalogs for all same-force stations. The visible failure came from its presentation budget:

1. It placed one marker and one sprite over every retained claimed entity instance.
2. It stopped after 384 individual markers.
3. Station catalogs were traversed sequentially.
4. A sufficiently large ore field belonging to an early station could consume the entire marker budget.
5. Later station catalogs were never reached during that redraw.

This made a force-wide catalog look like a single-station claim display even though the underlying ownership ledger contained claims from multiple stations.

The old system also inherited each catalog record's retained-instance limit, so a huge field could be both visually noisy and incomplete.

---

## New presentation model

`alt_resource_field_overlay_0679.lua` treats claimed natural resources as fields rather than isolated debugging points.

### Claim collection

For the current player's force and surface, it gathers claims from every valid Cogitator catalog through:

- catalog `resources` records,
- catalog `mineable_products` records,
- retained concrete instances,
- direct resource scans validated against the authoritative `owned_resources` ledger,
- recoverable positional ownership keys that exceeded catalog instance retention.

Physical entity keys are deduplicated so a resource appearing as both a raw resource and a mineable product contributes only one claimed position.

### Field construction

Claims are grouped by resource type into six-tile grid cells. Adjacent cells, including diagonal adjacency, are flood-filled into one field.

A field records:

- resource type,
- claimed physical node count,
- aggregate recorded amount,
- owning station set,
- field center,
- occupied cells,
- field bounds.

### Rendering

Large fields receive:

- a thick, faint outer boundary,
- a narrow, bright inner boundary,
- one resource icon near the field center,
- one label showing resource name, claimed-node count, and owning-station count.

Very small or isolated claims receive a compact glowing circle rather than a rectangular cell boundary.

The renderer is player-local and appears only while Factorio ALT/entity-information mode is enabled.

---

## Force-wide ownership behavior

The field map is built from every valid station on the player's current surface and force. It does not require selecting a particular Cogitator.

Claims remain assigned to their real station owner in `station_catalog_0327.owned_resources`; the field renderer aggregates them only for presentation. A continuous ore field can therefore display one shared field label such as “iron ore — 186 claimed — 3 stations” while the catalog retains exact per-entity ownership beneath it.

This avoids changing acquisition arbitration merely to improve visualization.

---

## Rendering budgets

| Limit | Value | Purpose |
|---|---:|---|
| Grid cell size | 6 tiles | Reduces thousands of ore entities to a manageable field shape |
| Maximum fields per player | 96 | Bounds map-overlay work |
| Maximum boundary segments | 520 | Bounds rendering objects |
| Maximum resource entities examined per station recovery scan | 2,048 | Recovers large ownership ledgers without unbounded scans |
| Catalog retained instances per item | Raised to at least 1,024 | Improves exact field reconstruction and acquisition visibility |
| Field redraw period | 120 ticks | Avoids rebuilding unchanged fields continuously |
| Rendering TTL | 180 ticks | Allows stable draw-before-destroy refresh |

Fields are sorted by claimed-node count before drawing, so the largest operational fields receive priority if an extreme map reaches a rendering cap. Unlike the previous per-node approach, one large field uses a bounded number of edge segments rather than consuming hundreds of individual icons.

---

## Cache and invalidation behavior

Field geometry is cached by player surface and force. The cache signature includes:

- mod field-map version,
- surface index,
- force index,
- total ownership-ledger size,
- each matching station catalog's scan tick,
- each catalog's owned-resource count,
- each catalog's operating radius.

Catalog rescans, ownership changes, station-range changes, surface changes, or force changes therefore invalidate the relevant field map.

The range authority explicitly clears both legacy visual signatures and field geometry caches when an effective station radius changes.

---

## Cogitator operating-range buff

`station_range_authority_0680.lua` adds a flat five-tile policy bonus after the existing base, technology, and quality calculations.

### Effective base radii before technology and quality

| Cogitator tier | Previous base | 0.1.663 base |
|---|---:|---:|
| Junior | 25 | **30** |
| Intermediate | 30 | **35** |
| Senior | 35 | **40** |
| Planetary Magos | 35 | **40** |
| Void | 41 | **46** |

Existing range research remains additive. Existing station-quality bonuses remain additive and retain their prior cap.

The authority patches the canonical radius readers:

- `get_station_operating_radius`
- `refresh_pair_radius`
- `tech_priests_radar_operating_radius_0280`

It refreshes existing pairs, invalidates affected station catalogs, and redraws radius/resource overlays when the calculated radius changes.

---

## Deliberate separation from personal acquisition travel

The +5 buff expands station territory, catalog coverage, construction/repair eligibility, resource ownership, and visual radius overlays.

It does **not** automatically raise the conservative direct-acquisition role caps in `movement_bounds_contract_0511.lua`.

Those personal travel caps remain:

- Planetary Magos: 24
- Senior: 32
- Intermediate: 34
- Junior: 36

This is intentional. A station may own and coordinate a wider territory without requiring its individual priest to personally chase every resource at the edge of that territory. Delegation, logistics, and known-source acquisition can use the larger station network while direct emergency mining remains bounded.

A later balance pass can raise the personal caps separately after movement behavior is runtime-verified.

---

## Commandless runtime changes

The following old visual debug commands are removed during installation:

- `/tp-visual-stability-0474`
- `/tp-visual-lease-0487`

The player-facing claimed-resource map is controlled by ordinary Factorio ALT mode. Automatic diagnostics replace the old command-only inspection path.

---

## Automatic diagnostics

### Claimed-resource fields

`PAIR-DUMP-0468 ALT-RESOURCE-FIELDS-0679` reports:

- enabled state,
- collected claim count,
- total field count,
- rendered field count,
- boundary-segment count,
- rendering-object count,
- unresolved ownership-key count,
- field-cache hits,
- field-cache rebuilds.

### Station range

`PAIR-DUMP-0468 STATION-RANGE-0680` reports:

- authority enabled state,
- flat bonus,
- effective base range for every station prototype,
- pairs checked,
- pairs whose radius changed,
- confirmation that direct-acquisition bounds remain unchanged.

---

## Runtime validation scenarios still pending

1. **Two-station display** — place two same-force Cogitators over separate ore fields and confirm both fields appear simultaneously in ALT mode.
2. **Large first field** — give the first station a field containing more than 384 ore entities and confirm later stations still appear.
3. **Shared continuous field** — overlap two station territories over one continuous ore patch and confirm it renders as one field with multiple owning stations.
4. **Different resource types** — place iron, copper, coal, stone, uranium, oil, and modded resources near multiple stations and confirm each type forms separate fields.
5. **Surface filtering** — confirm ALT fields from another planet or surface do not appear on the current surface.
6. **Force filtering** — confirm another force's claims do not appear to the player.
7. **Catalog ownership change** — remove a station or change overlapping ownership and confirm field geometry refreshes without stale edges.
8. **Range expansion** — confirm existing station radius overlays and catalog scans increase by exactly five tiles before research/quality bonuses.
9. **Research and quality** — confirm technology and quality bonuses stack on top of the new flat bonus exactly once.
10. **Direct-movement separation** — confirm a priest does not personally direct-mine beyond its unchanged role cap merely because its station territory grew.
11. **ALT transition** — turn ALT mode off and confirm field objects clear; turn it on and confirm they redraw without old per-node markers.
12. **Performance stress** — test many stations and several very large patches while monitoring field-cache hits, edge counts, and visual responsiveness.

---

## Completion estimate

### Implementation

- All-station aggregate claims: **100% implemented**
- Field-level visualization: **100% implemented**
- Legacy marker retirement: **100% implemented**
- Centralized +5 station-range policy: **100% implemented**
- Automatic diagnostics: **100% implemented**

### Verification

- Static source review: completed
- External Lua parser: pending
- Factorio load test: pending
- Runtime scenarios: 0 of 12 executed

### Overall confidence

**Approximately 80% complete.**

The remaining work is runtime validation and any correction demanded by actual Factorio rendering, ownership, or performance evidence. No known implementation item from the requested ALT aggregation or +5 station-range buff remains intentionally unimplemented.

---

## Next sequential development target

After runtime verification, continue with the planned machine-logistics 0528 mapping and remediation. That pass should explicitly reuse:

- the expanded station territory,
- the authoritative all-station ownership ledger,
- field-level resource context,
- existing inventory steward and station catalog authorities,
- unchanged personal direct-acquisition bounds.
