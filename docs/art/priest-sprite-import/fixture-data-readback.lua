local function json(value)
 if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)=='nil' then return 'null' end
 local fields={}
 if #value>0 then for i=1,#value do fields[#fields+1]=json(value[i]) end;return '['..table.concat(fields,',')..']' end
 for k,v in pairs(value) do fields[#fields+1]=json(tostring(k))..':'..json(v) end;table.sort(fields);return '{'..table.concat(fields,',')..'}'
end
local report={mechanicus_version=mods['mechanicus-reborn'] or false,units={},corpses={}}
for name,p in pairs(data.raw.unit) do
 if name:find('tech%-priest') then report.units[#report.units+1]={name=name,run_animation=p.run_animation,attack_animation=p.attack_parameters and p.attack_parameters.animation} end
end
for name,p in pairs(data.raw.corpse) do
 if name:find('tech%-priest') then report.corpses[#report.corpses+1]={name=name,animation=p.animation,decay_animation=p.decay_animation} end
end
table.sort(report.units,function(a,b)return a.name<b.name end);table.sort(report.corpses,function(a,b)return a.name<b.name end)
log('PRIEST_GRAPHICS_JSON '..json(report))
