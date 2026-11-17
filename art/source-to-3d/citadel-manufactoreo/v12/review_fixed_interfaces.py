"""Explicit reviewed interface types, based on the complete V11 inventory.

No name wildcard grants a pass. Every exact normalized pair type must have a
reviewed construction decision; repaired types must be absent from final art.
Raw inventories retain every pair, including intentional fixed engagements.
"""
from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parent;basis=R/'fixed-contact-groups-v11.txt';lines=basis.read_text().splitlines()
rows={int(re.match(r'(\d+)',line)[1]):re.sub(r'^\d+\s+\d+\s+','',line)for line in lines}
decisions={}
def note(ids,kind,reason):
 for i in ids:
  assert i in rows and i not in decisions,(i,rows.get(i))
  decisions[i]={'v11_group':i,'interface':rows[i],'decision':kind,'reason':reason}
def ok(ids,reason):note(ids,'intentional-fixed-interface',reason)
def repair(ids,reason):note(ids,'repair-required-must-be-absent',reason)
repair([33],'Cassette perimeter bolt heads crossed end fins and were not seated on the bare rim. Move the heads to free rim corners and seat their bottoms on the rim top.')
repair([57,137,283],'Duplicate roof-branch collars and the positive-row port corridor interfered with neighbouring clamp heads. Use one collar per row, share the central main clamp, offset collars and route that port around the fasteners.')
repair([83],'Inspection-plug foot heads intersected the independent retained plug body. Enlarge the supporting flange and increase the stud circle, preserving a radial gap to the plug.')
repair([119],'An independently fitted crown cassette rim intersected a neighbouring nave cooling fin. Remove that whole optional cassette mount where the existing roof bank occupies it.')
repair([274,275,276,298],'Optional cast tablets/seals overlapped independent closed service-line entry areas. Remove each whole affected optional relief cell, retaining the complete line and adjacent supported relief.')
repair([299],'An old cartridge face stud overlapped the later harness anchor head at the same fastening site. Retain the harness anchor and remove the redundant old stud.')
repair([305],'A console foot crossed a foundation-anchor head. Set the foot back and narrow it while preserving contact with its shoe and the console casting.')
repair([284,366,367,368],'Facade service-line or saddle crossed an independent armor stud or glazing surround. Space the four lines outside the window frame, bring them forward, and provide founded entry blocks and longer seated saddles.')

ok([1,3,4,6,8,13,17,18,32,34,38,46,59,60,62,64,65,76,99,103,105,106,108,116,191,254,255,256,288,300,331,332,338,369,370],
 'Fixed relief, trim, ribs, retained tablets and their raised traces form joined casting or layered cladding interfaces. The overlapping ends seat the relief/trim on its supporting panel; none is an animated member or an independent service line. Closed hatches and their static locking bars remain closed.')
ok([2,5,9,14,15,19,20,27,28,31,35,37,45,56,58,61,68,75,77,81,82,89,139,147,159,162,164,175,202,224,230,248,249,258,287],
 'Retained fastener to its actual seat, bracket, flange, cover, rib, hinge leaf or joined supporting plate. The head/shaft intentionally engages that support. These are fixed fastenings, not unwanted contact with a moving part or a separate process line.')
ok([10,11,12,16,21,22,23,24,25,26,30,47,63,73,74,78,79,96,100,107,120,121,122,144,170,171],
 'Fixed fitted service-bay construction: formed fins/slats seat in their thermal core/rim, closed caps overlap the vessel end, cradles retain the cap/body, founded posts meet bridges/cores, ties meet their bands and protective grilles seat in the housing. These are declared mounted/retained interfaces, not clearance surfaces.')
ok([29,39,40,41,42,43,87,97,98,115,194,321,322,323,328,329,330,333,334,335],
 'Closed glazing assembly. Lead strips intentionally solder at their crossings and meet the fixed muntins/bars. Blind panes seat in their opaque backing and load-bearing surrounds; overlapping frame/seat layers keep the manufacturing interior closed.')
