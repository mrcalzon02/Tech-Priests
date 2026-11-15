-- Appended inside the forge controller, retaining its original job state.
local slots={};for i=1,8 do slots[#slots+1]=i end
require('stock-access').bind(F,function(e)return state()[e.unit_number] end,{
 slots=slots,touch=D.touch_stack,accepts=function(s)return D.is_raw(s) or s.name==c.inert end,
 input_hint='Load raw metallicized pellets. Spent pellets may be returned as inert material.',
 group=function(i)if i>=1 and i<=8 then return 'Input' end end,
 locked=function(job,i)return job.in_flight and job.active_slot==i or false end,
})
