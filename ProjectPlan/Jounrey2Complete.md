# Journey 2 — Building CoT to TAKX (OpenRA)  
*Scope: Buildings only. Each building instance gets its own CoT marker with unique UID, lifecycle state (full/damaged/destroyed), and heartbeats/keep-alive. Starts when MCV transforms into Construction Yard.*

---

## Objectives
- Emit CoT events for **every building** (including the Construction Yard on MCV deploy).  
- Ensure **unique, stable UIDs** per building instance (even when multiple share the same name).  
- Provide **heartbeat/keep-alive** so TAKX can detect alive vs. destroyed.  
- Map **state → MIL-STD-2525C symbology** via a configurable table (placeholder IDs now; you’ll provide exact codes later).  
- Reuse the existing **GeoTransform** from `map.yaml` for accurate lat/lon.

---

## Design Overview

### New Trait (proposed)
`CoTBuildingEmitter` (attach to all building actors via rules YAML)

**Config (per actor or shared defaults):**
- `Endpoint`: `127.0.0.1:4242` (UDP default; TCP optional later)  
- `UIDPrefix`: e.g., `BLD`  
- `Type`: CoT `type` (e.g., `a-f-G-I-R` for installations; exact values supplied later)  
- `MilsymIdByState`: map of `{Healthy, Damaged, Destroyed} → __milsym id`  
- `CallsignPattern`: e.g., `${Team}.${ShortName}.${Seq}` → `BLUE.PWR.02`  
- `HeartbeatSec`: e.g., `5` (send periodic heartbeat)  
- `StaleSec`: e.g., `60` (time → `stale` = `time + StaleSec`)  
- `PrecisionMeters`: e.g., `1` (round lat/lon to ~1m)  

**Hooks:**
- `OnSpawn/OnTransform(MCV→ConstructionYard)` → send **Spawn** CoT  
- `OnHealthChanged` → send **Status** CoT (Healthy/Damaged)  
- `OnDestroyed` → send **Destroyed** CoT + stop heartbeats  
- `OnTick` (every `HeartbeatSec`) → **Heartbeat** CoT (same position; refresh `time/stale`)

**UID Strategy:**
- Deterministic per instance: `uid = hash(ActorId || MapGuid || SpawnTick)` or GUID generated at first emission and persisted in actor state.  
- Never re-use a UID after destruction.

**Callsign Strategy:**
- Team prefix + short code + sequence (per building type, per team).  
- Example: `BLUE.CY.01` (Construction Yard), `BLUE.PWR.03` (Power Plant).

**Location:**
- `WPos → Cell → Lat/Lon` using your `GeoTransform` (respect `rotation_deg`).  
- Height `hae` optional; can be fixed or derived later.

**Stale/Keep-Alive:**
- For each event:  
  - `time = now()`  
  - `start = now()` (or first-seen for spawn)  
  - `stale = now() + StaleSec`  
- Heartbeats ensure `stale` advances while the building exists.  
- On `Destroyed`, send final event and **disable** future heartbeats.

---

## Milestones & Deliverables

### J2-M0 — Planning & Enablement (½ day)
[x] - Complete
- Confirm building classes to include (all standard RA buildings + CY).  
- Create default mapping table skeleton (building → CoT `type` + placeholder `__milsym id`).  
- **Deliverable:** `ProjectPlan/SupportingDocs/buildings_mapping.md` (stub), task list refined.

### J2-M1 — Trait Skeleton & UID (1 day)
[X] - Complete
- Implement `CoTBuildingEmitter` with config parsing & UID generation/persistence.  
- Wire to generic building lifecycle hooks (spawn, health, death).  
- **Deliverable:** Compiles; logs demonstrate UID stability and per-instance uniqueness.

### J2-M2 — MCV→CY Transform Event (½–1 day)
[X] - Complete
- Detect MCV deploy → Construction Yard (CY) created.  
- Emit **Spawn** CoT for CY at creation time.  
- **Deliverable:** On deploy, TAKX shows CY marker with unique UID & callsign.

### J2-M3 — Heartbeat & Stale Semantics (1 day)
[ ] - Complete-Canclled
- Add periodic **Heartbeat** at `HeartbeatSec`.  
- Implement `stale = time + StaleSec` on every emission.  
- **Deliverable:** Marker remains “alive” in TAKX while building exists; goes stale if game pauses/trait disabled.

### J2-M4 — Health State Mapping (1 day)
[x] - Complete
- Map health buckets:  
  - `Healthy` → your “full health” CoT sample  
  - `Damaged` → your “damaged” sample  
  - `Destroyed` → your “destroyed” sample  
