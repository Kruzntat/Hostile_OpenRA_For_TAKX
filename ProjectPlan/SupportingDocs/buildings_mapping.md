# Building CoT Mapping (RA)

Source of truth: `OpenRA/mods/ra/rules/defaults.yaml` → `^BasicBuilding.CoTBuildingEmitter`

Notes:
- CoT type comes from `ActorSymbols[Actor]` (falls back to `CotType`).
- MIL-STD-2525 ID comes from `ActorMilsymIds[Actor]` (damage-state-specific from `ActorDamageMilsymIds[Actor][State]`).
- Current placeholders: per-actor 2525 IDs as defined in `ActorMilsymIds` (see below).

## Table

| Actor | Callsign | CoT Type | 2525 (default) |
|---|---|---|---|
| POWR | Power | a-f-G-I-U-E | SFGPIUE---H---- |
| APWR | AdvPower | a-f-G-I-U-E-N | SFGPIUEN--H---- |
| PROC | Refinery | a-f-G-I-R-M | SFGPIRM---H---- |
| WEAP | WarFactory | a-f-G-U-C-I-M | SFGPUCIM------- |
| DOME | RadarDome | a-f-G-U-C-F-T-R | SFGPUCFTR------ |
| HQ | HQ | a-f-G-U-H | SFGPUH--------- |
| BARR | BarracksSoviet | a-f-G-I-P | SFGPIP----H---- |
| TENT | BarracksAllied | a-n-G-I-P | SNGPIP----H---- |
| SYRD | NavalYardSoviet | a-f-G-I-B-N | SFGPIBN---H---- |
| SPEN | NavalYardAllied | a-n-G-I-B-N | SFGPUCF----- |
| FIX | ServiceDepot | a-f-G-I-T | SFGPIT----H---- |
| HPAD | Helipad | no-defined-type | SFGPUCVV------- |
| ATEK | TechCenterAllied | a-f-G-I-U-R | SFGPUCF----- |
| STEK | TechCenterSoviet | a-n-G-I-U-R | SFGPIUR---H---- |

## Next steps
- Replace placeholder 2525 IDs with your final MIL-STD-2525C codes per actor (and per damage state if desired).
- Optionally set a valid CoT type for `HPAD` (currently `no-defined-type`).
