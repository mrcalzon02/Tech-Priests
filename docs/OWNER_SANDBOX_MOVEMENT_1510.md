# 1510 owner sandbox movement diagnostic

Input: owner-provided Factorio 2.1.25 / Tech Priests 1.0.4 current log,
all research enabled and additional mods installed. Do not publish the
private logs or crash dump. The current session ended with user quit.

- 14,736 native position discontinuity detections across ten priest identities.
- 13,823 detections separated by five ticks; median apparent displacement
  rate 103.45 tiles/s; maximum five-tick displacement 133.6989257 tiles
  (station 1051, priest 1052, moving-to-scavenge).
- Largest reported sample displacement 950.9510179 tiles over 45 ticks.
- Near tick 122880, stations 991 and 1039 report failed/overleash acquisition
  distances of 968.53 and 951.14 tiles.
- The emergency script-output log contains earlier installs and empty initial
  pair dumps, not the active incident trace. The older minidump is not the
  current sandbox session.

The observations do not establish the first writer of the discontinuities.
Known defects in the canonical controller: sample cleared the request without
stopping native movement, expiry abandoned native commands, recovery used a
potentially unbounded coordinate teleport and reset its sample, active service
and sample restarted at the same prefix. Correct these independent defects
without changing movement prototype speed, research, simulation ticks,
construction scheduling or save custody. Verify a deliberate jump separately
from an actual native reproduction. No release without approval.