- Swap `__milsym id` and `type` per state using mapping table.  
- **Deliverable:** Emissions match your example structures for CY.

### J2-M5 — Multi-Instance & Naming (1 day)
[x] - Complete
- Per type, per team **sequence indexing** for callsigns (e.g., second Power Plant = `.02`).  
- Ensure UIDs differ across identical names.  
- **Deliverable:** Build 3× Power Plants → 3 distinct UIDs; TAKX shows separate markers.

### J2-M6 — Config & Rules Wiring (½ day)
[x] - Cancelled Feature
- Global defaults under `mods/ra/rules/cot.yaml` (endpoint, heartbeat, stale).  
- Actor-level overrides (e.g., different `Type` or `MilsymIdByState`).  
- **Deliverable:** One-file config change re-targets endpoint or rate for all buildings.

### J2-M7 — Test Harness & Golden CoT (1 day)
[ ] - Complete-Cancelled
- Add lightweight CoT logger (already have `cot.log` pattern) + binary UDP echo harness.  
- Generate **golden XML** fixtures for CY {Healthy, Damaged, Destroyed} and generic building xeartbeat.  
- Diff-tests to catch regressions (normalize timestamps).  
- **Deliverable:** `tests/cot/golden/*.xml`, `tests/cot/test_building_emissions.cs`.

### J2-M8 — TAKX Integration QA (1 day)
[x] - Cancelled Feature
- Manual & scripted runs: place multiple buildings, damage, destroy; verify TAKX updates.  
- Validate `stale` behavior when heartbeats stop (destroyed).  
- **Deliverable:** QA checklist + screenshots; `docs/cot/takx_bringup_buildings.md`.

### J2-M9 — Polish & Docs (½ day)
[ ] - Complete-Cancaled

- Finalize mapping table placeholders; ready for your MIL-STD-2525C IDs.  
- Admin guide: tuning heartbeat/stale, callsign patterns, performance notes.  
- **Deliverable:** `README` section + operator guide.

**Total:** ~6–7 working days (engineering) + QA passes.

---

## Acceptance Criteria

1. **Per-Building UID:**  
   - Every building instance (including multiple Power Plants) has a **unique, stable UID** for its lifetime.

2. **Lifecycle Emissions:**  
   - **Spawn/Transform:** CY emits on creation; any building emits on placement.  
   - **Health:** Healthy → Damaged swaps symbol/type appropriately.  
   - **Destroyed:** Final event sent; no further heartbeats.

3. **Keep-Alive:**  
   - Heartbeat every `HeartbeatSec`; `stale = time + StaleSec`.  
   - TAKX shows markers as active while heartbeats continue; stale after destruction or game stop.

4. **Geospatial Accuracy:**  
   - Lat/Lon uses `GeoTransform` with rotation; position falls within building footprint center (1 cell tolerance).  
   - Coordinates rounded to ~1 m.

5. **Configurability:**  
   - Endpoint, heartbeat, stale, callsign pattern, and symbol/type mapping configurable without code changes.

6. **Logging & Tests:**  
   - `cot.log` shows emissions with uid, callsign, state, and target endpoint.  
   - Golden XML tests pass.

---

## Test Matrix

| Scenario | Steps | Expected CoT |
|---|---|---|
| MCV deploy → CY | Build MCV, deploy | CY Spawn event with new UID; callsign `BLUE.CY.01` |
| Add Power Plants ×3 | Build PWR thrice | 3 UIDs; callsigns `.01/.02/.03`; heartbeats active |
| Damage CY | Attack to 50% | Damaged event; symbol/type switches; UID unchanged |
| Destroy CY | Finish off | Destroyed event; heartbeats stop; marker stales after `StaleSec` |
| Pause/Resume | Pause game > `StaleSec`, resume | Markers stale during pause; resume sends heartbeat → marker active |
| No GeoTransform | Load non-geo map | Log “skip” and no CoT sent |

---

## Inputs Needed From You

- Final **2525C mapping** for buildings (type + `__milsym id` per state).  
- Preferred **callsign pattern** and team prefixes.  
- `HeartbeatSec` and `StaleSec` defaults.  
- Any special buildings requiring distinct `type` overrides.

---

## Deliverables

- Source: `CoTBuildingEmitter.cs`, rules YAML updates, config defaults.  
- Tests: golden XML, unit tests.  
- Docs: mapping table, TAKX bring-up, operator guide.  
- QA artifacts: screenshots + `cot.log` samples.

---

## Out of Scope (for this iteration)
- Mobile units (handled in later journeys).  
- Advanced building states (power-down, captured/owner-swap) — can be added in J3+.  
- TCP, reliability, batching across processes — optional future work.
