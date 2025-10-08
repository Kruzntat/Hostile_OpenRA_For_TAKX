# CoT Output Settings

This document explains the Chain‑of‑Thought (CoT) output configuration modal and transport behavior in this fork.

## Where and when the modal appears
- Main entry point: `OpenRA.Mods.Common.Widgets.Logic.MainMenuLogic.OnSystemInfoComplete()`
  - Opens `MAINMENU_COT_OUTPUT_PROMPT` if `CotOutputSettingsPromptLogic.ShouldShowPrompt()` is true.
- Show conditions: `CotOutputSettingsPromptLogic.ShouldShowPrompt()` returns true if
  - No saved config exists, or
  - A saved config exists but `Remember == false`.

## UI layout and logic
- Chrome: `mods/common/chrome/mainmenu-prompts.yaml` → `MAINMENU_COT_OUTPUT_PROMPT`
- Logic: `OpenRA.Mods.Common.Widgets.Logic.CotOutputSettingsPromptLogic`
- Fields:
  - Mode: Localhost / Unicast / Multicast (dropdown)
  - Host: IPv4 or hostname. Localhost forces 127.0.0.1. Unicast/Multicast require a host; Continue is disabled if blank.
  - Port: integer; defaults to 4242 if invalid/blank
  - Multicast TTL: visible only when Mode = Multicast; defaults to 1
  - Bind Interface: free‑text for an interface name (stored, but currently not enforced by transports)
  - Remember: checkbox controlling persistence and future prompting
- Behavior on Continue:
  - Builds a `CotOutputConfig` from field values and calls `CotOutputService.ConfigureAndStart(newCfg, persist: true)`.
  - Reconfigures the sender immediately, even if a fallback had already started (no game restart required).
  - The config is persisted only if `Remember == true`.

## Transport behavior (what each mode does)
- Code: `OpenRA.Mods.Common/CotOutputService.cs`
  - Localhost → `UdpUnicastTransport` to `127.0.0.1:<port>`
  - Unicast → `UdpUnicastTransport` to `<host>:<port>`
  - Multicast → `UdpMulticastTransport` to `<group>:<port>` with `TTL` set; loopback disabled
- Backpressure: bounded channel (capacity 256), Drop‑Oldest, single reader/sender background task
- Shutdown: `Game.OnQuit += Dispose` cleans up channel, task, and socket

## Runtime initialization and reconfiguration
- First use: if any CoT message is sent before you configure, `CotOutputService.EnsureInitializedFrom("127.0.0.1", 4242)` may start a temporary localhost sender unless a remembered config exists.
- Applying settings: pressing Continue (or calling `ConfigureAndStart`) replaces the running sender with your new settings immediately.
- See Verification for the `cot init ...` log line that confirms the active endpoint.

## Persistence
- File path:
  - Windows: `%APPDATA%\OpenRA\cot-output.json`
    - `%APPDATA%` is `%USERPROFILE%\AppData\Roaming`
    - Example: `C:\Users\<username>\AppData\Roaming\OpenRA\cot-output.json`
  - Non‑Windows: `~/.openra/cot-output.json`
    - `~` is the user's home directory
    - Example: `/home/<username>/.openra/cot-output.json`
- Loaded by: `CotOutputSettingsPromptLogic` (for modal defaulting) and `CotOutputService.EnsureInitializedFrom` (prefers remembered config on first use)
- JSON schema (example):
```json
{
  "Mode": "Unicast",
  "Host": "192.168.1.25",
  "Port": 4242,
  "MulticastTtl": 1,
  "BindInterfaceName": "Ethernet",
  "Remember": true
}
```

