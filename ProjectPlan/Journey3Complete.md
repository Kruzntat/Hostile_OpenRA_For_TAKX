# J3 — CoT Output Selector (Localhost / Unicast / Multicast)  
*Add a startup UI + robust transport layer so OpenRA → TAKX can run on one or many LAN hosts.*

This plan plugs cleanly into your current **J2 CoT emitter** work (buildings + MCV spawn). We’ll keep your default behavior (localhost:4242) but give players a **modal at launch** to choose:  
- **Localhost** `127.0.0.1:4242` (default)  
- **Unicast** to a specific IPv4 (e.g., `192.168.1.25:4242`)  
- **Multicast** to a group (e.g., `239.255.42.42:4242`, TTL=1)

---

Status: N3 completed. Next: N4 — Startup Modal UI.

## Architecture (C#; aligns with OpenRA trait model)

**Core types**
- `enum CotEndpointMode { Localhost, Unicast, Multicast }`
- `sealed class CotOutputConfig { CotEndpointMode Mode; string Host; int Port; int? MulticastTtl; string? BindInterfaceName; bool Remember; }`
- `interface ICotTransport : IDisposable { ValueTask SendAsync(ReadOnlyMemory<byte> payload); }`
- `sealed class UdpUnicastTransport : ICotTransport { /* standard UDP */ }`
- `sealed class UdpMulticastTransport : ICotTransport { /* sets IP_MULTICAST_TTL, optional IF, LOOP=false */ }`
- `sealed class CotBroadcaster : IDisposable`  
  - Owns the chosen `ICotTransport`  
  - Thread-safe `Enqueue(ReadOnlyMemory<byte>)`  
  - Bounded channel + background sender loop (never blocks the game loop)  
- `static class CotOutputService`  
  - Singleton-style lifecycle; reads config, constructs transport, exposes `Enqueue` to your existing `CoT*Emitter` traits

**Persistence**
- JSON at `%APPDATA%/OpenRA/cot-output.json` (Windows) / `~/.openra/cot-output.json` (others)  
- CLI overrides: e.g., `--cot.mode=Multicast --cot.host=239.255.42.42 --cot.port=4242`

**Compatibility with your J2**
- Your `CoTBuildingEmitter` calls `CotOutputService.Enqueue(xmlBytes)` exactly as it does now; only the service’s transport is new.

---

## UX — “CoT Output Settings” (modal at game start)
- **Mode (radio buttons)**: Localhost / Unicast / Multicast  
- **Port** (numeric): default **4242**  
- **If Unicast**: `Host IPv4` textbox (placeholder `192.168.1.25`)  
- **If Multicast**:  
  - Preset dropdown: `239.255.42.42`, `239.255.0.1`, `Custom…`  
  - If Custom → `Group IPv4` textbox (validate 239.0.0.0/8)  
  - `TTL` numeric (default **1**)  
  - (Advanced) `Bind Interface` dropdown if multiple NICs  
- **Remember this setting** (checkbox)  
- Buttons: `Start` (disabled until valid), `Cancel`

**Inline validation**
- Unicast: valid IPv4 (allow RFC1918; show hint if outside `192.168/16` while okay to accept)  
- Multicast: must be **239.0.0.0/8** (reject `224.0.0.x`)  
- Port: 1–65535 (warn if not 4242)

---

## Defaults & Recommendations
- **Default mode/host/port**: Localhost → `127.0.0.1:4242`  
- **Recommended multicast**: `239.255.42.42:4242`, **TTL=1**  
- **Broadcast** (optional future toggle): subnet broadcast `192.168.1.255:4242` for tiny labs only

---

## Logging (fits your `cot.log` pattern)
- On init:  
  - `cot: init mode=Localhost host=127.0.0.1 port=4242`  
  - `cot: init mode=Unicast host=192.168.1.25 port=4242`  
  - `cot: init mode=Multicast group=239.255.42.42 port=4242 ttl=1 if=Ethernet0`
- On send error: `cot: send error err=<exception> dropping packet` (non-fatal)  
- On backpressure: `cot: backpressure drop oldest count=…` (if enabled)

---

## Milestones, Tasks, & Acceptance Criteria

### [X]N1 — Design Freeze & Wiring Plan (½ day)
**Tasks**
- Finalize field names, defaults, and UX copy.
- Decide: expose “Bind Interface” now or later.  
**Acceptance**
- Spec reviewed; no ambiguity in modes, validation, or defaults.
- Status: Completed on 2025-08-20T18:36:09-04:00.

