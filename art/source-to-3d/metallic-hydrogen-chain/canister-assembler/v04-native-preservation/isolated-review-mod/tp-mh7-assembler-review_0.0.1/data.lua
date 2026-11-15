-- Isolated fixture only; never included in the production assembler mod.
local spec=require('__tp-mh7-assembler__/spec')
local probe=table.deepcopy(data.raw['assembling-machine'][spec.entity]);probe.name='tp-mh7-assembler-clock-probe';probe.minable=nil
data:extend{probe,{type='recipe',name='tp-mh7-assembler-clock-probe',categories={spec.category},enabled=true,hidden=true,energy_required=16,ingredients={},results={{type='item',name='tp-mh7-assembler-cycle-result',amount=1,independent_probability=0}},preserve_products_in_machine_output=false}}
