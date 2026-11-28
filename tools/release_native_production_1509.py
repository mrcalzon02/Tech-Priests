#!/usr/bin/env python3
"""Owner-authorized native Engineer and production UI hotfix; exact archive gate."""
import os
import time
import release_unit_hotfix as release

SOURCE = "fa235434452c70c3ce18bcd7d041327cac7e7700"
release.BASE_VERSION = "1.0.3"
release.BASE_COMMIT = "ec9d26ffe7fe06c320b76409638998e37ec4072e"
release.BASE_TAG = "v1.0.3"
release.BASE_ASSET_ID = 803382207
release.BASE_BYTES = 251136228
release.BASE_SHA256 = "bf8be0c18995ece757d0092f2d3ef79860170c762295d31f1e45275feaa3c2e3"
release.RELEASES["unit"] = {
    "version": "1.0.4", "slug": "native-production", "engine": "2.1.25",
    "title": "native Engineer and plasma production recipe selectors",
    "changes": [
        "Keep the intrinsic Engineer visible, with no automatic character skin selection.",
        "Allow explicit custom graphical overlays without replacing the physical player.",
        "Use standard selectable crafting recipes and native inventory interfaces throughout all seven metallicized-hydrogen production machines.",
        "Provide real forge and sealing recipes for each pellet decay stage; preserve material ratios, power requirements and canister fuel value.",
        "Recover existing privately held pellet stock during configuration migration.",
        "Preserve the standard graphics distribution and optional HD companions.",
    ],
}
release.source_commit = lambda: SOURCE

if __name__ == "__main__":
    if os.environ.get("TP_RELEASE_SOURCE_SHA") != SOURCE:
        raise SystemExit("Exact approved source is required")
    # Use fresh public-listing reads for the existing update publisher. Its
    # previous upload was accepted but the cached listing did not reflect it.
    import sys
    if len(sys.argv)>1 and sys.argv[1]=="publish":
        import publish_hd_mods as portal
        def fresh_listing(name):
            if name!="tech-priests":
                raise ValueError("Only the approved existing mod may be updated")
            # Query both documented listing shapes if the full response has
            # not reflected the update; verify owner/identity on every read.
            observed=None
            for suffix in ("/full", ""):
                try:
                    result=portal.request(portal.BASE+"/api/mods/"+name+suffix+"?tp_readback="+str(time.time_ns()))
                except portal.PortalError as exc:
                    if exc.status==404:
                        continue
                    raise
                if result.get("name")!=name or result.get("owner","").casefold()!=portal.OWNER.casefold():
                    raise ValueError("Mod Portal owner/identity mismatch")
                observed=result
                versions=[x.get("version") for x in result.get("releases",[])]
                print("TP_104_PORTAL_OBSERVED_VERSIONS",versions[-12:],flush=True)
                if "1.0.4" in versions:
                    return result
            return observed
        portal.listing=fresh_listing
    raise SystemExit(release.main())
