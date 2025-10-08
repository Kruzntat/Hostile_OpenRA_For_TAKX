# J8 — Fog-of-War CoT Filtering (Friendly-Always, Hostile-When-Detected)

## Scope: Apply visibility rules so TAK only receives (a) CoT for the player + teammates always, and (b) CoT for enemy actors only while detected by any friendly sensor. When hostiles drop out of detection, their markers stale. Friendly CoT persists for the whole match. Builds on J2–J7 emitters and J3 output.

## Objectives

Friendly (self + allies): always emit full CoT (no FoW filtering) for the entire game.

Hostile (enemies): emit CoT only while detected by any friendly actor; when no longer detected, stop emitting and let TAK stale the marker.

Use a single generic hostile milsym for all enemy contacts while detected (you’ll supply the code).

Preserve UID continuity across visible/hidden transitions.

Keep compatibility with existing CoT Output Service & settings (localhost/unicast/multicast).

## Design Overview

New service: CoTVisibilityRouter

Centralizes visibility policy all emitters call before sending.

### Policy:

If actor.Owner is player or ally → ALLOW (always).

Else if enemy:

If DetectedByTeam(actor, localTeam) → ALLOW and force hostile milsym (generic).

If not detected → SUPPRESS; if this is a transition, let last event go stale (no removal message needed—TAK handles via stale).

Re-sighting resumes emissions with the same UID.

Detection sources (union):

Line-of-sight / sensor traits / vision providers from any friendly or allied actor (team union).

Symbology handling:

For friendlies: use their normal per-type 2525C mapping from J2–J7.

For hostiles: override CoT type and <detail><__milsym id="..."/></detail> per domain (ignore per-unit specifics for enemies):
- Ground mobile: type=a-h-G, milsym=SHGP-----------
- Building/Installation: type=a-h-G-I, milsym=SHGPI-----H----
- Aircraft: type=a-h-A, milsym=SHAP-----------
- Vessel: type=a-h-U, milsym=SHUP-----------

Emitter integration (all types):
CoTBuildingEmitter, CoTInfantryEmitter, CoTVehicleEmitter, CoTAircraftEmitter, CoTShipEmitter call:

if (router.ShouldEmit(self, localTeam, out var hostileOverrideMilsym))
{
    var milsym = hostileOverrideMilsym ?? ResolveFriendlyMilsym(self); // friendly mapping as in J2–J7
    SendCot(self, milsym, ...);
}
else if (wasVisibleOrDetectedLastTick)
{
    SendStaleSoon(self); // stale = now + 1s
}
wasVisibleOrDetectedLastTick = router.WasEmittedThisTick;


Config (global defaults, overridable per-mod):

CoTFoW:
  Mode: Local            # Local-first per our approach
  TeamSharing: true      # union of allied detection/vision
  Hostile:
    UseGenericMilsym: true
    OverrideType: true
    GenericMilsymIds:
      GroundMobile: "SHGP-----------"
      Building: "SHGPI-----H----"
      Aircraft: "SHAP-----------"
      Vessel: "SHUP-----------"
    Types:
      GroundMobile: "a-h-G"
      Building: "a-h-G-I"
      Aircraft: "a-h-A"
      Vessel: "a-h-U"
    StaleSecondsWhenLost: 1
  Friendly:
    AlwaysEmit: true
  Stealth:
    EmitOnlyWhenAttacking: true

## Lifecycle & Timing

Friendlies (always on): spawn → heartbeats → damage/destroy → heartbeats stop on death (unchanged from J2–J7).

Hostiles (gated):

First detection → start/continue heartbeats (use generic hostile milsym).

Lost detection → stop sending; TAK cleans up at now + StaleSecondsWhenLost.

Re-detected → resume emissions with same UID.

Notes:

Destroyed-while-undetected: no explicit destroyed event (contact already stale).

UID/callsign generation stays as implemented in J2–J7 (no changes).

Acceptance Criteria

Friendly-always: All player + ally actors emit CoT for the entire match regardless of FoW.

Hostile-when-detected: Enemy actors emit CoT only while detected by any friendly/ally; otherwise suppressed.

