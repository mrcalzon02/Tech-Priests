-- Reviewed actual 3D item renders, canonical FMPL camera and owner-selected pose C.
-- Artwork only; weapon behavior, recipe inputs and science unlocks are unchanged.
local rows={
 {"gun","tech-priests-galvanic-rifle","galvanic-rifle"},
 {"gun","tech-priests-lasgun","lasgun"},
 {"gun","tech-priests-omnissian-axe","power-axe"},
 {"gun","tech-priests-laspistol","laspistol"},
 {"gun","tech-priests-bolt-pistol","bolt-pistol"},
 {"gun","tech-priests-radium-carbine","radium-carbine"},
 {"gun","tech-priests-radium-serpenta","radium-serpenta"},
 {"gun","tech-priests-gamma-pistol","gamma-pistol"},
 {"gun","tech-priests-boltgun","boltgun"},
 {"gun","tech-priests-dialogus-staff","dialogus-staff"},
 {"gun","tech-priests-condemnor-boltgun","condemnor-boltgun"},
 {"gun","tech-priests-magnarail-lance","magnarail-lance"},
 {"gun","tech-priests-volkite-blaster","volkite-blaster"},
 {"gun","tech-priests-heavy-arc-rifle","heavy-arc-rifle"},
 {"gun","tech-priests-heavy-grav-cannon","heavy-grav-cannon"},
 {"ammo","tech-priests-galvanic-clip","galvanic-clips"},
 {"ammo","tech-priests-las-charge-cell","las-charge-cells"},
 {"ammo","tech-priests-induction-charge","tool-charges"},
 {"ammo","tech-priests-bolt-magazine","bolt-magazines"},
 {"ammo","tech-priests-radium-magazine","radium-magazines"},
 {"ammo","tech-priests-gamma-cell","gamma-cells"},
 {"ammo","tech-priests-magnarail-slug-pack","magnarail-slug-packs"},
 {"ammo","tech-priests-volkite-cell","volkite-cells"},
 {"ammo","tech-priests-heavy-arc-cell","heavy-arc-cells"},
 {"ammo","tech-priests-graviton-charge","graviton-charges"},
}
for _,row in ipairs(rows) do
 local p=assert(data.raw[row[1]] and data.raw[row[1]][row[2]],"Missing agreed weapon/supply "..row[2])
 p.icon="__tech-priests__/graphics/icons/unit-arsenal-v02/"..row[3]..".png"
 p.icon_size=64;p.icons=nil;p.icon_mipmaps=nil
end
