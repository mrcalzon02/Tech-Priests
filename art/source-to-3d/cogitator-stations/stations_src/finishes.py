"""Station finishes. RGB values are sRGB shop colors before field aging."""
# FMPL source profile, finish label, sRGB, metalness, roughness.
FINISHES = {
    'iron': ('steel-hammered', 'Hammered iron', (85,73,57), .72,.52),
    'steel': ('steel-pitted','Exposed steel', (124,119,105), .80,.37),
    'gunmetal': ('steel-burnt','Burnished gunmetal', (76,76,70), .82,.43),
    'dark': ('steel-burnt','Blackened casting', (59,56,53), .56,.59),
    'bronze': ('copper-patina','Cast statuary bronze', (145,108,65), .78,.43),
    'brass': ('brass-machined','Old machined brass', (179,143,84), .80,.38),
    'gold': ('brass-machined','Burnished gilt', (214,169,83), .80,.30),
    'copper': ('copper-patina','Annealed copper', (166,94,55), .76,.42),
    'rust': ('iron-rust','Oxidized iron', (114,63,36), .41,.70),
    'ceramic': ('ceramic-tile','Ivory glazed porcelain', (186,170,133), .08,.28),
    'black': ('steel-burnt','Baked black enamel', (37,40,38), .28,.44),
    'red': ('rubber-industrial','Oxblood cable jacket', (165,45,30), .13,.44),
    'green': ('rubber-industrial','Olive cable jacket', (88,119,45), .12,.43),
    'amber': ('rubber-industrial','Ochre cable jacket', (201,143,37), .14,.43),
    'rubber': ('rubber-industrial','Graphite rubber', (46,48,45), .04,.71),
    'oxide': ('iron-rust','Red oxide enamel', (116,49,33), .38,.53),
    'blue': ('rubber-industrial','Petrol cable jacket', (49,94,100), .15,.46),
}
