# CoT LAN Configuration Checklist (Firewall + IGMP)

Use this checklist to validate Unicast and Multicast CoT traffic on a LAN. Applies to OpenRA CoT Output using UDP (typically port 4242).

- Sender: OpenRA PC
- Receivers: WinTAK/ATAK/UDP listener hosts
- Reference config: `Mode=Unicast|Multicast`, `Host=192.168.x.x|239.255.42.42`, `Port=4242`, `TTL=1`
- Verify active settings in log: `%APPDATA%\OpenRA\Logs\` → `cot init mode=... host=... port=...`

---

## 1) Unicast Checklist

- [ ] Sender (OpenRA)
  - [ ] Confirm CoT settings: `Mode=Unicast`, correct `Host=<receiver IP>`, `Port=4242`.
  - [ ] Check log: `cot init mode=Unicast host=<receiver IP> port=4242`.
  - [ ] Ensure routing selects correct NIC (multi‑NIC laptops/docks):
    - Windows: `route print` and `Get-NetIPInterface | Sort-Object InterfaceMetric`
    - Prefer lower metric on the intended interface if needed.

- [ ] Receiver (WinTAK/Listener)
  - [ ] Ensure WinTAK/receiver is listening on the same UDP port (e.g., 4242).
  - [ ] Windows Firewall:
    - Inbound allow UDP 4242:
      ```bat
      netsh advfirewall firewall add rule name="OpenRA CoT UDP 4242 In" dir=in action=allow protocol=UDP localport=4242
      ```
    - Outbound allow (rarely needed, but safe):
      ```bat
      netsh advfirewall firewall add rule name="OpenRA CoT UDP 4242 Out" dir=out action=allow protocol=UDP remoteport=4242
      ```
  - [ ] Verify reception:
    - Wireshark filter: `udp.port == 4242`
    - Or a simple UDP listener (example, if Python available):
      ```bash
      python - << 'PY'
      import socket
      s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      s.bind(("",4242))
      print("Listening on UDP/4242...")
      while True:
          data,addr=s.recvfrom(65535)
          print("from",addr,":",data[:80])
      PY
      ```

- [ ] Network
  - [ ] No AP client isolation/Layer‑2 isolation between devices.
  - [ ] Same IP subnet/VLAN for sender and receiver (or routing allows UDP 4242).

---

## 2) Multicast Checklist

- [ ] Sender (OpenRA)
  - [ ] Confirm CoT settings: `Mode=Multicast`, `Host=239.255.42.42` (recommended), `Port=4242`, `TTL=1`.
  - [ ] Check log: `cot init mode=Multicast host=239.255.42.42 port=4242`.
  - [ ] TTL = 1 to keep traffic on the local broadcast domain.

- [ ] Receivers
  - [ ] Configure app to join the same group/port (`239.255.42.42:4242`).
  - [ ] Windows Firewall inbound UDP 4242 (same rule as Unicast):
    ```bat
    netsh advfirewall firewall add rule name="OpenRA CoT UDP 4242 In" dir=in action=allow protocol=UDP localport=4242
    ```
  - [ ] Verify IGMP join (Windows):
    ```bat
    netsh interface ip show joins
    ```
  - [ ] Verify packets:
    - Wireshark filter: `udp.port == 4242 && ip.dst == 239.255.42.42`

- [ ] Switch/AP (IGMP)
  - [ ] IGMP Snooping: Enabled on managed switches/APs to prevent flooding.
  - [ ] IGMP Querier: Present on the VLAN (router or switch). Without a querier, some devices drop multicast when snooping is enabled.
    - If no L3 gateway is present, enable an IGMP Querier on the switch or temporarily disable snooping for tests.
  - [ ] Wi‑Fi AP options that can affect multicast:
    - “Multicast to Unicast” conversions (sometimes helpful, sometimes harmful) — test both ways.
    - Client Isolation/Layer‑2 Isolation — must be disabled for receivers to get multicast.
  - [ ] Ensure the VLAN allows multicast and that ACLs don’t block 239.0.0.0/8.

- [ ] Routing
  - [ ] TTL=1 prevents the multicast from crossing routers — expected for same‑LAN tests.
  - [ ] If your LAN has multiple L3 segments, either raise TTL and allow routing for group 239.255.42.42 or test within a single segment.

---

## 3) Cross‑Cutting Troubleshooting

- [ ] Confirm OpenRA settings took effect by checking the `cot init` log line.
- [ ] On Windows, ensure outbound UDP isn’t blocked by local security suites.
- [ ] Multi‑NIC systems: verify the correct egress NIC via routing/metrics.
  - Optional (advanced): adjust metrics `Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 10`
- [ ] Verify that no corporate/guest VLAN policies block UDP 4242 or multicast.
- [ ] Packet capture on sender and receiver pinpoints where packets disappear.
  - Sender Wireshark: `udp.port == 4242`
  - Receiver Wireshark (unicast): `udp.port == 4242 && ip.dst == <receiver IP>`
  - Receiver Wireshark (multicast): `udp.port == 4242 && ip.dst == 239.255.42.42`

---

## 4) Linux/macOS Notes (Receivers)

- Linux UFW:
  ```bash
  sudo ufw allow 4242/udp
  ```
- Verify multicast group membership:
  ```bash
  ip maddr show
  # or
  netstat -g
  ```
- Basic UDP listener (Python):
  ```bash
  python3 - << 'PY'
  import socket
  s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  s.bind(("",4242))
  print("Listening on UDP/4242...")
  while True:
      data,addr=s.recvfrom(65535)
      print("from",addr,":",data[:80])
  PY
  ```

---

## 5) Known Pitfalls

- Devices connected to guest Wi‑Fi SSIDs with client isolation will not receive peer traffic.
- No IGMP Querier + IGMP Snooping enabled can silently drop multicast — add a querier or disable snooping.
- APs that rate‑limit or suppress multicast can cause drops; test with “multicast‑to‑unicast” both enabled and disabled.
- Wrong listening port in WinTAK/ATAK (must match OpenRA’s port).
- Multiple NICs with higher metric may steal default route; fix by adjusting interface metrics.
- NIC binding in OpenRA CoT is not yet enforced; OS routing table chooses the egress interface.
