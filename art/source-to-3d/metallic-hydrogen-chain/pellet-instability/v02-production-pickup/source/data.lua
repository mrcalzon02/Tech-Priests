local c=require('config')
local rows={}
for i,stage in ipairs(c.stages) do
 local item=table.deepcopy(data.raw.item['iron-ore'])
 item.type='item-with-tags';item.name=stage.name;item.localised_name=stage.label
 item.localised_description='Uncontained material loses integrity and quality, then becomes inert. Seal in a pressure shell promptly.'
 -- Individual metadata prevents merging or splitting from refreshing a timer.
 item.stack_size=1;item.flags={'not-stackable'}
 item.spoil_ticks=c.interval_max_ticks;item.quality_affects_spoil_ticks=false
 item.spoil_result=c.stages[i+1] and c.stages[i+1].name or c.inert
 item.spoil_quality_change=c.stages[i+1] and -1 or -128
 item.spoil_to_trigger_result={items_per_trigger=1,trigger={type='direct',action_delivery={type='instant',target_effects={{type='script',effect_id='tp-mh7-pellet-decay-'..i}}}}}
 rows[#rows+1]=item
end
local inert=table.deepcopy(data.raw.item.stone);inert.name=c.inert;inert.localised_name='Inert pellet';inert.stack_size=100
inert.localised_description='Spent, non-fuel material. Cannot be restored by containment.'
rows[#rows+1]=inert
local shell=table.deepcopy(data.raw.item['steel-plate']);shell.name=c.shell;shell.localised_name='Empty pressure shell';shell.stack_size=20
rows[#rows+1]=shell
local sealed=table.deepcopy(data.raw.item['uranium-fuel-cell']);sealed.type='item-with-tags';sealed.name=c.contained
sealed.localised_name='Contained metallicized pellet';sealed.localised_description='Sealed containment preserves remaining lifetime, integrity and quality; it does not repair decay.'
sealed.stack_size=1;sealed.flags={'not-stackable'};sealed.fuel_category=nil;sealed.fuel_value=nil;sealed.burnt_result=nil
sealed.fuel_acceleration_multiplier=nil;sealed.fuel_top_speed_multiplier=nil
rows[#rows+1]=sealed
data:extend(rows)
