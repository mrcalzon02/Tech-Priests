-- 1263: Factorio's native network/placement is authority for installed
-- electric links. Geometry can propose only a physical candidate, never
-- confer an electric connection where the engine reports none.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local A=require("scripts.core.native_electric_authority_1263")
local force={index=1};local enemy={index=2};local surface={index=1}
local station={valid=true,position={x=0,y=0},force=force,surface=surface}
local engine={valid=true,type="generator",position={x=16,y=0},
 force=force,surface=surface,energy_generated_last_tick=0,
 bounding_box={left_top={x=14.5,y=-2.5},
 right_bottom={x=17.5,y=2.5}},
 is_connected_to_electric_network=function()return false end,
 electric_network_id=200}
local pole={valid=true,type="electric-pole",position={x=19.5,y=0.5},
 force=force,surface=surface,
 prototype={supply_area_distance=2.5,maximum_wire_distance=7.5},
 electric_network_id=200}
assert(A.coverage_at(pole.position,engine,2.5),
 "native engine footprint was replaced with center-distance guessed cutoff")
assert(A.network_id(engine)==200 and A.network_id(pole)==200,
 "native Factorio electric network IDs were not read")
local same,reason=A.real_pole_covers(pole,engine)
assert(same and reason=="same-native-electric-network"
 and engine.energy_generated_last_tick==0,
 "same native network rejected just because the boiler has no fuel yet")
pole.electric_network_id=201
local split,split_why=A.real_pole_covers(pole,engine)
assert(not split and split_why=="native-electric-network-mismatch",
 "nearby foreign copper network was mistaken for genuine generator coverage")
pole.electric_network_id=200
engine.electric_network_id=nil
local absent,absent_why=A.real_pole_covers(pole,engine)
assert(not absent and absent_why=="native-machine-electric-network-absent",
 "known unconnected engine was powered by geometric inference")
engine.electric_network_id=200
pole.position={x=24,y=0}
local outside,outside_why=A.real_pole_covers(pole,engine)
assert(not outside and outside_why=="outside-native-pole-supply-area",
 "same electric network ID made an out-of-range pole a local supply point")
pole.position={x=19.5,y=0.5}
pole.force=enemy
local foreign,foreign_why=A.real_pole_covers(pole,engine)
assert(not foreign and foreign_why=="invalid-or-foreign-physical-pole",
 "another force's pole was accepted as native station distribution")
pole.force=force
pole.surface={index=2}
local other_surface=A.real_pole_covers(pole,engine)
assert(not other_surface,"cross-surface pole was accepted")
pole.surface=surface
pole.prototype.supply_area_distance=nil
local missing_proto=A.real_pole_covers(pole,engine)
assert(not missing_proto,"unknown prototype coverage became a connection")
pole.prototype.supply_area_distance=2.5
-- Old pure-Lua fixtures do not expose Factorio's connection method. They may
-- still use geometry to test planning, but that result never credits energy.
engine.is_connected_to_electric_network=nil
engine.electric_network_id=nil
local mock,mock_reason=A.real_pole_covers(pole,engine)
assert(mock and mock_reason=="legacy-mock-geometric-coverage-only"
 and engine.energy_generated_last_tick==0,
 "source-only legacy fixture incorrectly simulated power production")
assert(not A.coverage_at({x=19.5,y=0.5},engine,nil)
 and A.network_id(station)==nil,
 "unobservable prototype range or unrelated station yielded electric proof")
print("[native-electric-authority-1263] PASS native network identity, absent/mismatched networks, footprint, prototype ranges, foreign force/surface, zero synthetic power")
