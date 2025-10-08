# J5 — Vehicle CoT from Factories  
*Scope: All vehicle units (tanks, APCs, aircraft, etc.). Each vehicle instance gets its own CoT marker with unique UID, mobility updates, lifecycle state, and keep-alives.*

---

## Objectives
- Emit CoT events for **every vehicle** created from vehicle-producing structures (e.g., War Factory, Airfield).  
- Ensure **unique, stable UIDs** per vehicle instance.  
- Provide **heartbeat/keep-alive** while active.  
- Map `{Alive, Damaged, Destroyed}` → MIL-STD-2525C symbology via `vehicle_mapping.md`.  
- Reuse `GeoTransform` for lat/lon.  
- Integrate with CoT output selector (J3).  

---

## Design Overview

### New Trait
`CoTVehicleEmitter` (attach to all vehicle actors via rules YAML)

**Config (per actor or shared defaults):**
- `Endpoint`: uses `CotOutputService` (J3).  
- `UIDPrefix`: e.g., `VEH`.  
- `Type`: CoT `type` (varies: tank/APC/air, etc.; pulled from mapping).  
- `MilsymIdByState`: map of `{Alive, Damaged, Destroyed} → milsym id`.  
- `CallsignPattern`: `${Team}.${ShortName}.${Seq}` → `BLUE.TNK.01`.  
- `HeartbeatSec`: e.g., `5`.  
- `StaleSec`: e.g., `60`.  
- `PrecisionMeters`: e.g., `1`.  

**Hooks:**
- `OnSpawn(Factory→Vehicle)` → send **Spawn** CoT.  
- `OnHealthChanged` → send **Status** CoT.  
- `OnDestroyed` → send **Destroyed** CoT + stop heartbeats.  
- `OnTick` → **Heartbeat** CoT with updated position.  

**UID Strategy:**  
- Deterministic GUID or persisted unique ID. Never reused.  

**Callsign Strategy:**  
- Team prefix + type code + sequence.  
- Example: `BLUE.TNK.01`, `RED.JET.02`.  

**Location:**  
- Vehicles are mobile. Update via heartbeat ticks.  
- `WPos → Lat/Lon` via `GeoTransform`.  

---

## Milestones & Deliverables

### [x] J5-M0 — Planning & Enablement (½ day)  
- Confirm vehicle classes to include (Tank, Jeep, APC, Aircraft, naval etc.).  
- Update mapping table skeleton (`vehicle_mapping.md`) with placeholder 2525C IDs.  QA will provide all unique vehicle names after the list of all vehicles have been provided
- **Deliverable:** Mapping doc in SupportingDocs.  

### [X] J5-M1 — Trait Skeleton & UID (1 day)  
- Implement `CoTVehicleEmitter` with config parsing + UID generation.  
- Hook into vehicle lifecycle.  
- **Deliverable:** Logs show per-vehicle UID + emissions.  

### [x] J5-M2 — Factory Spawn Event (½ day)  
- Detect Factory producing vehicles.  
- Emit **Spawn** CoT.  
- **Deliverable:** TAKX shows vehicle marker with UID + callsign.  

### [x] J5-M3 — Mobility & Heartbeats (1 day)  
- Send heartbeat while alive.  
- Update TAKX marker position dynamically.  
- **Deliverable:** Vehicles move in TAKX with game.  

### [X] J5-M4 — Health State Mapping (1 day)  
- Alive, Damaged, Destroyed → mapped to 2525C IDs.  
- **Deliverable:** Symbols change correctly in TAKX.  

### [x] J5-M5 — Multi-Instance & Naming (½ day)  
- Sequence indexing for multiple vehicles of same type.  
- **Deliverable:** 3× Tanks = `.01/.02/.03`.  

### [X] J5-M6 — Integration with J3 Output Service (½ day)  
- Ensure vehicle CoT flows over localhost/unicast/multicast.  
- **Deliverable:** Visible across LAN.  

### [x] J5-M7 — QA & Test Matrix (1 day)  
- Spawn, move, damage, destroy vehicles; confirm TAKX updates.  
- **Deliverable:** QA checklist + screenshots; `cot.log` samples.  

---

## Acceptance Criteria
1. **Per-Vehicle UID:** Stable unique UID per vehicle.  
2. **Lifecycle Events:** Spawn, health change, destroyed mapped correctly.  
3. **Mobility:** CoT updates reflect movement.  
4. **Keep-Alive:** Heartbeats sustain active state.  
5. **Configurability:** YAML mapping for symbology, no code change.  
6. **Integration:** Works with buildings (J2), infantry (J4), and transport selector (J3).  

---

## Test Matrix

| Scenario | Steps | Expected CoT |
|---|---|---|
| Spawn Tank | Build Tank from Factory | Spawn event; TAKX marker appears with UID + callsign |
| Move Tank | Drive Tank across map | Marker updates in TAKX |
| Damage Tank | Attack Tank | Status CoT; symbol changes; UID persists |
| Destroy Tank | Kill Tank | Destroyed event; marker stales after `StaleSec` |
| Multi-unit | Build 3 APCs | 3 distinct UIDs, `.01/.02/.03` callsigns |
| LAN Output | J3 Multicast | All TAK clients see vehicle markers |

---

## Inputs Needed From You
- Final **2525C mapping** for vehicles (`vehicle_mapping.md`).  
- Preferred **callsign pattern** for vehicles.  
- Heartbeat/stale defaults.  

---

## Deliverables
- Source: `CoTVehicleEmitter.cs`, vehicle YAML updates.  
- Tests: golden XML for vehicle states.  
- Docs: mapping table + operator guide.  
- QA: screenshots + `cot.log` samples.  
