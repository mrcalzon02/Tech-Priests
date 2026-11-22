#!/usr/bin/env python3
"""Contracts for real Factorio fortification fixtures; never gameplay PASS."""
import pathlib
import re
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
FORT = ROOT / "tests/scenarios/combat-roster/fortification.lua"
LAUNCHER = ROOT / "tools/run_combat_roster_native.py"
BATCH = ROOT / "tests/scenarios/combat-roster/batch_visual.lua"


class NativeFortificationContract(unittest.TestCase):
    def test_collinear_cannon_ejection_preserves_stock_shells(self):
        source = (ROOT / "tech-priests_src/prototypes/bunker_twin_cannon.lua").read_text(
            encoding="utf-8")
        self.assertIn("t.attack_parameters=table.deepcopy(data.raw.gun['tank-cannon'].attack_parameters)", source)
        self.assertIn("t.attack_parameters.true_collinear_ejection=true", source)
        self.assertIn("for _,ammo in pairs(data.raw.ammo) do if ammo.ammo_category=='cannon-shell'", source)
        self.assertNotIn("t.attack_parameters.ammo_categories=", source)

    def test_no_scripted_damage_or_skipped_native_engine(self):
        source = FORT.read_text(encoding="utf-8")
        for mandatory in (
            'Registry.on_init(init,',
            'on_entity_damaged,on_damaged',
            'on_entity_died,on_died',
            's.create_entity{name="stone-wall"',
            'local wall=s.create_entity',
            't.wall_units[wall.unit_number]',
            'include_extent(t.bounds,gun)',
            'include_extent(t.bounds,car)',
            'first_wall_distance>=settings.clearance',
            'settings.thickness',
            'wall_first_inner_loss_tick',
            'enemy_first_inside_tick',
            'final.enemies_alive==0',
            'game.forces.enemy.get_evolution_factor',
            'native_spawn_profile("biter-spawner"',
            'native_spawn_profile("spitter-spawner"',
            'prototypes.entity[spawner]',
            'Bridge.unit(car)',
            'Bridge.command(car,player',
            'defender_roster',
            'tower_roster',
            'damage_by_tower',
            'native=true',
            'no_scripted_damage=true',
        ):
            self.assertIn(mandatory, source)
        for forbidden in (
            'game.speed=', 'game.tick_paused=', 'kill_all_units',
            'cause.damage(', 'entity.damage(', 'entity.die(', 'b.die(',
            'b.health=0', 'wall.health=0'
        ):
            self.assertNotIn(forbidden, source)

    def test_native_damage_ledger_separates_enemy_hits_from_friendly_fire(self):
        source = FORT.read_text(encoding="utf-8")
        for marker in (
            'damage_by_tower_target={}',
            'wall_kills_by_source={}',
            'target_class="wall"',
            'target_class="friendly_tower"',
            'target_class="enemy"',
            'target_class="defender_or_support"',
            't.damage_by_tower_target[kind]=by_target',
            'by_target[target_class]=by_target[target_class]+amount',
            'wall_kills_by_source=t.wall_kills_by_source',
            'damage_by_tower_target=t.damage_by_tower_target',
        ):
            self.assertIn(marker, source)
        event = source.split("local function on_damaged(event)", 1)[1].split(
            "\nlocal function on_died(event)", 1)[0]
        self.assertIn("event.final_damage_amount", event)
        self.assertIn("event.cause", event)
        self.assertIn("entity.force and entity.force.name", event)
        self.assertNotIn("entity.damage(", event)
        self.assertNotIn("entity.health=", event)
        self.assertNotIn("game.speed=", event)

    def test_wall_integrity_is_distinct_from_enemy_breach_and_engine_pass(self):
        source = FORT.read_text(encoding="utf-8")
        # Real Factorio execution can PASS its fixture while a defense loses
        # wall segments or enemies briefly enter before being eliminated.
        for marker in (
            'status=#blockers==0 and "PASS" or "FAIL"',
            'defense_held=defense_held',
            'wall_held=t.enemy_first_inside_tick==nil',
            'wall_integrity_held=lost_walls==0',
            'wall_segments_lost=lost_walls',
            'wall_survival_fraction=final.walls_alive/#t.walls',
            'inner_wall_damaged=t.wall_first_inner_loss_tick~=nil',
            'wall_segments_lost=lost_walls,first_enemy_inside=',
        ):
            self.assertIn(marker, source)
        self.assertNotIn('wall_integrity_held=defense_held', source)
        self.assertNotIn('wall_integrity_held=t.enemy_first_inside_tick==nil', source)

    def test_seven_distinct_mono_towers_and_explicit_mixed_ratios(self):
        source = FORT.read_text(encoding="utf-8")
        for name in (
            'autocannon', 'chicago', 'minigun', 'cannon',
            'lobber', 'rocket', 'dish',
            'mix-autocannon-minigun-3to1',
            'mix-autocannon-minigun-1to1',
            'mix-autocannon-minigun-1to3',
            'mix-rocket-dish-3to1',
            'mix-all-seven',
        ):
            self.assertIn(name, source)
        for cutoff in ('index%4==0', 'index%2==0'):
            self.assertIn(cutoff, source)
        self.assertIn('require_native(#t.towers==12', source)
        self.assertIn('t.tower_roster[kind]=', source)

    def test_native_aai_defender_types_and_ratios(self):
        source = FORT.read_text(encoding="utf-8")
        for name in (
            'none', 'guardsmen-6', 'guardsmen-12', 'rangers-12',
            'breachers-12', 'sisters-12', 'mixed-12', 'mixed-24'
        ):
            self.assertIn(name, source)
        self.assertIn('Catalog.by_id[id]', source)
        self.assertIn('registered.unit_id', source)
        self.assertIn('Catalog.ammo[unit.ammo_family]', source)
        self.assertIn('get_inventory(defines.inventory.car_ammo)', source)
        self.assertIn('get_fuel_inventory()', source)
        self.assertIn('aai-programmable-vehicles","get_units"', source)
        defender_stage = source.split('local requested=defender_types', 1)[1].split(
            'local inner_x=math.ceil', 1)[0]
        # The AAI command can replace/invalidate the original LuaEntity.
        # Never read its bounding box AFTER handing control to AAI.
        self.assertLess(defender_stage.index('include_extent(t.bounds,car)'),
                        defender_stage.index('Bridge.command(car,player'))

    def test_real_wall_ring_clearances_are_measured_not_reported_from_request(self):
        source = FORT.read_text(encoding="utf-8")
        self.assertIn('settings.thickness==1 or settings.thickness==2', source)
        check = re.search(r'require_native\((settings\.clearance==[^,]+),', source)
        self.assertIsNotNone(check)
        allowed = tuple(map(int, re.findall(r'settings\.clearance==(\d+)', check.group(1))))
        self.assertEqual(allowed, (0, 3, 5, 7, 10, 13))
        launcher = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn("'--fort-clearance',type=int,choices=(0,3,5,7,10,13)", launcher)
        self.assertIn('math.ceil(t.bounds.x+settings.clearance+0.5)', source)
        self.assertIn('math.ceil(t.bounds.y+settings.clearance+0.5)', source)
        self.assertIn('for layer=0,settings.thickness-1 do', source)
        self.assertIn('for x=-hx,hx do place_wall(x,-hy);place_wall(x,hy) end', source)
        self.assertIn('for y=-hy+1,hy-1 do place_wall(-hx,y);place_wall(hx,y) end', source)
        self.assertIn('first_wall_distance=math.min(', source)
        self.assertIn('measured_min_wall_clearance=t.measured_min_clearance', source)
        self.assertIn('include_extent(t.turret_bounds,gun)', source)
        self.assertNotIn('include_extent(t.turret_bounds,car)', source)
        self.assertIn('measured_min_turret_wall_clearance=t.measured_min_turret_clearance', source)
        self.assertIn('require_native(#t.walls==expected_walls', source)

    def test_clearance_cli_is_bounded_and_zero_is_present(self):
        args = [sys.executable, str(LAUNCHER), '--factorio', str(LAUNCHER / 'no-engine'),
                '--scenario', 'fortification-visual', '--fort-towers', 'mix-all-seven',
                '--fort-defenders', 'mixed-12', '--fort-thickness', '1', '--fort-evolution', '1']
        for gap in (0, 3, 5, 7, 10, 13, -1, 6, 14):
            result = subprocess.run(args + ['--fort-clearance', str(gap)],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2, result.stderr)
            expected = ('Installed Factorio executable missing' if gap in (0, 3, 5, 7, 10, 13)
                        else 'invalid choice')
            self.assertIn(expected, result.stderr)
        result = subprocess.run(args, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertIn('fortification requires turret, defenders, thickness, clearance and evolution',
                      result.stderr)

    def test_headless_benchmarks_and_wider_smoother_real_gui_capture(self):
        launcher = LAUNCHER.read_text(encoding="utf-8")
        batch = BATCH.read_text(encoding="utf-8")
        compile(launcher, str(LAUNCHER), "exec")
        for text in (
            'fortification', 'fortification-visual',
            '--fort-thickness', '--fort-clearance', '--fort-towers',
            '--fort-defenders', '--fort-evolution',
            "'--test-save'", "'--test-ticks','3660'",
            'NATIVE_FORTIFICATION_VERDICT',
            'gameplay',
            "'--fps','12'",
            'count>=96 and actual==count'
        ):
            if text == "gameplay":
                continue
            self.assertIn(text, launcher)
        self.assertIn('zoom=.26', FORT.read_text(encoding="utf-8"))
        self.assertIn('resolution={1280,720}', FORT.read_text(encoding="utf-8"))
        self.assertIn('step=48', FORT.read_text(encoding="utf-8"))
        self.assertIn('zoom=.37', batch)
        self.assertIn('step=48', batch)


if __name__ == "__main__":
    unittest.main(verbosity=2)
