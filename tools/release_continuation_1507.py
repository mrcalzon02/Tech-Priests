#!/usr/bin/env python3
"""Exact 1.0.3 source packaging using the existing functional release gate."""
import os
import release_unit_hotfix as release

SOURCE = "ec9d26ffe7fe06c320b76409638998e37ec4072e"
release.BASE_VERSION = "1.0.2"
release.BASE_COMMIT = "665d421020d248098ac6b3a130c0c155f1c4fcda"
release.BASE_TAG = "v1.0.2"
release.BASE_ASSET_ID = 792066885
release.BASE_BYTES = 251023485
release.BASE_SHA256 = "e7e2eacba450bdaae63e8c402bf2f073252a91b95c9590246714585d8c672125"
release.RELEASES["unit"] = {
    "version": "1.0.3", "slug": "continuation", "engine": "2.1.25",
    "title": "bounded factory planning and character movement fixes",
    "changes": [
        "Spread factory planning, placement searches and final live checks over deterministic saved work batches.",
        "Share the force planning queue across ordinary construction, shortage, infrastructure and defense planning.",
        "Retain traversable crossing knowledge with local invalidation and native movement fallback.",
        "Restore cosmetic character selection, native Engineer movement and switching back to the Engineer.",
        "Preserve the standard graphics package, existing optional HD companions and unit pickup corrections.",
    ],
}
release.source_commit = lambda: SOURCE

if __name__ == "__main__":
    if os.environ.get("TP_RELEASE_SOURCE_SHA") != SOURCE:
        raise SystemExit("Exact approved source is required")
    raise SystemExit(release.main())
