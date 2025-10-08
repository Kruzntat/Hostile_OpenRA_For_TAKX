# J6 — Aircraft CoT to TAKX (OpenRA)

*Scope: Aircraft units only (fixed‑wing and rotary). Each aircraft instance gets its own CoT lifecycle, air‑specific telemetry (altitude, speed, course), runway/helipad interactions, and keep‑alives. Builds on J2 (Buildings), J3 (Output Selector), J4 (Infantry), and J5 (Vehicles).*

---

## Objectives

* Emit CoT for **every aircraft** produced/spawned in OpenRA.
* Add **air telemetry**:

  * `hae` (height above ellipsoid) or AGL fallback
  * `track` → `speed` (m/s) and `course` (degrees)
* Model **flight phases**: taxi/hover, takeoff, climb, cruise/loiter, attack run, RTB (return to base), approach, landing, parked.
* Provide **unique, stable UIDs**, **callsigns**, and **heartbeats**.
* Map `{Alive, Damaged, Destroyed}` to **MIL‑STD‑2525C** air symbols via `aircraft_mapping.yaml`.
* Reuse **GeoTransform** from `map.yaml` for accurate lat/lon.
* Integrate with the **CoT Output Service** (localhost, unicast, multicast) configured in J3.

---

## Design Overview

### New Trait

`CoTAircraftEmitter` (attach to all aircraft actors via rules YAML)

**Config (per actor or shared defaults):**

* `Endpoint`: uses the shared CotOutputService.
* `UIDPrefix`: default `AIR`.
* `TypeByRole`: CoT `type` by role (e.g., `a-f-A-F` for fixed‑wing, `a-f-A-H` for rotary), overridable per aircraft.
* `MilsymIdByState`: `{Alive, Damaged, Destroyed} → 2525C id`.
* `CallsignPattern`: `${Team}.${ShortName}.${Seq}` → `BLUE.JET.01` / `RED.HEL.02`.
* `HeartbeatSec`: default `2–5` (faster than ground units for smooth tracks).
* `StaleSec`: default `20–30` (aircraft update more frequently).
* `PrecisionMeters`: default `1`.
* `AltitudeMode`: `HAE` | `AGL` | `Fixed` (fallback if engine lacks Z). Since Engine lacks Z, we will use HAE (MSL 300m).
* `TaxiSpeedMps`, `RotateSpeedMps` (optional cosmetics for taxi/takeoff modeling).

**Hooks:**

* `OnSpawn(Airfield→Aircraft)` → **Spawn** CoT (parked/taxi state).
* `OnTakeoff` / `OnLand` → state transitions; update altitude/speed profile.
* `OnWaypoint` → optional **Nav** CoT (reduced rate; enriches course predictability).
* `OnHealthChanged` → **Status** CoT (Alive/Damaged).
* `OnAttackBegin/End` → mark **AttackRun** window (helps analysts interpret maneuvers).
* `OnDestroyed` → **Destroyed** CoT; stop heartbeats.
* `OnTick` (every `HeartbeatSec`) → **Heartbeat** CoT with updated position + `track`.

**UID Strategy:**

* Generate per instance at first emission; persist in actor state. Never reused.

**Callsign Strategy:**

* Team prefix + platform short code + sequence: `BLUE.F16.01`, `BLUE.MIG.02`, `BLUE.HIND.01`.
* Optional per‑mission suffix: `BLUE.F16.01.CAS`.

**Location & Telemetry:**

* `WPos → Lat/Lon` via `GeoTransform`.
* `hae`: if the engine exposes Z, convert to meters and add to a nominal geoid offset; else approximate using: parked/taxi `hae≈0`, climb/cruise based on speed/phase tables (configurable), landing profile decreasing to `0` on touchdown.
* `track` detail element: `speed` (m/s), `course` (0–359°). Compute from last two positions over Δt; clamp spikes.

**Flight Phases (derived state):**

