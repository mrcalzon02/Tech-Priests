# Main-mod bunker runtime ownership

```mermaid
flowchart TD
  Data[data.lua] --> Family[bunker_family.register]
  Data --> Bullets[bunker_bullet_weapons.register]
  Data --> Cannon[bunker_twin_cannon.register]
  Final[data-final-fixes.lua] --> Finalizers[Grenade packs / bullets / cannon finalizers]
  Finalizers --> Schema[Existing recipe schema sanitizer]
  Control[control.lua] --> Install[bunker_cannon_integration.install_main]
  Install --> Registry[Existing canonical runtime_event_registry]
  Registry --> Init[Init/configuration: discover existing weapons]
  Registry --> Tick[Tick: family motion and cannon motion]
  Registry --> Shot[Native trigger effects: shot / muzzle callbacks]
  Registry --> Built[Build / revive / clone: register weapon]
  Registry --> Hit[Damage: bullet shot observer]
  Tick --> Render[Separate cap / aerials / shadows; fixed foundation]
  Shot --> Render
  Native[Native turret targeting and ammunition] --> Projectile[Original cannon projectile / native damage]
  Shot --> Muzzle[Move original projectile to alternating active muzzle]
  Muzzle --> Projectile
```

The weapon owner adds named routes; it does not install raw script handlers
over priest services. An installation assertion verifies every previous route
still exists. Full-mod fixtures observed 180 preserved routes. Rendering is
shot-driven; ammunition and damage remain owned by the native engine.
