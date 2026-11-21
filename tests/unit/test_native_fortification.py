#!/usr/bin/env python3
"""Contracts for real Factorio fortification fixtures; never gameplay PASS."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
FORT = ROOT / "tests/scenarios/combat-roster/fortification.lua"
LAUNCHER = ROOT / "tools/run_combat_roster_native.py"
BATCH = ROOT / "tests/scenarios/combat-roster/batch_visual.lua"


class NativeFortificationContract(unittest.TestCase):
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

    def test_real_wall_ring_clearances_are_measured_not_reported_from_request(self):
        source = FORT.read_text(encoding="utf-8")
        self.assertIn('settings.thickness==1 or settings.thickness==2', source)
        self.assertIn('settings.clearance==3 or settings.clearance==7', source)
        self.assertIn('for layer=0,settings.thickness-1 do', source)
        self.assertIn('for x=-hx,hx do place_wall(x,-hy);place_wall(x,hy) end', source)
        self.assertIn('for y=-hy+1,hy-1 do place_wall(-hx,y);place_wall(hx,y) end', source)
        self.assertIn('first_wall_distance=math.min(', source)
        self.assertIn('measured_min_wall_clearance=t.measured_min_clearance', source)
        self.assertIn('require_native(#t.walls==expected_walls', source)

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