Stale-on-loss: When detection ends, TAK markers expire within StaleSecondsWhenLost (default 1s).

Generic hostile milsym: All detected enemies use the single hostile 2525C ID you provide.

UID continuity: Same UID across detect ↔ lost ↔ re-detect transitions.

Compatibility: No regressions to building/infantry/vehicle/air/ship emitters or CoT output settings.

Test Matrix
Scenario	Steps	Expected
Friendly persistence	Idle friendly units	Continuous heartbeats; never suppressed
Enemy detected	Scout spots enemy tank	Enemy tank appears in TAK with generic hostile milsym; heartbeats while in detection
Enemy lost	Enemy retreats into FoW	Emissions stop; marker stales in ~1s
Enemy re-sighted	Scout reacquires	Same UID resumes; milsym = generic hostile
Ally detection	Teammate spots enemy	Marker visible; own client receives CoT due to TeamSharing
Destroy while visible	Kill detected enemy	Destroy event sent; marker then stales per normal
Destroy while hidden	Kill after losing detection	No new CoT; previous marker already stale
LAN modes	Use Unicast/Multicast	Transport unchanged; only visibility policy affects emissions

# Milestones & Tasks

[x] J8-M0 — Design freeze
Defaults locked: TeamSharing=true, StaleSecondsWhenLost=1s, domain-specific hostile type+milsym overrides, stealth actors emit only when attacking.

[x] J8-M1 — Router service
- Implement `CoTVisibilityRouter` trait (world-level):
  - `ShouldEmit(Actor self, Player viewer, out string hostileMilsym, out string hostileType)`
  - Team union detection using `World.RenderPlayer` and `Player.IsAlliedWith(...)` + `Actor.CanBeViewedByPlayer(...)`.
  - Domain classification helper: GroundMobile, Building, Aircraft, Vessel.
  - Stealth handling: treat stealth actors as emit-only-when-attacking.
- Configuration: bind to `CoTFoW` (YAML) with defaults above.
- Unit tests for policy edges (friendly always, enemy detect/lost, stealth attacking/not, re-sight UID continuity).

[x] J8-M2 — Emitter integration
- Touch `CoTInfantryEmitter`, `CoTVehicleEmitter`, `CoTBuildingEmitter`, `CoTAircraftEmitter`, `CoTShipEmitter`:
  - Consult router before every emission (spawn/heartbeat/damage/killed).
  - For hostiles: override type+milsym per domain.
  - On transition to not emitting: send stale with +1s, then suppress.
  - Suppress destroy events for enemies when not detected.
- Logging: add lightweight debug traces (toggleable) to verify gating decisions.

[x] J8-M3 — Team union
Ensure allied detection union is consulted everywhere.

[X] J8-M4 — QA pass
Run full matrix on a FoW map; capture cot.log and TAK screenshots.

QA (Local-first).
Server-authoritative routing (per-team streams) remains planned for a later journey.

Deliverables

Source: CoTVisibilityRouter.cs, emitter diffs.

Config: mods/ra/rules/cot-fow.yaml (or merged into existing CoT config).

Docs: docs/cot/fow.md usage + operator notes.

QA: cot.log samples, TAK screenshots.

## Status Update — Lint Cleanup (2025-09-14)

- __Scope__: Non-functional lint cleanup across CoT emitters: `CoTInfantryEmitter.cs`, `CoTVehicleEmitter.cs`, `CoTAircraftEmitter.cs`, `CoTBuildingEmitter.cs`, `CoTShipEmitter.cs`.
- __Fixes__: Addressed style warnings (brace/blank-line spacing, long parameter list wrapping, comment spacing) without behavior changes.
- __Result__: Clean emitter builds; unit tests passing (150/150). Minor non-emitter style suggestions remain out-of-scope for J8.

Inputs Needed From You

None — defaults locked in this design (can be overridden later via YAML if needed).

Why this matches your intent

Friendlies always on → full SA for your team in TAK.

Enemies never leak unless your team has positive detection.

Losing contact cleans the map via stale—no ghost targets.

Keeps all prior emitter work intact (J2–J7) and transport settings (J3).