## Verification
- Logs: on start, `CotOutputService` logs a line like
  - `cot init mode=Unicast host=192.168.1.25 port=4242`
  - Log location: `%APPDATA%\OpenRA\Logs\` (latest file)
- Functional checks:
  - Localhost: run a listener on the same PC; verify packets
  - Unicast: send to a specific LAN host (e.g., TAKX or a UDP listener)
  - Multicast: send to a group (e.g., `239.255.42.42:4242`, `TTL=1`); verify multiple receivers on the subnet

## Infantry damage-state mapping (CoT + MILSYM)

- Location: `OpenRA/mods/ra/rules/defaults.yaml` → `^Infantry > CoTInfantryEmitter`
- Damage-state keys (case-insensitive): `Undamaged`, `Light`, `Medium`, `Heavy`, `Critical`, `Dead`.
- Resolution precedence (from `CoTInfantryEmitter.cs`):
  1) `ActorDamageMilsymIds[Actor][State]`
  2) `ActorDamageMilsymIds[Actor]["Default"]`
  3) `ActorMilsymIds[Actor]`
  4) `MilsymId` (trait default)

### 3-state infantry schema
- We use the same scheme as buildings by driving the 4th character (index 3, 0-based) of the 2525C symbol ID:
  - Undamaged (OK): set char4 = `C`
  - Damaged (Light/Medium/Heavy): set char4 = `D`
  - Critical/Dead: set char4 = `X` (Dead uses the same as Critical)
- Keep each actor’s base 2525C ID (identity/unit type) intact; only substitute the 4th character per state. This preserves per-actor specificity while reflecting health state.

Example (pattern only — do not copy these strings verbatim):

```yaml
^Infantry:
  CoTInfantryEmitter:
    # Each actor has a base 2525C ID in ActorMilsymIds (your per-unit codes)
    ActorMilsymIds:
      E1: "<E1_BASE_2525>"   # e.g., SFGPUCI-----***** (example only)

    # Derive per-state IDs by replacing the 4th character of the base with C/D/X
    ActorDamageMilsymIds:
      E1:
        Undamaged: "<E1_BASE with char4=C>"
        Light:     "<E1_BASE with char4=D>"
        Medium:    "<E1_BASE with char4=D>"
        Heavy:     "<E1_BASE with char4=D>"
        Critical:  "<E1_BASE with char4=X>"
        Dead:      "<E1_BASE with char4=X>"  # same as Critical
```

Notes:
- The same pattern can be applied to all infantry actors (`E1, E2, E3, E4, E6, SPY, E7, MEDI, MECH, THF, SHOK, DOG, Zombie, Ant, FireAnt, ScoutAnt, WarriorAnt`).
- If `ActorDamageMilsymIds` is omitted/empty, the emitter falls back to the static per-actor `ActorMilsymIds` or the trait `MilsymId`.

## Forcing the modal to show again
- Delete `%APPDATA%\OpenRA\cot-output.json`, or set `"Remember": false` in the file
- Or in the UI: uncheck “Remember these settings” before Continue (no file will be written)

## Milestone status
- N3 — Config & Persistence: Completed. Implemented `CotEndpointMode`, `CotOutputConfig`, JSON load/save at `%APPDATA%/OpenRA/cot-output.json`, `EnsureInitializedFrom(...)` fallback, `ConfigureAndStart(...)`, and startup log line.
- N4 — Startup Modal UI: Completed. Modal chrome and logic exist (`mods/common/chrome/mainmenu-prompts.yaml`, `OpenRA.Mods.Common.Widgets.Logic.CotOutputSettingsPromptLogic.cs`), integrated in startup flow (`OpenRA.Mods.Common.Widgets.Logic.MainMenuLogic.cs`). Includes minimal validation (Continue disabled when Unicast/Multicast host is blank; Localhost forces 127.0.0.1) and immediate reconfigure on Continue.

## Current limitations / notes
- Bind Interface: stored in `CotOutputConfig.BindInterfaceName` and displayed in the modal, but not applied when sockets are created; the OS selects the egress NIC by routing table.
- Validation: Continue is disabled for Unicast/Multicast when Host is blank. Other inputs are minimally sanitized (Port defaults to 4242 if invalid; Multicast TTL defaults to 1). No inline error labels yet.
- Multicast presets: no preset dropdown is currently wired; enter the group manually (recommended: `239.255.42.42`).
- CLI overrides for CoT: not implemented; configuration is via UI and the JSON file.

## Troubleshooting
- Always confirm the active endpoint in the log: `%APPDATA%\OpenRA\Logs\` → line like `cot init mode=Unicast host=192.168.1.25 port=4242`.
- Still sending to 127.0.0.1?
   - Ensure `%APPDATA%\OpenRA\cot-output.json` has your desired `Mode`, `Host`, and `Remember`.
   - Set `"Remember": false` to force the modal to appear on next launch, then press Continue.
- Unicast: match the UDP port with your TAK/receiver (commonly 4242) and allow via Windows Firewall.
- Multicast: use a valid IPv4 multicast group (224.0.0.0–239.255.255.255); `TTL=1` for same‑LAN. Ensure your AP/switch permits multicast/IGMP snooping, and that receivers join the same group/port.
- NIC binding: not implemented yet; routing table determines the egress interface.

## Files to review
- UI chrome: `OpenRA/mods/common/chrome/mainmenu-prompts.yaml`
- UI logic: `OpenRA/OpenRA.Mods.Common/Widgets/Logic/CotOutputSettingsPromptLogic.cs`
- Startup sequencing: `OpenRA/OpenRA.Mods.Common/Widgets/Logic/MainMenuLogic.cs`
- Transport + persistence: `OpenRA/OpenRA.Mods.Common/CotOutputService.cs`
