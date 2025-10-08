# J7 — Ship & Submarine CoT to TAKX (OpenRA)

*Scope: Naval units only (surface ships and submarines). Each vessel gets its own CoT lifecycle, maritime telemetry (course, speed, depth for subs), and keep-alives. Builds on J2 (Buildings), J3 (Output Selector), J4 (Infantry), J5 (Vehicles), and J6 (Aircraft).*

---

## Objectives

* Emit CoT for **every naval unit** (ships and subs) produced in OpenRA.
* Add **naval telemetry**:

  * `track` → `speed` (knots or m/s) and `course` (degrees)
  * Submarines: `depth` (positive down, meters)
* Model **phases**: docked, underway, attack, damaged, sunk.
* Provide **unique, stable UIDs**, **callsigns**, and **heartbeats**.
* Map `{Alive, Damaged, Destroyed}` to **MIL‑STD‑2525C** maritime symbols via `ship_mapping.yaml`.
* Reuse **GeoTransform** from `map.yaml` for lat/lon accuracy.
* Integrate with the **CoT Output Service** (localhost, unicast, multicast) from J3.

---

## Design Overview

### New Trait

`CoTShipEmitter` (attach to all ship/submarine actors via rules YAML)

**Config (per actor or shared defaults):**

* `Endpoint`: uses the shared CotOutputService.
* `UIDPrefix`: default `SHIP`.
* `TypeByRole`: CoT `type` by role (e.g., `a-f-N-S` for surface ship, `a-f-N-U` for submarine).
* `MilsymIdByState`: `{Alive, Damaged, Destroyed}` mapping.
* `CallsignPattern`: `${Team}.${ShortName}.${Seq}` → `BLUE.DST.01` / `RED.SUB.02`.
* `HeartbeatSec`: default `5`.
* `StaleSec`: default `60`.
* `PrecisionMeters`: default `1`.
* `DepthMode`: `Fixed` | `Simulated` (subs only).

**Hooks:**

* `OnSpawn(Dock→Ship)` → **Spawn** CoT.
* `OnHealthChanged` → **Status** CoT.
* `OnDestroyed` → **Destroyed** CoT; stop heartbeats.
* `OnTick` (every `HeartbeatSec`) → **Heartbeat** CoT with position + `track` + (for subs) `depth`.
* `OnAttack` → mark **Engagement** window.

**UID Strategy:**

* Generated per instance at first emission; persisted in actor state.

**Callsign Strategy:**

* Team prefix + vessel code + sequence: `BLUE.FRG.01`, `BLUE.SUB.01`.

**Location & Telemetry:**

* `WPos → Lat/Lon` via `GeoTransform`.
* `track`: speed (m/s) + course (0–359°).
* Sub depth: `depth` element in `<detail>` (positive meters down). Approximated if engine lacks Z.

**Phases (derived state):**

* `Docked` (speed≈0 at naval yard)
* `Underway` (movement detected)
* `Attack` (firing weapons)
* `Damaged` (health threshold)
* `Sunk` (destroyed → final event)

**Symbol/Type Mapping:**

* `ship_mapping.yaml` keyed by actor name → `{type, milsymAlive, milsymDamaged, milsymDestroyed}`.
* Role presets: `Surface`, `Submarine`.

**Emission Rate:**

* Heartbeat: 1–2 Hz (ships move slower than aircraft).

**Error Handling:**

* If map lacks `GeoTransform`, log skip and disable trait.
* If CoT transport unavailable, drop non‑blocking and log once per minute.

---

## CoT Payload Shape (examples)

**Heartbeat (Surface Ship)**

```xml
<event version="2.0" type="a-f-N-S" how="m-g" uid="SHIP-..." time="2025-08-29T14:12:03Z" start="2025-08-29T14:10:55Z" stale="2025-08-29T14:12:33Z">
  <point lat="34.567890" lon="-77.567890" hae="0" ce="25" le="25"/>
  <detail>
    <contact callsign="BLUE.DST.01"/>
    <track speed="15" course="270"/>
    <__milsym id="SNFPFS-----*****"/>
  </detail>
</event>
```

**Heartbeat (Submarine)**

```xml
<event version="2.0" type="a-f-N-U" how="m-g" uid="SHIP-..." time="2025-08-29T14:12:03Z" start="2025-08-29T14:10:55Z" stale="2025-08-29T14:12:33Z">
  <point lat="34.561111" lon="-77.561111" hae="-50" ce="50" le="50"/>
  <detail>
    <contact callsign="BLUE.SUB.01"/>
    <track speed="10" course="090"/>
    <depth value="50" unit="m"/>
    <__milsym id="SNUPFS-----*****"/>
  </detail>
</event>
```

