-- Disposable branch-only test of original Tech-Priests gun proxy on Skitarii.
-- The visual soldier and proxy use real in-engine entities. A fully separate
-- enemy-owned chest is intentionally outside the soldier's 12-tile melee/marker
-- attack and inside the proxy's 15-tile bullet range. No scripted damage.
-- All world changes occur only inside Factorio --test-scenario.
local prefix = "[WAR-AMMO] "
local state = { phase = "setup", start_tick = 0 }
local soldier, proxy, target, ammo_inventory, before_count, before_ammo, health_before

local function emit(name, value)
  log(prefix .. name .. "=" .. tostring(value))
end

local function fail(message)
  if state.phase == "finished" then return end
  emit("FAIL", message)
  emit("STATUS", "FAIL")
  state.phase = "finished"
  script.finish_test(false)
end

script.on_nth_tick(10, function(event)
  if state.phase == "finished" then return end
  local ok, err = pcall(function()
    if state.phase == "setup" then
      local surface = assert(game.surfaces["nauvis"], "Nauvis missing")
      local origin = {x=0,y=0}
      surface.request_to_generate_chunks(origin, 2)
      surface.force_generate_chunk_requests()

      local pos = assert(surface.find_non_colliding_position(
        "warfare-skitarii-experiment", origin, 20, 0.5),
        "No legal infantry spawn tile")
      soldier = assert(surface.create_entity{
        name="warfare-skitarii-experiment", position=pos, force=game.forces.player
      }, "Native Skitarii unit did not spawn")
      assert(soldier.valid and soldier.type == "unit", "Wrong Skitarii entity")
      assert(soldier.commandable, "Skitarii commandable missing")

      local proxy_proto = prototypes.entity["tech-priest-small-arms-proxy"]
      assert(proxy_proto and proxy_proto.type == "ammo-turret",
        "Existing native small-arms proxy not available")
      -- Keep soldier still so it is not responsible for target damage.
      soldier.commandable.set_command({
        type=defines.command.stop, distraction=defines.distraction.none
      })

      proxy = assert(surface.create_entity{
        name="tech-priest-small-arms-proxy",
        position=soldier.position,
        force=game.forces.player
      }, "Native ammo proxy did not spawn")
      assert(proxy.valid and proxy.type == "ammo-turret",
        "Wrong proxy entity type")

      -- The original priest proxy shoots only within 15 tiles, while the
      -- experimental soldier's marker attack ranges 12 tiles. This ensures
      -- any native target damage comes from the ammo-fed proxy, not the unit.
      local enemy_pos = {
        x=soldier.position.x+13.5, y=soldier.position.y
      }
      local target_pos = assert(surface.find_non_colliding_position(
        "wooden-chest", enemy_pos, 2, 0.1), "No clear target position")
      assert(math.abs(target_pos.x-soldier.position.x) > 12,
        "Target within direct soldier attack reach")
      target = assert(surface.create_entity{
        name="wooden-chest", position=target_pos, force=game.forces.enemy
      }, "Native enemy target did not spawn")
      target.health = math.min(target.health, 180)
      health_before = target.health

      ammo_inventory = assert(
        proxy.get_inventory(defines.inventory.turret_ammo),
        "Proxy has no native turret ammo inventory")
      local inserted = ammo_inventory.insert{
        name="firearm-magazine", count=5
      }
      assert(inserted == 5, "Proxy refused actual physical firearm magazines")
      local slot = ammo_inventory[1]
      assert(slot and slot.valid_for_read and slot.name=="firearm-magazine",
        "Native magazine not retained in ammo inventory")
      before_count = slot.count
      before_ammo = slot.ammo
      assert(before_ammo > 0, "Magazine had no native ammo")

      proxy.active = true
      proxy.operable = false
      proxy.shooting_target = target
      assert(proxy.shooting_target == target,
        "Native proxy refused or changed shooting target")
      state.start_tick = event.tick
      emit("soldier_unit", soldier.name)
      emit("proxy_entity", proxy.name)
      emit("target_distance", string.format("%.3f",
        math.abs(target.position.x-soldier.position.x)))
      emit("initial_magazines", before_count)
      emit("initial_loaded_rounds", before_ammo)
      emit("target_hp", health_before)
      state.phase = "firing"
      return
    end

    assert(soldier and soldier.valid, "Infantry vanished during proxy test")
    assert(proxy and proxy.valid, "Proxy vanished during test")
    assert(target and target.valid, "Enemy target was destroyed; no final readback")
    local slot = ammo_inventory[1]
    local after_count = slot.valid_for_read and slot.count or 0
    local after_ammo = slot.valid_for_read and slot.ammo or 0
    local native_damage = health_before - target.health
    local consumed = (after_count < before_count) or
                     (after_count == before_count and after_ammo < before_ammo)
    if native_damage > 0.01 and consumed then
      emit("native_damage", string.format("%.3f", native_damage))
      emit("magazines_now", after_count)
      emit("loaded_rounds_now", after_ammo)
      emit("ammo_consumption_verified", "true")
      emit("proxy_damage_verified", "true")
      emit("STATUS", "PASS")
      state.phase = "finished"
      script.finish_test(true)
    elseif event.tick - state.start_tick > 720 then
      fail("No combined native target damage + magazine consumption: damage=" ..
        tostring(native_damage) .. " magazines=" .. tostring(after_count) ..
        " bullets=" .. tostring(after_ammo))
    end
  end)
  if not ok then fail("runtime-exception: " .. tostring(err)) end
end)
