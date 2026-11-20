# Player inventory target safety — legacy-provider hardening (1499)

The existing `inventory_target_safety.lua` prevents a Tech Priest's
automated logistics and idle scan from treating a real player or
character-like entity as a storage chest. This refinement supports two
legacy candidate shapes:

- Normal `{entity=<LuaEntity>, ...}` inventory/idle-scan entries.
- Direct `LuaEntity` values returned by older or modded providers.

It handles an unsupported candidate `.entity` property through `pcall`
instead of risking a LuaEntity field-access error, and only wraps previously
installed provider functions when those globals actually contain functions.

Ordinary storage and machine candidates keep their original payload and
relative order; no new scheduler, item transfer, force ownership, mining,
inventory deletion, or player-inventory access is introduced.

## Source regression

Run from the repository root using Lua 5.2+:

```sh
texlua tests/unit/inventory_target_safety_1499.lua
```

The test checks wrapped/direct vanilla player characters and player-bound
modded entities, valid machine retention, unsupported entity-property
handling, provider errors, and no-provider fallback. Executed locally
against byte-identical files from the committed repository.

**Native status:** source/mock regression passed. End-to-end Factorio 2.1
multiplayer and modded-character acceptance are still unverified.
