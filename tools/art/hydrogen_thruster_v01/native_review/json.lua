local function json(value)
 if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)=='nil' then return 'null' end
 local fields={}
 if #value>0 then for i=1,#value do fields[#fields+1]=json(value[i]) end;return '['..table.concat(fields,',')..']' end
 for k,v in pairs(value) do fields[#fields+1]=json(tostring(k))..':'..json(v) end;table.sort(fields);return '{'..table.concat(fields,',')..'}'
end