* `Parked` (on pad/runway, speed≈0)
* `Taxi/Hover` (slow movement, low altitude)
* `Takeoff` (speed crossing `RotateSpeedMps`)
* `Climb` (increasing `hae`)
* `Cruise/Loiter` (stable `hae`, waypoints/loiter radius)
* `AttackRun` (weapon discharge window)
* `RTB` (course bias toward home/base)
* `Approach` (descending profile)
* `Landing` (touchdown → `Parked`)

**Symbol/Type Mapping:**

* `aircraft_mapping.yaml` keyed by actor name → `{type, milsymAlive, milsymDamaged, milsymDestroyed}`.
* Role presets: `FixedWing`, `RotaryWing`, `UAV`.

**Emission Rate & Coalescing:**

* Heartbeat: 2–5 Hz max to keep TAK smooth without flooding.
* Coalesce: if multiple updates within one tick window, send the newest only.

**Error Handling:**

* If map lacks `GeoTransform`, log `skip air cot: no georef` and disable trait.
* If CoT transport unavailable, drop non‑blocking and log once per minute.

---

## CoT Payload Shape (examples)

**Heartbeat (Airborne)**

```xml
<event version="2.0" type="a-f-A-F" how="m-g" uid="AIR-..." time="2025-08-28T14:12:03Z" start="2025-08-28T14:10:55Z" stale="2025-08-28T14:12:23Z">
  <point lat="34.123456" lon="-77.123456" hae="850.0" ce="15" le="15"/>
  <detail>
    <contact callsign="BLUE.F16.01"/>
    <track speed="215" course="137"/>
    <__milsym id="SFAPMF-----*****"/>
  </detail>
</event>
```

**Landing (Touchdown)**

```xml
<event version="2.0" type="a-f-A-F" how="m-g" uid="AIR-..." time="2025-08-28T14:18:41Z" start="2025-08-28T14:10:55Z" stale="2025-08-28T14:19:01Z">
  <point lat="34.120001" lon="-77.120001" hae="0" ce="10" le="10"/>
  <detail>
    <contact callsign="BLUE.F16.01"/>
    <track speed="12" course="090"/>
    <__milsym id="SFAPMF-----*****"/>
  </detail>
</event>
```

**Destroyed**

```xml
<event version="2.0" type="a-f-A-F" how="m-g" uid="AIR-..." time="2025-08-28T14:22:07Z" start="2025-08-28T14:10:55Z" stale="2025-08-28T14:22:27Z">
  <point lat="34.111111" lon="-77.111111" hae="100" ce="50" le="50"/>
  <detail>
    <contact callsign="BLUE.F16.01"/>
    <__milsym id="SFAXMF-----*****"/>
  </detail>
</event>
```

> Notes: `track` optional on non‑moving phases; `hae` will be MSL 300m.

---

## Milestones & Tasks

### [x]J6‑M0 — Planning & Inventory (½ day)

* Enumerate all aircraft actors in RA mod (fixed‑wing, helicopter, VTOL/UAV if present).
* Create `SupportingDocs/aircraft_mapping.yaml` skeleton with placeholder 2525C IDs.
* Decide default `AltitudeMode` and heartbeat/stale for air.

### [x] J6‑M1 — Trait Skeleton & UID (1 day)

* Implement `CoTAircraftEmitter` with config parsing and UID persistence.
* Wire to aircraft lifecycle hooks (spawn, health, destroy).
* Logs: show UID, callsign, mapping resolution.
* Confirm if default.yaml is used for the aircraft rules. G:\WindSurf\OpenRA_WoW\OpenRA_WoW\OpenRA\mods\ra\rules\defaults.yaml

### [x] J6‑M2 — Flight Phase Model (1 day)

* Implement phase machine (Parked→Taxi→Takeoff→Climb→Cruise/Loiter→AttackRun→RTB→Approach→Landing→Parked).
* Derive `course` and `speed`; simple altitude profile by phase if Z not exposed.

### [x] J6‑M3 — Heartbeats & Telemetry (1 day)

* Send heartbeat at .5 - 1 sec updates with `track` and `hae`.
* Coalesce updates; protect game loop from stalls.

