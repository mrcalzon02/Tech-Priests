-- Isolated integration fixture, never shipped inside the normal-game addon.
local supply=table.deepcopy(data.raw['electric-energy-interface']['electric-energy-interface'])
supply.name='tp-hydrogen-fixture-power';supply.energy_production='100MW';supply.energy_usage='0W';supply.energy_source.buffer_capacity='1MJ';supply.energy_source.usage_priority='primary-output';supply.minable=nil
data:extend{supply}
for _,spec in ipairs(require('__tp-hydrogen-production__/specs')) do
 local clone=table.deepcopy(data.raw['assembling-machine'][spec.entity]);clone.name='tp-hydrogen-clock-'..spec.key;clone.minable=nil;clone.fixed_recipe=nil;clone.energy_source={type='void'}
 data:extend{clone,{type='recipe',name=clone.name,categories={spec.category},enabled=true,hidden=true,energy_required=spec.cycle_seconds,ingredients={},results={{type='item',name='tp-mh7-assembler-cycle-result',amount=1,independent_probability=0}},preserve_products_in_machine_output=false}}
end
