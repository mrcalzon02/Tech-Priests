-- Furnaces reject recipes whose item products exceed their output slots,
-- including the probability-zero Detritus product used by consecration.
-- Preserve their original recipe capacity and add only the required waste slot.
return function(furnaces,recipes)
  for _,furnace in pairs(furnaces or {})do
    local capacity=tonumber(furnace.result_inventory_size)or 1
    local supported={}
    for _,category in pairs(furnace.crafting_categories or {})do supported[category]=true end
    local needed=capacity
    for _,recipe in pairs(recipes or {})do
      local fits=supported[recipe.category or "crafting"]
      for _,category in pairs(recipe.categories or {})do fits=fits or supported[category]end
      if fits then
        local items,detritus={},false
        for _,product in pairs(recipe.results or {})do
          if(product.type or "item")=="item"then
            local name=product.name or product[1]
            if name then items[name]=true end
            if name=="mechanical-detritus"and(product.probability==0 or product.independent_probability==0)then detritus=true end
          end
        end
        local count=0;for _ in pairs(items)do count=count+1 end
        if detritus and count-1<=capacity then needed=math.max(needed,count)end
      end
    end
    furnace.result_inventory_size=needed
  end
end
