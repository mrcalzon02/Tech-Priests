-- Factorio --test-scenario only: spawn one CI test unit and verify real
-- engine command movement followed by native attack damage. Do not run in
-- production control.lua. No AAI commands are issued.
local NAME = "warfare-skitarii-experiment"
local PREFIX = "[WAR-SKITARII] "
local phase = "setup"
local soldier, target, start_pos, attack_start_hp, move_ok

local function emit(key, value)
  log(PREFIX .. key .. "=" .. tostring(value))
end
local function fail(reason)
  emit("FAIL", reason)
  script.finish_test(false)
  phase = "finished"
end
local function distance(a,b)
  local dx = a.x-b.x
  local dy = a.y-b.y
  return math.sqrt(dx*dx + dy*dy)
end

script.on_nth_tick(10, function(event)
  if phase == "finished" then return end
  local ok, err = pcall(function()
    if phase == "setup" then
      assert(script.active_mods["warfare-skitarii-experiment"] == "0.0.1",
          "isolated experiment mod missing")
      local surface = game.surfaces["nauvis"]
      assert(surface, "Nauvis missing")
      local center = {x=0,y=0}
      surface.request_to_generate_chunks(center, 2)
      surface.force_generate_chunk_requests()
      local pos = surface.find_non_colliding_position(NAME, center, 24, 0.5)
      assert(pos, "no legal Skitarii spawn position")
      soldier = surface.create_entity({
        name=NAME, position=pos, force=game.forces.player
      })
      assert(soldier and soldier.valid and soldier.type == "unit",
          "native unit spawn failed")
      assert(soldier.commandable and soldier.commandable.valid,
          "unit lacks native LuaCommandable")
      assert(soldier.prototype.name == NAME, "wrong unit prototype loaded")
      start_pos = {x=soldier.position.x,y=soldier.position.y}
      local destination = {x=start_pos.x+8,y=start_pos.y}
      soldier.commandable.set_command({
        type=defines.command.go_to_location,
        destination=destination,
        radius=1,
        distraction=defines.distraction.none,
      })
      emit("spawned", soldier.name)
      emit("commandable", soldier.commandable.object_name)
      emit("move_issued_tick", event.tick)
      phase = "moving"
      return
    end

    assert(soldier and soldier.valid, "Skitarii vanished before test finished")
    if phase == "moving" then
      local travelled = distance(soldier.position, start_pos)
      if travelled >= 4 then
        move_ok = travelled
        emit("native_walk_tiles", string.format("%.3f", travelled))
        emit("walk_verified", "true")
        local surface = soldier.surface
        local enemy_pos = {x=soldier.position.x+6,y=soldier.position.y}
        local target_pos = surface.find_non_colliding_position(
          "wooden-chest", enemy_pos, 15, 0.5)
        assert(target_pos, "no legal enemy dummy position")
        target = surface.create_entity({
          name="wooden-chest", position=target_pos, force=game.forces.enemy
        })
        assert(target and target.valid and target.health, "native target spawn failed")
        target.health = math.min(80, target.health)
        attack_start_hp = target.health
        soldier.commandable.set_command({
          type=defines.command.attack,
          target=target,
          distraction=defines.distraction.none,
        })
        emit("attack_issued_tick", event.tick)
        phase = "attacking"
      elseif event.tick > 500 then
        fail("no native movement >=4 tiles before tick 500; reached=" .. travelled)
      end
      return
    end

    if phase == "attacking" then
      if not (target and target.valid) then
        assert(move_ok and move_ok>=4,"no observed native walking")
        emit("target_destroyed", "true")
        emit("native_attack_verified", "true")
        emit("STATUS", "PASS")
        phase = "finished"
        script.finish_test(true)
        return
      end
      if target.health < attack_start_hp - 0.1 then
        assert(move_ok and move_ok >=4, "missing verified native walking")
        emit("native_damage", string.format("%.3f", attack_start_hp-target.health))
        emit("native_attack_verified", "true")
        emit("STATUS", "PASS")
        phase = "finished"
        script.finish_test(true)
      elseif event.tick > 1050 then
        fail("no native attack damage by tick 1050; target health=" ..
             tostring(target.health))
      end
    end
  end)
  if not ok then fail("runtime-exception: " .. tostring(err)) end
end)
