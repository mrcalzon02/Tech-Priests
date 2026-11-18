"""Generate native combat identity/stats from the canonical weapon/ammo catalog.

Economics and initial balance below are explicit gameplay choices, not lore stats.
Run from any directory; output is deterministic. No copied third-party code.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'


# HP, range, cooldown ticks, damage/shot, speed, unit-specific unlock.
STATS = {
 'skitarii-ranger': (200, 24, 60, 28, .12, None),
 'guardsman': (150, 17, 30, 12, .13, 'guard-muster'),
 'enginseer': (400, 1.8, 60, 60, .12, 'enginseer-initiation'),
 'imperial-officer': (200, 13, 36, 17, .14, 'officer-corps'),
 'lord-commissar': (350, 15, 48, 45, .13, 'commissariat'),
 'skitarii-vanguard': (225, 16, 15, 18, .13, 'vanguard-cohorts'),
 'skitarii-marshal': (500, 18, 30, 36, .13, 'skitarii-command'),
 'datasmith': (650, 15, 48, 70, .11, 'cybernetica-protocols'),
 'battle-sister': (300, 22, 24, 40, .12, 'militant-orders'),
 'dialogus': (350, 1.8, 60, 45, .12, 'sacred-liturgies'),
 'canoness': (700, 24, 36, 70, .13, 'canoness-command'),
 'manipulus': (850, 32, 90, 180, .10, 'galvanic-mastery'),
 'dominus': (1200, 26, 30, 100, .10, 'dominus-ascension'),
 'kataphron-breacher': (1400, 24, 60, 200, .08, 'heavy-servitor-chassis'),
 'kataphron-destroyer': (1100, 30, 36, 180, .075, 'grav-annihilation'),
}
# Inputs per batch; all ammo and movement fuel are physically finite.
AMMO = {
 'galvanic': ([['iron-plate',2],['copper-plate',1]],5,20,'physical'),
 'las': ([['iron-plate',1],['copper-plate',2],['electronic-circuit',1]],5,30,'laser'),
 'induction': ([['copper-plate',2],['electronic-circuit',1]],5,12,'physical'),
 'bolt': ([['piercing-rounds-magazine',2],['steel-plate',2],['explosives',1]],4,16,'physical'),
 'radium': ([['iron-plate',2],['copper-plate',1],['uranium-238',1]],10,24,'poison'),
 'gamma': ([['battery',2],['advanced-circuit',1]],5,16,'laser'),
 'magnarail': ([['steel-plate',2],['battery',1],['advanced-circuit',2]],5,10,'physical'),
 'volkite': ([['battery',4],['processing-unit',1],['copper-plate',4]],5,20,'laser'),
 'arc': ([['battery',2],['processing-unit',1]],5,10,'electric'),
 'graviton': ([['battery',4],['processing-unit',2],['low-density-structure',2]],5,12,'physical'),
}
TECHS = {
 'enginseer-initiation': (['automation','steel-processing'],75,'R'),
 'officer-corps': (['tech-priests-guard-muster','logistics'],100,'RG'),
 'bolt-armaments': (['military-2','steel-processing','explosives'],100,'RGM'),
 'commissariat': (['tech-priests-officer-corps','tech-priests-bolt-armaments'],150,'RGM'),
 'radium-armaments': (['chemical-science-pack','uranium-processing'],150,'RGMB'),
 'vanguard-cohorts': (['tech-priests-radium-armaments','tech-priests-enginseer-initiation','battery'],150,'RGMB'),
 'skitarii-command': (['tech-priests-vanguard-cohorts'],250,'RGMB'),
 'cybernetica-protocols': (['tech-priests-enginseer-initiation','chemical-science-pack','battery','advanced-circuit'],250,'RGMB'),
 'sacred-liturgies': (['tech-priests-militant-orders','tech-priests-enginseer-initiation'],200,'RGMB'),
 'canoness-command': (['tech-priests-militant-orders','tech-priests-sacred-liturgies'],350,'RGMB'),
 'galvanic-mastery': (['tech-priests-cybernetica-protocols','production-science-pack','electric-engine','processing-unit'],500,'RGMBP'),
 'dominus-ascension': (['tech-priests-galvanic-mastery','utility-science-pack','processing-unit'],750,'RGMBPY'),
 'heavy-servitor-chassis': (['tech-priests-galvanic-mastery','utility-science-pack','electric-engine'],750,'RGMBPY'),
 'grav-annihilation': (['tech-priests-heavy-servitor-chassis','tech-priests-dominus-ascension','low-density-structure'],1500,'RGMBPY'),
}
AMMO_TECH = {'las':'guard-muster','induction':'enginseer-initiation','bolt':'bolt-armaments',
             'radium':'radium-armaments','gamma':'cybernetica-protocols','magnarail':'galvanic-mastery',
             'volkite':'dominus-ascension','arc':'heavy-servitor-chassis','graviton':'grav-annihilation'}


def main():
    design = json.loads((ROOT/'docs/data/combat-weapons-and-ammunition.json').read_text())
    result = {'units':[], 'ammo':{}, 'technologies':{}}
    for family, identity in design['ammo_families'].items():
        inputs, count, shots, damage_type = AMMO[family]
        result['ammo'][family] = {'name':identity['item_prototype_proposed'], 'label':identity['display_name'],
                                  'ingredients':inputs, 'count':count, 'shots':shots, 'damage_type':damage_type,
                                  'technology':'tech-priests-'+AMMO_TECH[family] if family in AMMO_TECH else None}
    for row in design['units']:
        ident = row['appearance_id']
        hp, reach, cooldown, damage, speed, tech = STATS[ident]
        stage = row['stage']
        # Increasing industrial bills; every actor consumes its own weapon item.
        weapon_bill = [['iron-plate',10],['copper-plate',5],['iron-gear-wheel',2],['electronic-circuit',1]]
        body = [['iron-plate',15],['copper-plate',5],['electronic-circuit',3]]
        if ident=='guardsman':
            weapon_bill=[['iron-plate',6],['copper-plate',3],['electronic-circuit',1]]
            body=[['iron-plate',10],['copper-plate',3]]
        elif stage>=1:
            weapon_bill=[['steel-plate',3+stage*2],['copper-plate',4+stage*2],['electronic-circuit',2+stage]]
            body=[['steel-plate',5+stage*4],['iron-gear-wheel',3+stage],['electronic-circuit',3+stage*2]]
        if stage>=3:
            weapon_bill += [['battery',stage*2],['advanced-circuit',stage]]
            body += [['advanced-circuit',stage*2],['engine-unit',stage]]
        if stage>=4:
            body += [['electric-engine-unit',stage],['processing-unit',stage]]
        if stage>=5:
            weapon_bill += [['processing-unit',5],['low-density-structure',5]]
            body += [['low-density-structure',10]]
        result['units'].append({'id':ident, 'label':row['unit_name'], 'name':row['combat_entity_prototype_proposed'],
          'faction':row['faction'], 'stage':stage, 'health':hp, 'range':reach, 'cooldown':cooldown,
          'damage':damage, 'speed':speed, 'weapon':row['weapon_prototype_proposed'],
          'weapon_label':row['weapon_name'], 'ammo_family':row['ammo_family'],
          'melee':row['attack_kind']=='melee', 'technology':'tech-priests-'+tech if tech else None,
          'weapon_ingredients':weapon_bill, 'ingredients':[[row['weapon_prototype_proposed'],1]]+body})
    for ident, (prereq,count,packs) in TECHS.items():
        result['technologies']['tech-priests-'+ident]={'prerequisites':prereq,'count':count,'packs':packs}
    target=ROOT/'tech-priests_src/shared/combat_roster_catalog.lua'
    target.write_text('-- Generated by tools/generate_combat_roster.py; canonical identity: docs/data/combat-weapons-and-ammunition.json\n'
                      '-- Initial gameplay balance; native AAI owns movement, targeting and shooting.\nlocal M='+lua(result)+'''
M.by_id={}; M.by_name={}
for _,u in ipairs(M.units) do M.by_id[u.id]=u;M.by_name[u.name]=u end
function M.for_entity_name(name)
 local base=name:match("^(.-)%-_%-") or name
 return M.by_name[base]
end
return M
''', encoding='utf-8')
    print('Generated 15 units, ten finite ammunition families and research/economic definitions.')


if __name__=='__main__': main()
