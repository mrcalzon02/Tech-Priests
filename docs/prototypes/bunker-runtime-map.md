# Main-mod bunker runtime ownership

```mermaid
flowchart TD
  Data[data.lua] --> Family[bunker_family.register]
  Data --> Bullets[bunker_bullet_weapons.register]
  Data --> Cannon[bunker_twin_cannon.register]
  Data --> Rocket[bunker_rocket_salvo.register]
  Data --> Artillery[bunker_artillery.register]
  Final[data-final-fixes.lua] --> Finalizers[Grenade packs / bullets / cannon / rocket / artillery finalizers]
  Finalizers --> Schema[Existing recipe schema sanitizer]
  Control[control.lua] --> Install[bunker_cannon_integration.install_main]
  Install --> Registry[Existing canonical runtime_event_registry]
  Registry --> Init[Init/configuration: discover existing weapons]
  Registry --> Tick[Tick: family, cannon, rocket and artillery motion]
  Registry --> Shot[Native trigger effects: shot / muzzle callbacks]
  Registry --> Built[Build / revive / clone: register weapon]
  Registry --> Hit[Damage: bullet shot observer]
  Tick --> Render[Separate cap / aerials / shadows; fixed foundation]
  Shot --> Render
  Native[Native turret targeting and ammunition] --> Projectile[Original cannon projectile / native damage]
  Shot --> Muzzle[Move original projectile to alternating active muzzle]
  Muzzle --> Projectile
  Registry --> ArtShot[Original artillery launch notification]
  ArtShot --> Barrage[Advance paid chamber / pause after third shell]
  Barrage --> Render
  Artillery --> ArtMuzzle[Native gun launch table from the model muzzle socket]
  ArtMuzzle --> ArtProjectile[Original artillery projectile and native damage]
```

The weapon owner adds named routes; it does not install raw script handlers
over priest services. An installation assertion verifies every previous route
still exists. Full-mod fixtures observed 180 preserved routes. Rendering is
shot-driven; ammunition and damage remain owned by the native engine.

Artillery observes `on_trigger_fired_artillery`. It does not create replacement
shells or apply scripted damage. Its native gun fires at the model-derived
socket, and the observer selects recoil, breech indexing, lowering, gate motion,
shell insertion and re-elevation. The fixed foundation retains the shared
force-coloured corner masks.

The artillery window uses a live camera and actual inventory widgets. A static
cap must not be layered over the moving body: an earlier alpha-intersection
fallback hid the lower reload cage. The native cap sublayers now remain empty;
the complete source body, shell overlays and moving shadow are rendered by the
weapon owner.
