-- New platforms carry a Void Cogitator as native starter-pack structure.
-- The regular station lifecycle creates its one bound Void Priest.
local pack=data.raw["space-platform-starter-pack"]and data.raw["space-platform-starter-pack"]["space-platform-starter-pack"]
if not(pack and data.raw.container and data.raw.container["void-cogitator-station"])then return end
local function contains(node)
 if type(node)~="table"then return false end
 if node.entity_name=="void-cogitator-station"then return true end
 for _,v in pairs(node)do if type(v)=="table"and contains(v)then return true end end
 return false
end
if contains(pack.trigger)then return end
local triggers=pack.trigger or{}
if triggers.type then triggers={triggers}end
triggers[#triggers+1]={type="direct",action_delivery={type="instant",source_effects={
 {type="create-entity",entity_name="void-cogitator-station",offsets={{6,0}},trigger_created_entity=true}
}}}
pack.trigger=triggers
-- The native hub occupies -4..4. Keep the 2x2 station clear on an attached
-- foundation berth; these tiles are part of the paid starter pack itself.
pack.tiles=pack.tiles or{}
local seen={}
for _,tile in pairs(pack.tiles)do local p=tile.position;seen[(p.x or p[1])..":"..(p.y or p[2])]=true end
for x=5,6 do for y=-1,0 do
 if not seen[x..":"..y]then pack.tiles[#pack.tiles+1]={tile="space-platform-foundation",position={x=x,y=y}}end
end end