ok([7,36,44,48,52,53,55,66,67,69,70,71,72,84,85,90,91,92,93,94,95,109,110,111,112,113,114,123,124,125,126,127,128,129,130,131,132,133,134,135,138,140,141,142,143,145,146,149,150,151,152,153,154,189,190,192,193,196,197,198,199,200,201,203,204,205,206,207,208,209,212,214,216,217,218,219,221,225,226,228,229,231,232,233,234,235,240,241,242,243,244,245,246,304,306,307,308,309,310,311,312,313,314,316,317,318,319,320,325,326,327,337],
 'Declared stationary load path or enclosure seam: feet/shoes/cornices/ribs/buttresses and bay supports seat in the cast base or opaque tower/nave. Roof thermal cores and their protective rails are installed into the closed roof/cornice envelope. Layered cladding/supports are intentionally embedded, not separate moving mechanisms. Source construction and front/rear/clay views show these as attached, closed architectural joints.')
ok([49,50,51,80,86,88,101,102,136,166,167,168,169,178,179,180,183,184,185,186,187,195,210,211,213,215,222,223,236,237,238,239,250,251,269,270,271,272,273,279,280,281,282,285,290,291,292,293,294,295,296,297,301,302,303,315,324,345,362,363],
 'Declared closed-service junction or supported termination: tubes enter their own sealed header, cartridge, tower, console or case; collars/clamps/glands retain them and founded brackets attach the service to its host. Opposed branches meet inside their shared closed header. These contacts occur at intentional entries or fitted supports, not at an unrelated visible crossing. No native fluid port or burner is implied.')
ok([54,176,177,181,182,266,289],
 'The service clamp or wall-to-line standoff meets its actual wall shoe, existing column/band or fixed hatch retaining band. This is the bracket load path. The distinct supported tube is still clear except at its declared clamp/gland; the bracket is not an animated link.')
ok([104,117,118,148,155,156,157,158,160,161,163,165,172,173,174,188,220,227,247,252,253,257,265,267,268,286,336],
 'Closed static access/locking assembly: hinge leaves seat on the door/wall around their captured pin; locking guides share retained bands/tablets; the wheel spokes join hub/rim and its shaft engages the fixed gland. Cabinet feet, access panels and lap edges attach to their actual host. These doors/locks are intentionally closed and are not animated travel paths.')
ok([259,260,261,262,263,264,364,365],
 'Fixed fan/instrument support: opaque backplate and annular housing meet their tower backing, the fixed shaft enters its bearing support and its own end retainer, and the dial bearing seats in the fixed bored face. Moving hubs/needle remain separated by their measured bores and axial gaps; full-cycle foreign-moving contact count remains zero.')
ok([277,278,339,340,341,342,343,344,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361],
 'Recovered indexed FMPL console: fixed casting/side extension, overlapping integral button bosses, seated control heads and CRT retaining-edge mitres are the original part assembly. Their local fixed casting/retainer contacts are preserved with provenance. The installed upper source heads are the native wire endpoints; no console element is animated or used as a hidden manufacturing mechanism.')

if __name__=='__main__':
 missing=set(rows)-set(decisions);print('REVIEWED',len(decisions),'MISSING',[(i,rows[i])for i in sorted(missing)])
 (R/'fixed-interface-review-decisions.json').write_text(json.dumps({'basis':'V11 complete fixed-contact inventory, all370 pair types read and reviewed.','source_sha256':'994819cdc6732ef365f56de46d9b1b017e62656462bbc8ae99973d728525d25c','runtime_sha256':'b75bbfa292e9fa0f74c8dcedcca89e2376506d66558c0f67890e0940a8627cc2','decisions':list(decisions.values()),'missing_ids':sorted(missing),'final_candidate_clearance_not_yet_claimed':True},indent=2)+'\n')
