-- Existing local faction production restrictions, retained for armory recipes.
for _,faction in ipairs({"mechanicus","astra-militarum","sororitas"}) do
 data:extend{{type="bool-setting",name="tech-priests-combat-allow-"..faction,
  setting_type="startup",default_value=true,order="z-combat-"..faction}}
end
