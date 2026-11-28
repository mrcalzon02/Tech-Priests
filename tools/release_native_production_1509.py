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
    raise SystemExit(release.main())