### [x]**N2 — Transport Layer (1–1.5 days)**
**Tasks**
- Implement `ICotTransport`, `UdpUnicastTransport`, `UdpMulticastTransport`.
- Multicast options: `TTL=1`, `LOOP=false`, optional interface bind.
- `CotBroadcaster` with bounded `Channel<byte[]>` & async sender.
**Tests**
- Localhost smoke test listener receives packets.
- Multicast self-listen (loopback enabled temporarily) confirms group send.
**Acceptance**
- All three paths can emit to a test listener without blocking the game loop.

### [X]**N3 — Config & Persistence (½ day)**
**Tasks**
- Implement `CotOutputConfig` load/save; sane defaults if file absent/corrupt.
- CLI overrides (optional).  
**Acceptance**
- Restart preserves settings when “Remember” is checked; defaults otherwise.

### [X]**N4 — Startup Modal UI (1 day)**
**Tasks**
- Build modal with radios, fields, presets, TTL, Remember checkbox.
- Real-time validation; disable `Start` when invalid.
**Acceptance**
- Choosing a mode updates an in-memory preview; clicking `Start` builds the correct transport.

### [ ]**N5 — Game Integration & Lifecycle (½–1 day)**
**Tasks**
- Show modal before first CoT emission (tie into your J2 emitters).
- Ensure safe dispose on exit or settings change.
- Backpressure policy: **drop-oldest** with a small queue (e.g., 256) to avoid stalls.
**Acceptance**
- No frame hitches under bursty CoT; clean shutdown (no socket leaks).

### [X] **N6 — LAN Validation (1 day)**
**Tasks**
- **Unicast**: Send to TAKX on another PC (`192.168.1.x:4242`) → verify in TAKX.
- **Multicast**: `239.255.42.42:4242` TTL=1 → verify all TAK devices on the subnet receive.
- (Optional) **Broadcast** sanity check if you later add it.
**Acceptance**
- TAKX on a separate machine displays contacts for both Unicast and Multicast modes.
- Packet capture confirms correct dst IP/port; multicast stays on-subnet (TTL=1).

### [ ] **N7 — Error Handling & Diagnostics (½ day)**
**Tasks** - Cancelled***
- Clear inline errors (invalid IP/group/port).
- Robust exception handling in sender loop (non-fatal).
- Add a diagnostics toggle to sample-log one XML every N messages.
**Acceptance**
- Bad inputs never start the transport; meaningful messages guide the user.
- Network blips don’t crash the game; warnings logged.

### [X] **N8 — Docs & QA Artifacts (½ day)**
**Tasks**
- `docs/cot/output-selector.md` with LAN checklists (firewall/IGMP).
- Tiny UDP receive tool (C#) for lab verification.
**Acceptance**
- A new user can configure and prove end-to-end in <5 minutes.

Once complete and tested, this will be merged into the mainline OpenRA repository. 

---

## Test Matrix (augmenting your existing one)

| Scenario | Steps | Expected |
|---|---|---|
| Localhost default | Launch → keep defaults | TAKX on same PC shows contacts; `cot.log` init=Localhost |
| Unicast to remote | Select Unicast `192.168.1.25:4242` | TAKX on `.25` shows contacts; others don’t |
| Multicast on LAN | Select Multicast `239.255.42.42:4242 TTL=1` | All TAK clients on subnet show contacts |
| Invalid unicast | Enter `300.168.1.10` | `Start` disabled; inline error |
| Invalid multicast | Enter `224.0.0.5` | Blocked with “use 239.x.x.x” |
| Port change | Set `4321` | Packets to chosen port; TAKX listening there receives |
| Multi-NIC | Bind wrong IF | Log warning; (optional) UI hint or IF dropdown fixes it |
| Backpressure | Burst 5k msgs in a second | No hitching; log reports modest drops |

---

## Implementation Notes (practical)
- **Socket reuse:** set `SocketOptionName.ReuseAddress` appropriately for multicast receive tools; sender typically doesn’t need it.  
- **Interface bind:** when multiple adapters exist, allow user to pick; default to first non-virtual IPv4 adapter.  
- **Security:** TTL=1 prevents leakage; don’t expose CoT off-LAN.  
- **Performance:** consider coalescing updates per entity to ≤10 Hz if you ever stream many units.

---

## Ready-to-Use Defaults (if you ship today)
- Mode: **Localhost**  
- Host: **127.0.0.1**  
- Port: **4242**  
- Multicast preset: **239.255.42.42** (TTL=1)  
- Remember: **true**

---

## Next Steps
If you want, I can follow up with:  
1) the `ICotTransport` / `CotBroadcaster` C# skeleton (drop-in), and  
2) a minimal `cot-output.json` example + the startup modal view-model.