-- Read-only identity proof for a recipe-fanout assignment already adopted
-- by the queue and subsequently given a canonical infrastructure recipe.
local M={}
function M.matches(pair,order,production)
  return type(production)=="table"and production.infrastructure_first_0640==true
    and(production.strict_recipe_0647==true or production.facility_only_0647==true)
    and type(order)=="table"and order.status=="active"
    and order.kind=="assignment"and order.source=="adopt-active"
    and order.purpose=="recipe-fanout"and order.task~=nil
    and(order.task==pair.active_task or order.task==pair.active_task_0285)
    and order.item==(production.output_item or production.item_name)
end
return M
