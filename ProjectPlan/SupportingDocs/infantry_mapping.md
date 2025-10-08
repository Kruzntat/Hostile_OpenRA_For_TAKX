# Infantry Mapping (J4-M0)

Source of truth: `OpenRA/mods/ra/rules/defaults.yaml` under `^Infantry -> CoTInfantryEmitter`.

- __CoT Type__: proposed per-actor CoT `type` value (`ActorDamageSymbols.<Actor>.Default`).
- __2525C IDs__: MIL-STD-2525 identifiers per state from `ActorDamageMilsymIds`.
- __Damaged__ in this table corresponds to `Default` in `ActorDamageMilsymIds`.

| Actor | Name | CoT Type | 2525C Undamaged | 2525C Damaged | 2525C Critical | 2525C Dead |
|---|---|---|---|---|---|---|
| E1 | Rifleman | a-f-G-E-W-R-R | SFGCEWRR--***** | SFGDEWRR--***** | SFGXEWRR--***** | SFGXEWRR--***** |
| E2 | Grenadier | a-f-G-E-W-Z-L | SFGCEWZL--***** | SFGDEWZL--***** | SFGXEWZL--***** | SFGXEWZL--***** |
| E3 | RocketSoldier | a-f-G-E-W-S-L | SFGCEWSL--***** | SFGDEWSL--***** | SFGXEWSL--***** | SFGXEWSL--***** |
| E4 | Flamethrower | a-f-G-E-X-F | SFGCEXF---***** | SFGDEXF---***** | SFGXEXF---***** | SFGXEXF---***** |
| E6 | Engineer | a-f-G-U-C-E | SFGCUCE---***** | SFGDUCE---***** | SFGXUCE---***** | SFGXUCE---***** |
| SPY | Spy | no-defined-type | OFOCS-----***** | OFODS-----***** | OFOXS-----***** | OFOXS-----***** |
| E7 | Commando | a-f-F-G-S | SFFCGS----***** | SFFDGS----***** | SFFXGS----***** | SFFXGS----***** |
| MEDI | Medic | a-f-G-U-S-M | SFGCUSM---***** | SFGDUSM---***** | SFGXUSM---***** | SFGXUSM---***** |
| MECH | Mechanic | a-f-G-E-V-E | SFGCEVE---***** | SFGDEVE---***** | SFGXEVE---***** | SFGXEVE---***** |
| THF | Thief | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| SHOK | ShockTrooper | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| DOG | Dog | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| Zombie | Zombie | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| Ant | Ant | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| FireAnt | FireAnt | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| ScoutAnt | ScoutAnt | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |
| WarriorAnt | WarriorAnt | a-f-G-U-C-I | SFGCUCI-------- | SFGDUCI-------- | SFGXUCI-------- | SFGXUCI-------- |

Notes:
- __SPY__: CoT Type is currently `no-defined-type` in the rules. If desired, update to a specific CoT `type`.
- Civilians (`^CivInfantry`) are excluded from CoT per `defaults.yaml`.
