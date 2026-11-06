-- Factorio 2.1 renamed assembler and furnace inventory identifiers.
-- Always resolve the actual native enum, never infer numeric indices.
local M={}
local fallback={
 input={"assembling_machine_input","furnace_source","rocket_silo_input"},
 output={"assembling_machine_output","furnace_result","rocket_silo_output"},
 modules={"assembling_machine_modules","furnace_modules","rocket_silo_modules"},
 trash={"assembling_machine_trash","furnace_trash"},
}
function M.index(inventory,role,family)
 if type(inventory)~="table" or not fallback[role] then return nil end
 local modern=inventory["crafter_"..role]
 if type(modern)=="number" then return modern end
 -- In 2.0 the assembler and furnace IDs can be distinct; do not
 -- substitute one engine's family identifier for another's inventory.
 local specific=family=="furnace"and ({input="furnace_source",output="furnace_result",modules="furnace_modules",trash="furnace_trash"})[role]
  or family=="assembler"and ({input="assembling_machine_input",output="assembling_machine_output",modules="assembling_machine_modules",trash="assembling_machine_trash"})[role]
  or family=="rocket-silo"and ({input="rocket_silo_input",output="rocket_silo_output",modules="rocket_silo_modules"})[role]
 if specific and type(inventory[specific])=="number" then return inventory[specific] end
 for _,old in ipairs(fallback[role]) do
   local id=inventory[old]
   if type(id)=="number" then return id end
 end
 return nil
end
return M
