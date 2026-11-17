local function icon(kind,name,image)
 local p=data.raw[kind] and data.raw[kind][name];if p then p.icon='__tech-priests__/hydrogen/icons/'..image..'.png';p.icon_size=64;p.icons=nil end
end
for name,image in pairs({['tp-mh7-review-purified-water']='purified-water',['tp-mh7-review-hydrogen-gas']='hydrogen-gas',['tp-mh7-review-oxygen-gas']='oxygen-gas',['tp-mh7-review-compressed-hydrogen']='compressed-hydrogen'}) do icon('fluid',name,image) end
for _,group in ipairs{'raw','forged'} do for i,suffix in ipairs{'','-waning','-degraded','-critical'} do icon('item-with-tags','tp-mh7-'..group..'-metallicized-pellet'..suffix,({'pellet-fresh','pellet-waning','pellet-degraded','pellet-critical'})[i]) end end
icon('item','tp-mh7-inert-pellet','pellet-inert');icon('item','tp-mh7-empty-pressure-shell','empty-pressure-shell');icon('item-with-tags','tp-mh7-contained-metallicized-pellet','charged-fuel-canister')
