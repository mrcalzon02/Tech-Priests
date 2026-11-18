# Focused broker correction review

Reviewed the four-file override against the first combined native snapshot.
The revised snapshot differs in exactly these four files; their after-hashes
match the root's `runtime-overrides.json`.

- `character_visuals.lua` registers one named, five-tick broker service instead
  of a direct per-tick event route. It respects the broker's offered budget and
  opts into dormant execution only while presentation/picker work exists.
- `runtime_tick_broker.lua` retains a sorted set of explicitly opted-in dormant
  services. Non-opted background services remain outside a dormant pulse.
- `efficiency_economy_0595.lua` admits only the canonical central broker route
  with a `dormant-broker-only` scope when explicit dormant work is present.
- `runtime_event_registry.lua` rechecks each co-scheduled route under that
  scope, preventing a second registry five-tick route from inheriting the
  exception. It registers canonical dispatch through the registration function
  saved by 0596, while retaining canonical 0595 dormant and 0598 budget guards.

The repeated four-drive proof covers combined runtime interaction, flight,
power/feeds, repair, and real save/reload. Negative dormant assertions are limited
to ordinary broker services and co-scheduled registry routes; the units agent's
focused fixture separately checks presentation and these routing boundaries.

The correction is intended to preserve existing legacy raw-handler delivery.
Native baseline-versus-revised raw delivery remains a separate investigation.
This review does not claim that direct raw handlers remain wrapped or suppressed.
Neither proof supplies artistic approval.
