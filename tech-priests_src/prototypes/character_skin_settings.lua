local Catalog=require("shared.character_skin_catalog")
local definitions={{type="bool-setting",name="tech-priests-character-picker-enabled",setting_type="startup",default_value=true,order="s-skins-a"}}
for index,skin in ipairs(Catalog.skins) do
  definitions[#definitions+1]={type="bool-setting",name="tech-priests-skin-allow-"..skin.id,
    setting_type="startup",default_value=true,order=string.format("s-skins-b-%02d",index),
    localised_name={"tech-priests-skins.allow-skin",skin.label},
    localised_description={"tech-priests-skins.allow-description"}}
end
data:extend(definitions)
