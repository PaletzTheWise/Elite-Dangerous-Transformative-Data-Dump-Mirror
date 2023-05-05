# Elite-Dangerous-Transformative-Data-Dump-Mirror

This primarily Haxe/php library for transforming and then mirroring data from various data dumps like https://www.edsm.net/en_GB/nightly-dumps and https://spansh.co.uk/dumps.

The mirror accepts arbitrary trasformation function and includes two examples:
 * id           - no transformation, just mirror the file as-is
 * EDSM to EDDB - a rudimentary translation from EDSM systemsPopulated.json.gz to what eddb.io systems_populated/stations/factions json dumps used to look like. This might be useful to people who wrote algorithms running on the dumps from the now defunct eddb.io.
 
The Haxe code transpiles into php, which might be useable as a php library (see releases). The EDSM to EDDB translator is pure haxe, so it can be used on any Haxe target.

Depending on data dump size, transformation complexity, and the runtime environment, php execution time limit may become a problem. The EDSM to EDDB transformation takes tens of seconds.

# Disclaimer

This repository is not affiliated with Frontier Developments.

Elite Dangerous © 1984 - 2023 Frontier Developments Plc. All rights reserved. 'Elite', the Elite logo, the Elite Dangerous logo, 'Frontier' and the Frontier logo are registered trademarks of Frontier Developments plc.