### [x] J6‑M4 — Health & Symbology (½ day)

* Map Alive/Damaged/Destroyed to 2525C.
* Ensure symbol swaps without UID change.

### [x] J6‑M5 — Airfield/Helipad Integration (½ day)

* Link aircraft to its producing structure for `parent_callsign` in `<link>` (optional).
* Emit Taxi, Takeoff, Landing transitions.

### [x] J6‑M6 — Integration with Output Service (½ day)

* Confirm emissions work across Localhost/Unicast/Multicast.
* Add test toggles for lower update rate in debug builds.

### [x] J6‑M7 — QA & Test Matrix (1 day)

* Flight from spawn through landing; damage/destroy mid‑air; RTB flow.
* Screenshots of TAKX tracks; `cot.log` samples.

**Estimated Engineering:** \~4–5 days + QA.

---

## Acceptance Criteria

1. **Per‑Aircraft UID** is unique and stable for lifetime.
2. **Lifecycle** phases produce appropriate CoT (spawn/taxi/takeoff/airborne/land/destroyed).
3. **Telemetry** includes `track` (speed/course) and `hae` (or AGL) on airborne heartbeats.
4. **Keep‑Alive** at 2–5 Hz; TAK shows smooth tracks; markers stale within `StaleSec` when emissions stop.
5. **Symbology** swaps correctly on damage/destroyed.
6. **Integration**: works with J3 output settings; visible on TAKX across LAN.

---

## Test Matrix

| Scenario          | Steps                            | Expected CoT                                                     |
| ----------------- | -------------------------------- | ---------------------------------------------------------------- |
| Spawn Jet         | Build jet at Airfield            | Spawn event; parked/taxi state; UID + callsign set               |
| Takeoff & Climb   | Order takeoff                    | Takeoff→Climb transitions; `hae` rising; `track` present         |
| Cruise/Loiter     | Patrol waypoint loop             | Smooth heartbeats at 2–5 Hz; stable `hae`; correct `course`      |
| Attack Run        | Engage target                    | AttackRun window; no UID change; symbol unchanged unless damaged |
| RTB & Land        | Order return to base             | RTB→Approach→Landing transitions; `hae→0`; parked state          |
| Damaged Mid‑Air   | AA hits aircraft                 | Status CoT swaps to Damaged symbol; UID persists                 |
| Destroyed Mid‑Air | Kill aircraft                    | Destroyed event; heartbeats stop; marker stales                  |
| LAN Output        | Use Multicast 239.255.42.42:4242 | All TAK clients on subnet see tracks                             |

---

## Inputs Needed From You

* Final **2525C mapping** for all aircraft (fixed/rotary/UAV as applicable).
* Preferred **callsign pattern** and team prefixes for air.
* Defaults for **HeartbeatSec** and **StaleSec** for air units.
* Clarify whether OpenRA exposes Z; if not, approve the phase‑based altitude profile.

---

## Deliverables

* Source: `CoTAircraftEmitter.cs`, aircraft YAML updates, `aircraft_mapping.yaml`.
* Tests: golden XML for air states & sample tracks.
* Docs: operator guide (TAK bring‑up for air), mapping table.
* QA artifacts: screenshots + `cot.log` samples.

---

## Logging (examples)

* `air: spawn uid=AIR-... callsign=BLUE.JET.01 type=a-f-A-F`
* `air: takeoff uid=AIR-... speed=80 mps`
* `air: hb uid=AIR-... lat=… lon=… hae=… speed=… course=…`
* `air: damaged uid=AIR-... milsym=SFADMF-----*****`
* `air: destroyed uid=AIR-...`

---

## Implementation Notes

* **Performance:** throttle to ≤5 Hz; drop‑oldest queue policy to avoid frame hitches.
* **Precision:** round lat/lon to \~1 m; clamp course changes >120°/tick as outliers.
* **Security:** prefer multicast TTL=1; avoid leaking CoT off‑LAN.
* **Extensibility:** future UAV control links, sensor FOV cones, and tasking messages can attach under `<detail>` without changing the trait interface.
