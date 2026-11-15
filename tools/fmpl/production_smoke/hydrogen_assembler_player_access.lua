-- Appended inside the assembler controller; shells in active pairs stay reserved.
local slots={1,2,3,7,8,9};for i=10,24 do slots[#slots+1]=i end
require('stock-access').bind(A,function(e)return state()[e.unit_number] end,{
 slots=slots,touch=touch,accepts=function(s)return formed[s.name] or s.name==c.shell or s.name==c.inert end,
 input_hint='Load formed metallicized pellets and pressure shells.',
 group=function(i)if i>=10 and i<=24 then return 'Input' elseif i>=1 and i<=3 then return 'Processing' elseif i>=7 and i<=9 then return 'Ready' end end,
 locked=function(job,i)
  if not job.in_flight then return false end
  if i>=1 and i<=3 then return true end
  for _,pair in ipairs(job.pairs or {}) do if pair.shell_slot==i then return true end end
  return false
 end,
})
