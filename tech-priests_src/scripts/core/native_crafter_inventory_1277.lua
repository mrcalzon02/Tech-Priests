-- Factorio 2.1 renamed assembler and furnace inventory identifiers.
-- Always resolve the actual native enum, never infer numeric indices.
local M={}
local fallback={
 input={"assembling_machine_input","furnace_source","rocket_silo_input"},
 output={"assembling_machine_output","furnace_result","rocket_silo_output"},
 modules={"assembling_machine_modules","furnace_modules","rocket_silo_modules"},
 trash={"assembling_machine_trash","furnace_trash"},
}
function M.index(inventory,role)
 if type(inventory)~="table" or not fallback[role] then return nil end
 local modern=inventory["crafter_"..role]
 if type(modern)=="number" then return modern end
 for _,old in ipairs(fallback[role]) do
   local id=inventory[old]
   if type(id)=="number" then return id end
 end
 return nil
end
return M
