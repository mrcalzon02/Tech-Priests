# Full autonomous factory escalation: logistics frustration admission (1504)

**Rule:** On deployment, Tech-Priests keep ordinary repair, consecration,
maintenance, defense, and logistical fulfillment duties. They must **not**
independently fabricate an entire industrial chain or seed new autonomous
construction ghosts until their existing per-pair logistics frustration timer
reaches its full due tick.

The existing `logistic_frustration_start_tick` and
`logistic_frustration_due_tick` own the countdown; the new admission gate
does not set another duration or assume generic idle time is frustration.
No timer means no automatic factory escalation. When the original logistics
deadline is observed, the pair receives a persistent one-way
`self_construction_frustration_unlocked_1504` latch; successful supplies
afterward do not rewind an already authorized factory program.

**Guarded new-work paths:** 0640 infrastructure-first assignments; 0645
autonomous factory construction ghost planning (including 0643 network
shortage referrals); 0338 construction discovery for 0645 ghosts (including
cached candidates surviving reload); 0343 missing-core-facility construction
requests; and the original 0184 frustration-driven independent emergency
operation. The legacy 90-second generic idle fallback is **not** factory
authorization. A late 0184 service guard defers the factory path while
the priest continues through ordinary tick processing.

**Preserved work:** existing 0338 physical construction and material custody,
already initiated independent emergency crafts, scavenge tasks, and emergency
construction; explicit separately owned construction orders and other worker
duties remain under their established authorities. Existing physical emergency
machines may still be serviced before escalation.

**Tests:** `tests/unit/self_construction_frustration_gate.lua` covers missing,
malformed, pending, exact-expiry and persistent-after-clear states. The native
Factorio acceptance scenario must demonstrate (1) no autonomous ghost/new
infrastructure before the timer, (2) repairs/consecration continue, (3) factory
builds begin only after full timer expiry with real materials, (4) a save/reload
retains the latch and does not discard committed material, and (5) manual
orders and defensive work remain available. Static checks are not native
acceptance; do not declare the release validated without a real game run.
