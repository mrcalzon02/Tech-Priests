-- Native recipe identity is shared by prototype, runtime and tests.
local M={}
M.technology="tp-metallicized-hydrogen-production"
M.suffixes={"fresh","waning","degraded","critical"}
M.machines={
 {name="tp-mh7-review-purifier",recipes={"tp-mh7-review-purify"}},
 {name="tp-mh7-review-electrolyzer",recipes={"tp-mh7-review-electrolyze"}},
 {name="tp-mh7-review-compressor",recipes={"tp-mh7-review-compress"}},
 {name="tp-mh7-review-crucible",recipes={"tp-mh7-review-metallize"}},
 {name="tp-mh7-review-forge",recipes={}},
 {name="tp-mh7-review-fabricator",recipes={"tp-mh7-review-hydroform"}},
 {name="tp-mh7-canister-assembler",recipes={}},
}
M.by_name={}
M.recipe_machine={}
for _,suffix in ipairs(M.suffixes) do
 table.insert(M.machines[5].recipes,"tp-mh7-native-forge-"..suffix)
 table.insert(M.machines[7].recipes,"tp-mh7-native-seal-"..suffix)
end
for _,m in ipairs(M.machines) do
 M.by_name[m.name]=m
 for _,id in ipairs(m.recipes) do M.recipe_machine[id]=m.name end
end
function M.legacy_recipe(name)
 return type(name)=="string" and
  (name:match("^tp%-mh7%-review%-forge%-") or name:match("^tp%-mh7%-assembler%-"))~=nil
end
function M.private_item(name)
 return type(name)=="string" and
  (name:match("^tp%-mh7%-forge%-cycle%-")~=nil or name:match("^tp%-mh7%-assembler%-cycle%-")~=nil
   or name=="tp-mh7-forge-accept-guard" or name=="tp-mh7-assembler-accept-guard")
end
return M