**Destroyed (Sunk)**

```xml
<event version="2.0" type="a-f-N-S" how="m-g" uid="SHIP-..." time="2025-08-29T14:22:07Z" start="2025-08-29T14:10:55Z" stale="2025-08-29T14:22:37Z">
  <point lat="34.555555" lon="-77.555555" hae="0" ce="100" le="100"/>
  <detail>
    <contact callsign="BLUE.DST.01"/>
    <__milsym id="SNXPFS-----*****"/>
  </detail>
</event>
```

---

## Milestones & Tasks

### [x] J7‑M0 — Planning & Inventory 

* Enumerate all ship/sub actors in RA mod.
* Create `SupportingDocs/ship_mapping.yaml` skeleton with placeholder 2525C IDs.

### [x] J7‑M1 — Trait Skeleton & UID 

* Implement `CoTShipEmitter` with config parsing and UID persistence.
* Hook into ship lifecycle (spawn, health, destroy).

### [x] J7‑M2 — Telemetry 

* Compute `course` + `speed` from Δpos.
* Add `depth` detail for subs.

### [X] J7‑M3 — Heartbeats 

* Periodic updates (1–2 Hz) with `track` (and `depth` if sub).

### [x] J7‑M4 — Health & Symbology 

* Alive/Damaged/Destroyed mapping.
* Ensure symbol swaps without UID change.

### [x] J7‑M5 — Dock Integration - Cancelled

* Link ship to its producing structure (optional `<link parent_callsign>`).
* Emit Docked/Underway transitions.

### [x] J7‑M6 — Integration with Output Service 

* Confirm emissions work across Localhost/Unicast/Multicast.

### [x] J7‑M7 — QA & Test Matrix 

* Full lifecycle tests for ship and submarine.

**Estimated Engineering:** \~4 days + QA.

---

## Acceptance Criteria

1. **Per‑Ship UID** unique and stable.
2. **Lifecycle** covers spawn/docked, underway, damaged, sunk.
3. **Telemetry** includes `track` and, for subs, `depth`.
4. **Keep‑Alive** at 1–2 Hz; TAK shows movement; markers stale correctly.
5. **Symbology** swaps correctly on damage/destroyed.
6. **Integration** with J3 output settings confirmed.

---

## Test Matrix

| Scenario           | Steps                         | Expected CoT                             |
| ------------------ | ----------------------------- | ---------------------------------------- |
| Spawn Destroyer    | Build Destroyer at Naval Yard | Spawn event; UID + callsign set          |
| Ship Underway      | Move Destroyer                | Smooth heartbeats with speed/course      |
| Sub Dive & Transit | Move Submarine                | Heartbeats with depth + course updates   |
| Attack             | Engage target                 | Attack window marked; no UID change      |
| Damaged Ship       | Attack ship                   | Symbol switches to Damaged; UID persists |
| Sunk Ship          | Destroy ship                  | Destroyed event; heartbeats stop         |
| LAN Output         | Multicast 239.255.42.42:4242  | TAK clients see ships/subs               |

---

## Inputs Needed From You

* Final **2525C mapping** for ships/subs.
* Preferred **callsign pattern** and team prefixes.
* Defaults for heartbeat/stale for naval.
* Clarify if subs should simulate depth if engine lacks Z.

---

## Deliverables

* Source: `CoTShipEmitter.cs`, YAML updates, `ship_mapping.yaml`.
* Tests: golden XML for ships + subs.
* Docs: operator guide, mapping table.
* QA artifacts: screenshots + `cot.log` samples.

---

## Logging Examples

* `ship: spawn uid=SHIP-... callsign=BLUE.DST.01`
* `ship: hb uid=SHIP-... lat=… lon=… speed=… course=…`
* `sub: hb uid=SHIP-... lat=… lon=… depth=50m`
* `ship: damaged uid=SHIP-...`
* `ship: destroyed uid=SHIP-...`

---

## Implementation Notes

* **Performance:** 1–2 Hz to keep network load modest.
* **Precision:** round lat/lon to \~1 m; clamp speed/course outliers.
* **Security:** multicast TTL=1; avoid off‑LAN emission.
* **Extensibility:** future sonar/FOV or tasking messages attach under `<detail>`.
