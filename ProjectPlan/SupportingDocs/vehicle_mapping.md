# RA Vehicle to 2525C Mapping (J5-M0 Skeleton)

This document lists all RA vehicles defined in `OpenRA/mods/ra/rules/vehicles.yaml` that inherit from the vehicle archetypes and provides a skeleton mapping to placeholder 2525C symbol IDs. Classifications are approximate and for planning only.

Notes:
- Placeholder 2525C ID uses the current default `a-f-G-U-C` until QA confirms per-vehicle symbols.
- After QA review, update the CotType per actor in YAML or via `ActorSymbols` mapping in `CoTVehicleEmitter`.

## Vehicles

| Actor | Name | CoT Type | 2525C Undamaged | 2525C Damaged | 2525C Critical | 2525C Dead |
|---|---|---|---|---|---|---|
| V2RL | Artillery (Rocket) | a-f-G-U-C-F | SFGCUCF---***** | SFGDUCF---***** | SFGXUCF---***** | SFGXUCF---***** |
| 1TNK | Tank (Light) | a-f-G-E-V-A-T | SFGCEVAT--***** | SFGDGVAT--***** | SFGXGVAT--***** | SFGXGVAT--***** |
| 2TNK | Tank (Medium) | a-f-G-E-V-A-T-L | SFGCEVATL-***** | SFGDGVATL-***** | SFGXGVATL-***** | SFGXGVATL-***** |
| 3TNK | Tank (Heavy) | a-f-G-E-V-A-T-M | SFGCEVATM-***** | SFGDGVATM-***** | SFGXGVATM-***** | SFGXGVATM-***** |
| 4TNK | Tank (Super-Heavy) | a-f-G-E-V-A-T-H | SFGCEVATH-***** | SFGDGVATH-***** | SFGXGVATH-***** | SFGXGVATH-***** |
| ARTY | Artillery | a-f-G-U-C-F | SFGCUCF---***** | SFGDUCF---***** | SFGXUCF---***** | SFGXUCF---***** |
| HARV | Support (Harvester) | a-f-G-U-U |  SFGCUU----***** | SFGDUU----***** | SFGXUU----***** | SFGXUU----***** |
| MCV | Support (MCV) | a-f-F-B | SFFCB-----***** | SFFDB-----***** | SFFXB-----***** | SFFXB-----***** |
| JEEP | Jeep / Recon | a-f-G-U-C-R-X | SFGCUCRX--***** | SFGDUCRX--***** | SFGXUCRX--***** | SFGXUCRX--***** |
| APC | APC (Infantry Carrier) | a-f-G-U-S-T | SFGCUST---***** | SFGDUST---***** | SFGXUST---***** | SFGXUST---***** |
| MNLY | Support (Minelayer) | a-f-G-E-V-E-M | SFGCEVEM--***** | SFGDVEM--***** | SFGXVEM--***** | SFGXVEM--***** |
| TRUK | Support (Truck) | a-f-G-E-V-U-X | SFGCEVUX--***** | SFGDVUX--***** | SFGXVUX--***** | SFGXVUX--***** |
| MGG | Support (Gap Generator) | a-f-G-U-U-M-S-E-J-*-*-*-*-* | SFGCUUMSEJ***** | SFGDUUMSEJ***** | SFGXUMSEJ***** | SFGXUMSEJ***** |
| MRJ | Support (Jammer/EW) | a-f-G-U-U-M-S-E-J-*-*-*-*-* | SFGCUUMSEJ***** | SFGDUUMSEJ***** | SFGXUMSEJ***** | SFGXUMSEJ***** |
| TTNK | Tank (Tesla) | a-f-G-U-U-M-S-E | SFGCUUMSE-***** | SFGDUUMSE-***** | SFGXUMSE-***** | SFGXUMSE-***** |
| FTRK | Anti-Air (Flak Truck) | a-f-G-U-C | IFGCSRAA---***** | IFGDRAA---***** | IFGXRAA---***** | IFGXRAA---***** |
| DTRK | Special (Demolition) | a-f-F-N-U | SFFCNU----***** | SFFDNU----***** | SFFXNU----***** | SFFXNU----***** |
| CTNK | Tank (Chrono) | a-f-G-E-V-A-T | SFGCEVAT--***** | SFGDVAT--***** | SFGXVAT--***** | SFGXVAT--***** |
| QTNK | Special (MAD Tank) | a-f-F-G | SFFCG-----***** | SFFDG-----***** | SFFXG-----***** | SFFXG-----***** |
| STNK | Tank (Stealth) | a-f-G-U-C | EFOCDLB---***** | EFODLB----***** | EFOXLB----***** | EFOXLB----***** |

## Next Steps
- Replace placeholders with QA-approved 2525C IDs per vehicle.
- If callsigns differ per vehicle, record them and add `Callsign` overrides in `vehicles.yaml` under `CoTVehicleEmitter@vehicle`.
- Validate CoT outputs align with the mapping during test runs.
