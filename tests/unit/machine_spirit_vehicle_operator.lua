-- Native Factorio driver identity contract; no game process or scheduler.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Operator=require("scripts.core.consecration.vehicle_operator")
local reads=0
local driver=nil
local e={valid=true}
function e.get_driver() reads=reads+1; return driver end
local passenger={object_name="LuaPlayer",valid=true,connected=true,vehicle=e}
local driver_player={object_name="LuaPlayer",valid=true,connected=true,vehicle=e}
-- A seated passenger is not an operator when the engine reports no driver.
assert(Operator.get_player(e,{passenger})==nil and reads==1,"passenger mistaken for driver")
-- A native LuaPlayer driver never requires scanning connected players.
driver=driver_player
local poison=setmetatable({}, {__pairs=function() error("player scan on direct driver") end})
assert(Operator.get_player(e,poison)==driver_player,"direct driver not returned")
-- A player can be driving with a character LuaEntity instead of LuaPlayer.
local character={object_name="LuaEntity",valid=true}
driver=character
driver_player.character=character
assert(Operator.get_player(e,{passenger,driver_player})==driver_player,
  "character-backed driver identity lost")
-- A separate non-player occupant must not select a co-seated passenger.
driver={object_name="LuaEntity",valid=true}
assert(Operator.get_player(e,{passenger,driver_player})==nil,
  "non-player driver mistaken for a player passenger")
-- Disconnected and invalid players are not eligible for ejection.
driver=driver_player
driver_player.connected=false
assert(Operator.get_player(e,{driver_player})==nil,"disconnected player returned")
driver_player.connected=true
driver_player.vehicle={valid=true}
assert(Operator.get_player(e,{driver_player})==nil,"driver from another vehicle returned")
driver_player.vehicle=e
-- Native lookup failure must fail closed rather than guess from passengers.
e.get_driver=function() error("driver API unavailable") end
assert(Operator.get_player(e,{passenger,driver_player})==nil,"failed driver query guessed a passenger")
assert(Operator.get_player({valid=false}, {driver_player})==nil,"invalid entity accepted")
assert(Operator.get_player(nil, {driver_player})==nil,"nil vehicle accepted")
print("[machine-spirit-vehicle-operator] PASS native driver, player/character, passengers, disconnected, query failure")
