# 🕳️ Black Hole 0.3.3

**Black Hole** is a Windows GUI for running Xray with optional Desync profiles. It
imports a `vless://` link or a full Xray JSON file, replaces only the server
`address` with a Gray IP, and keeps the real `SNI`, `Host` header, TLS settings,
and WebSocket/XHTTP path unchanged.

> ⚠️ Use this tool only on networks and systems where you have permission. The
> app requires Administrator access because packet processing uses system-level
> components.

## ✨ Main Features

- 🧩 Import a `vless://` link or a full Xray JSON config
- 🌫️ Replace only `outbounds -> vnext[0] -> address` with a Gray IP
- 🔒 Keep the real `serverName`, `Host`, WebSocket/XHTTP path, and TLS settings
- 🚀 Ready-made Desync profiles for light, balanced, and severe filtering cases
- 🎛️ Manual controls for Split, Fooling, BadSeq, AutoTTL, Fake SNI, repeats, and ports
- 🖱️ Combo boxes open by clicking anywhere on the field or on the arrow
- 🪟 Optional Windows Proxy setup on `127.0.0.1:1920`
- 💾 Automatic restore for the imported config, Gray IP, and UI settings

## ▶️ Quick Start

1. 📂 Extract the ZIP file completely. Do not run the app from inside the ZIP.
2. 🖱️ Double-click `Start-BlackHole.cmd`.
3. 🛡️ Approve the Administrator prompt.
4. 🔗 Paste a `vless://` link or full Xray JSON into `Xray configuration`.
5. ✅ Click `Validate and import`.
6. 🌫️ Enter the new Gray IP in the `Gray IP` section.
7. 👀 Click `Apply address and preview` and check `Config output`.
8. 🎛️ Choose a `Desync profile`.
9. 🚀 Click `Start connection`.
10. 🛑 Click `Stop connection` to stop. Use `Stop-All.cmd` only when an emergency cleanup is needed.

## 🧭 Main Screen Sections

| Section | Purpose |
|---|---|
| 🕳️ Header | Shows the app name and top status area. |
| 🔴 Status badge | Shows `Stopped`, `Starting`, or `Connected`. |
| 🧩 `1) Xray configuration` | Paste a VLESS link or full Xray JSON. |
| 🌫️ `2) Gray IP` | View the original server address and replace it with a Gray IP. |
| 🎛️ `3) Desync profile` | Select a ready-made profile or use Custom mode. |
| 🪟 `Set Windows proxy...` | Automatically points Windows Proxy to the internal HTTP listener. |
| 🚀 `Start connection` | Starts Desync and Xray with the current settings. |
| 🛑 `Stop connection` | Stops the app processes and restores system state. |

## 🔘 Main Buttons And Controls

| Control | Description |
|---|---|
| `Validate and import` | Validates the config and extracts address, port, SNI, Host, and network type. |
| `Open JSON` | Opens a local Xray JSON file. |
| `Apply address and preview` | Applies the Gray IP only to the `address` field and refreshes the preview. |
| `Start connection` | Prepares the config, then starts Desync and Xray. |
| `Stop connection` | Stops the app-owned processes and restores the previous proxy state. |
| `Save config.json` | Saves the final generated Xray config. |
| `Preview Desync command` | Shows the winws2/Desync command before running it. |
| `Open log folder` | Opens the runtime and log folder. |

## 🧪 Desync Profiles

| Profile | Simple Meaning | Best For |
|---|---|---|
| `Off (normal connection)` | Runs only Xray with Desync disabled. | Baseline testing |
| `Speed - Light split` | Light split without Fake packets. | Better speed and lower overhead |
| `Balanced - BadSeq` | One Fake TLS packet with BadSeq and balanced split. | Daily use |
| `Severe filtering - BadSeq` | Stronger `multidisorder` mode with two Fake packets. | Heavier filtering |
| `SNI spoof - WrongSeq` | Controlled Fake SNI using `hcaptcha.com` and stronger BadSeq. | SNI spoof testing without changing real SNI |
| `Severe filtering - AutoTTL` | Fake packets with AutoTTL and stronger split. | Routes where TTL tricks help |
| `Custom` | Uses the values from `Advanced settings`. | Manual experiments |

## ⚙️ Advanced Settings

| Option | Meaning | Note |
|---|---|---|
| `Split method` | TLS ClientHello splitting method. | Allowed: `multisplit` or `multidisorder` |
| `Split positions` | Positions where the packet is split. | Examples: `midsld`, `1,midsld`, `1,sniext+1,midsld` |
| `Method preventing Fake delivery to server` | Method used to stop the Fake packet from reaching the real destination. | Allowed: `none`, `badseq`, `ttl`, `badsum`, `md5sig` |
| `Bad Sequence Increment` | Wrong TCP sequence value for Fake packets. | Active only when `Fooling = badseq`. |
| `Optional Fake SNI` | Fake SNI used only inside the Fake packet. | Empty means random SNI. Real SNI/Host stay unchanged. |
| `AutoTTL Delta` | TTL delta for AutoTTL mode. | Active only when `Fooling = ttl`. |
| `AutoTTL Min` | Minimum TTL value. | Must be less than or equal to `AutoTTL Max`. |
| `AutoTTL Max` | Maximum TTL value. | Must be greater than or equal to `AutoTTL Min`. |
| `Fake repeats` | Number of Fake packet repeats. | Used only when Fooling is not `none`. |
| `SOCKS Port` | Internal Xray SOCKS port. | Default: `1819` |
| `HTTP Port` | Internal Xray HTTP port and Windows Proxy target. | Default: `1920` |

## 📑 Tabs

| Tab | Purpose |
|---|---|
| `Status` | Shows imported config details: Address, Port, SNI, Host, Network, and Security. |
| `Advanced settings` | Manual Desync and port settings. |
| `Config output` | Final Xray config after applying the Gray IP. |
| `Log` | Runtime events, errors, paths, and connection status. |

## 🌐 Ports And Proxy

```text
SOCKS: 0.0.0.0:1819
HTTP:  0.0.0.0:1920
Windows system proxy: 127.0.0.1:1920
```

When Windows Proxy is enabled, apps that respect the system proxy will use the
internal HTTP proxy at `127.0.0.1:1920`.

## 🧯 Emergency Stop

If the window closes but the connection or proxy remains active:

1. 🛑 Run `Stop-All.cmd`.
2. 🔁 It stops only processes recorded by Black Hole.
3. 🪟 It restores the previous Windows Proxy state when possible.

## 🔐 Privacy And Stored Files

- 🔒 Config, UUID, Gray IP, and settings stay inside the app folder.
- 💾 Main persistent files: `runtime/saved-workspace.json` and `runtime/user-settings.json`
- 🧹 Temporary connection files are removed after stopping.
- 📁 Logs are written inside `runtime`.

## 🛠️ Troubleshooting

| Problem | Fix |
|---|---|
| App does not open | Extract the ZIP first, then run `Start-BlackHole.cmd`. |
| Administrator prompt appears | This is expected for WinDivert and packet processing. |
| Core file is missing | Make sure the full folder was extracted and antivirus did not remove files. |
| Proxy remains enabled after closing | Run `Stop-All.cmd`. |
| Connection does not start | Check the `Log` tab and files inside `runtime`. |
| Gray IP is rejected | Use a literal IPv4 or IPv6 address, not a domain like `example.com`. |

## ⚠️ Disclaimer

This software is provided for educational and research purposes.  
Users are responsible for following the laws and regulations of their own country.

## 👤 Credits

Powered By ReZa Kh