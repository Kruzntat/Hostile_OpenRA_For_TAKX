# J4 — Infantry CoT from Barracks  
*Scope: Infantry units only. Each infantry instance spawned from a Barracks gets its own CoT marker with unique UID, lifecycle state (alive/damaged/destroyed), and heartbeats/keep-alive.*

---

## Objectives
- Emit CoT events for **every infantry unit** created from the Barracks.  
- Ensure **unique, stable UIDs** per infantry instance.  
- Provide **heartbeat/keep-alive** for active infantry.  
- Map **state → MIL-STD-2525C symbology** via a configurable YAML mapping file (you will supply the final codes).  
- Reuse existing **GeoTransform** from `map.yaml` for accurate lat/lon.  
- Integrate with the **CoT output selector (J3)** for LAN/multicast compatibility.

---

## Design Overview

### New Trait
`CoTInfantryEmitter` (attach to all infantry actors via rules YAML)

**Config (per actor or shared defaults):**
- `Endpoint`: uses `CotOutputService` from J3.  
- `UIDPrefix`: e.g., `INF`  
- `Type`: CoT `type` (e.g., `a-f-G-U-C-I` for combat infantry; exact values provided by you).  
- `MilsymIdByState`: map of `{Alive, Damaged, Destroyed} → __milsym id`.  
- `CallsignPattern`: `${Team}.${ShortName}.${Seq}` → `BLUE.RIF.07`.  
- `HeartbeatSec`: e.g., `5`.  
- `StaleSec`: e.g., `60`.  
- `PrecisionMeters`: e.g., `1`.

**Hooks:**
- `OnSpawn(Barracks→Infantry)` → send **Spawn** CoT.  
- `OnHealthChanged` → send **Status** CoT (Alive/Damaged).  
- `OnDestroyed` → send **Destroyed** CoT + stop heartbeats.  
- `OnTick` (every `HeartbeatSec`) → **Heartbeat** CoT.

**UID Strategy:**  
- Deterministic per instance: `uid = hash(ActorId || MapGuid || SpawnTick)` or GUID generated at first emission and persisted.  
- Never reused after destruction.

**Callsign Strategy:**  
- Team prefix + short code + sequence (per infantry type).  
- Example: `BLUE.RIF.01`, `BLUE.ENG.02`.

**Location:**  
- Infantry position tracked dynamically (not static like buildings).  
- `WPos → Lat/Lon` using `GeoTransform`.  
- Updates every heartbeat (infantry are mobile).

---

## Milestones & Deliverables

### [x]J4-M0 — Planning & Enablement (½ day)  
- Confirm infantry classes to include (Rifleman, Engineer, etc.).  
- Create default mapping table skeleton (`infantry_mapping.yaml`) with placeholder 2525C IDs.  
- **Deliverable:** `ProjectPlan/SupportingDocs/infantry_mapping.md`.

### [x]J4-M1 — Trait Skeleton & UID (1 day)  
- Implement `CoTInfantryEmitter` with config parsing & UID generation/persistence.  
- Hook into infantry lifecycle (spawn, health, death).  
- **Deliverable:** Logs show per-unit UIDs and CoT emissions.

### [x]J4-M2 — Barracks Spawn Event (½ day)  
- Detect Barracks spawning infantry.  
- Emit **Spawn** CoT at creation time.  
- **Deliverable:** TAKX shows infantry marker with unique UID & callsign.

### [x]J4-M3 — Mobility & Heartbeats (1 day)  
- Send periodic **Heartbeat** while infantry is alive.  
- Update position from game coordinates each tick.  
- **Deliverable:** Marker moves in TAKX as infantry moves.

### [x]J4-M4 — Health State Mapping (1 day)  
- Map health buckets:  
  - `Alive` → your “full” CoT  
  - `Damaged` → your “damaged” CoT  
  - `Destroyed` → your “destroyed” CoT  
- **Deliverable:** Emissions match your Infantry XML examples from J1.

### [ ] J4-M5 — Multi-Instance & Naming (½ day)  - Cancelled
- Per type, per team sequence indexing for callsigns.  
- Example: 3x Riflemen = `.01/.02/.03`.  
- **Deliverable:** Multiple infantry tracked separately in TAKX.

### [x] J4-M6 — Integration with J3 Output Service (½ day)  
- Ensure infantry CoT uses the same transport (localhost/unicast/multicast).  
- **Deliverable:** Infantry visible across LAN like buildings.

### [x] J4-M7 — QA & Test Matrix (1 day)  
- Spawn/damage/destroy infantry; confirm TAKX updates.  
- Movement across map shows updated CoT positions.  
- **Deliverable:** QA checklist + screenshots; `cot.log` samples.

---

## Acceptance Criteria
1. **Per-Infantry UID:** Stable unique UID for each soldier until destroyed.  
2. **Lifecycle Events:** Spawn, health change, destroyed → mapped correctly to 2525C.  
3. **Mobility:** CoT updates reflect movement at heartbeat interval.  
4. **Keep-Alive:** Heartbeats maintain active status; markers stale after destruction.  
5. **Configurability:** Mapping table in YAML, no code change needed to update symbols.  
6. **Integration:** Works seamlessly with J2 (buildings) + J3 (output selector).  

---

## Test Matrix

| Scenario | Steps | Expected CoT |
|---|---|---|
| Spawn Rifleman | Build Barracks, train Rifleman | Spawn event; TAKX marker with UID + callsign |
| Move Rifleman | Order unit to new location | Marker position updates on TAKX |
| Damage Infantry | Attack Rifleman | Status event; symbol/type switches; UID unchanged |
| Destroy Infantry | Kill Rifleman | Destroyed event; heartbeats stop; marker stales |
| Multi-unit Spawn | Train 3 Engineers | 3 distinct UIDs, callsigns `.01/.02/.03` |
| LAN Output | Set J3 to Multicast | All TAK clients on subnet see infantry markers |

---

## Inputs Needed From You
- Final **2525C mapping** for infantry types and states.  
- Preferred **callsign pattern** (team prefixes, abbreviations).  
- Heartbeat/stale defaults for infantry.  

---

## Deliverables
- Source: `CoTInfantryEmitter.cs`, infantry YAML updates.  
- Tests: golden XML for infantry states.  
- Docs: mapping table + operator guide.  
- QA: screenshots, `cot.log` samples.  
