# SSBU Online Deluxe (Quickplay & Stealth Edition)

[![Game Version](https://img.shields.io/badge/SSBU-13.0.5-orange.svg)](https://www.smashbros.com/)
[![Platform](https://img.shields.io/badge/Platform-Nintendo%20Switch%20%7C%20Eden%20Emulator-blue.svg)](https://github.com)
[![Rust](https://img.shields.io/badge/Rust-2021%20Edition-red.svg)](https://www.rust-lang.org/)
[![Skyline](https://img.shields.io/badge/Skyline-Plugin-brightgreen.svg)](https://github.com/skyline-dev/skyline)
[![License](https://img.shields.io/badge/License-GPL%20v3.0-lightgrey.svg)](LICENSE)

An advanced performance, input latency reduction, and networking enhancement mod for **Super Smash Bros. Ultimate (v13.0.5)**.

This repository is an enhanced fork of [saad-script/ssbu-online-deluxe](https://github.com/saad-script/ssbu-online-deluxe), specially engineered to unlock **full input delay reduction and latency slider controls in Official Nintendo Quickplay & Elite Smash**, eliminate matchmaking/transition crashes, and introduce a zero-trace **Stealth Mode** with runtime kernel memory patching.

> [!NOTE]
> ¿Prefieres leer esto en español? Consulta la versión en español: [README_ES.md](README_ES.md).

---

## 🌟 What's New in this Fork?

| Feature | Upstream (saad-script v1.4.1) | This Fork (Quickplay & Stealth Edition) |
| :--- | :--- | :--- |
| **Quickplay & Elite Smash** | ❌ Render profiles & latency slider locked out (vanilla only) | ✅ **Fully Unlocked**: LessLag, LLUltra, LLDoubles, and Latency Slider work in Quickplay & Elite Smash |
| **ssbusync Restriction** | ⚠️ Reverts to Vanilla when entering Quickplay | ✅ **Automated Arena Bypass**: Keeps render profiles active across all online matchmaking |
| **Profile Drift Correction** | ❌ None (profiles can be lost mid-game) | ✅ **Active Drift Detection**: Live per-frame verification re-applies profile if game engine reverts |
| **Matchmaking & Loading Stability** | ⚠️ Crashes on loading screens, stage load & queue shifts | ✅ **Transition Grace Period**: 300-frame guard eliminates transition and pane null-dereference crashes |
| **Stealth Mode (Anti-Detection)** | ❌ Not available (broadcasts mod beacon `0x45` & custom PIA data) | ✅ **Kernel SVC 0x6 Memory Patching**: Zero packet broadcast, suppresses `[Wired]`/`[Wifi]` tags, 100% vanilla appearance |
| **Dynamic Resolution in Quickplay** | ❌ Disabled in Quickplay | ✅ **Enabled**: Maintains smooth frametimes during zoom-in finishes and intensive effects |
| **ssbusync-guest Crash Handler** | ⚠️ Aborts with panic if remote API symbol is missing | ✅ **Patched vendored crate**: Graceful failover with zero crashes |

---

## 🚀 Key Features & Architectural Enhancements

### 1. ⚔️ Full Quickplay & Elite Smash Integration
In the upstream version, SSBU's render optimizations (`ssbusync`) and custom latency adjustments were restricted to Arenas and Local Online. When entering Quickplay on official servers, `ssbusync` detected the lack of an arena flag and forcibly stripped all environment flags, reverting graphics to Vanilla.

- **Dynamic Arena Marking (`ssbusync_restrict_mark_arena_mode`)**: Hooks and injects the arena flag during Quickplay/Elite matchmaking.
- **Smart Refresh Throttling**: ssbusync wipes mode flags across scene transitions; this fork refreshes the arena mark every ~60 frames without flooding the console log.
- **Render Profile Drift Detection**: During real matches, the mod continuously audits live graphics flags against the player's selected profile (`LessLag`, `LLUltra`, etc.) and automatically re-applies it if the engine attempts to revert.
- **Latency Slider in Quickplay**: The 0f–25f input buffer slider is fully functional in official Quickplay and Elite Smash.

### 2. 🛡️ Anti-Crash & Matchmaking Stability System
Quickplay matchmaking involves rapid transitions between background matchmaking, the training waiting room, stage loading, and real matches. Upstream suffered from severe stability issues:

- **Transition Grace Period (`TRANSITION_GRACE_FRAMES = 300`)**: When a scene transition or stage pre-setup begins, unsafe UI pane modifications and ssbusync calls are suspended for a 300-frame (~5-second) buffer window. This prevents crashes while the render pipeline and memory layout are tearing down or rebuilding.
- **Null Pointer Dereference Protection**: Added strict null-pointer validation (`reg_ptr.is_null()`) in the latency slider hook to prevent fatal memory exceptions during rapid scene changes.
- **State Preservation**: Prevents the main menu hook from prematurely resetting `MatchConnectionStatus` to `Offline` during internal Quickplay matchmaking handoffs.
- **Untracked Match Fallback**: Matches that begin without an explicit arena or local handle are automatically recognized and classified as Quickplay instead of entering an invalid state.

### 3. 🕶️ Stealth Mode (Anti-Detection & Privacy Hardening)
When playing online against other modded consoles, `libssbu_pia_manager` appends a 2-byte beacon tag (`[0x45, <connection_byte>]`) to peer-to-peer PIA traffic. This tag reveals your modded status (`is_modded`) and displays `[Wired]` or `[Wifi]` next to your ping. Furthermore, SSBU Online Deluxe by default broadcasts custom 4-byte extended packets (displaying your latency and profile to other users).

Enabling `stealth_mode = true` in `config.toml` provides complete privacy:

- **Kernel-Level Memory Hotpatching**:
  - Uses Nintendo Switch kernel `svcQueryMemory` (SVC 0x6) to dynamically inspect the `.text` segment of `libssbu_pia_manager`.
  - Performs a signature scan to locate the beacon constant and hotpatches:
    ```text
    mov w8, #0x45   --->   mov w8, #0x00
    ```
  - The manager never emits the modded identifier tag. Other modded consoles cannot detect that you are running mods or see connection suffixes.
- **Zero-Packet Broadcast**: Completely unhooks the custom PIA data sender (`send_pia_data_hook`).
- **One-Way (Antisocial) Reception**: Your console remains completely silent and appears 100% vanilla to peers and Nintendo servers, yet you can still view opponents' ping, stability metrics, and profiles.

### 4. ⚡ Dynamic Resolution Scaling (Perf Scaler) in Quickplay
The upstream mod intentionally exited early if Quickplay mode was active. This fork re-enables `sync_guest` dynamic resolution scaling across all online modes, ensuring rock-solid 60 FPS during heavy moves, critical-hit zoom-ins, and Sephiroth’s Gigaflare.

### 5. 📦 Vendored & Hardened `smash-ultelier`
Patched `vendor/smash-ultelier/crates/sync-guest/src/lib.rs` to eliminate:
```rust
panic!("[ssbusync] Unable to read remote api version");
```
If an API version cannot be read or matched, it fails silently and safely rather than crashing the game process.

---

## 🎮 Controls

### Native In-Game UI (Character Select Screen & Arena)

> **Controller Note**: `All Shoulder Buttons` = `L + R + Z` on GameCube Controller, or `ZL + ZR + L + R` on Nintendo Switch Pro Controller / Joy-Cons.

| Action | Input | Description |
| :--- | :--- | :--- |
| **Adjust Latency** | `D-Pad Left` / `D-Pad Right` | Change input delay buffer (`Auto`, `0f` to `25f`) |
| **Change Render Profile** | `D-Pad Up` / `D-Pad Down` | Cycle between profiles (`Auto`, `Vanilla`, `LessLag`, `LLUltra`, `LLDoubles`) |
| **Toggle FPS Boost (FPS++)** | `All Shoulder Buttons + X` | Toggles FPS Boost mode (Emulator only) |
| **Toggle Streamer Mode** | `All Shoulder Buttons + Y` | Instantly show or hide the on-screen native UI |
| **Cycle Opponent Info** | `L + R + D-Pad Left/Right` | Cycle between opponent telemetry in matches with >2 players |

### ImGui Overlay UI (Optional)

| Action | Input | Description |
| :--- | :--- | :--- |
| **Cycle Overlay Mode** | `L + R + D-Pad Down` | Switch between `Hidden`, `Full Info`, and `Performance Info` |
| **Navigate Overlay Rows** | `D-Pad Up` / `D-Pad Down` | Select row in `Full Info Mode` |
| **Adjust Selected Value** | `D-Pad Left` / `D-Pad Right` | Modify value of the highlighted row |
| **FPS Boost via Overlay** | `All Shoulder Buttons + X` | Toggle FPS Boost when `NetProfile` row is highlighted |

---

## 🏎️ Render Profiles Explained

- **Auto**: Automatically selects the optimal profile based on your platform (Console vs. Emulator) and match size (Singles vs. Doubles).
- **Vanilla**: Default game rendering pipeline. Zero graphical or input modifications.
- **LessLag**: Bypasses frame buffering to reduce **3 frames** of native engine input delay. Extremely stable on console.
- **LLUltra (LessLag Ultra)**: Reduces **4 frames** of native input delay.
  - *Console note*: Features dynamic resolution scaling to avoid stutters.
- **LLDoubles (Recommended for 3+ Players)**: Reduces **2 frames** of native input delay with maximum overhead headroom for multi-character chaos.
- **FPS++ Mode (Emulator Only)**: Further reduces input delay on compatible PC emulators.

---

## ⚙️ Configuration (`config.toml`)

Place your configuration file at:
```text
sd:/ultimate/ssbu_online_deluxe/config.toml
```

### Complete Example with Stealth Mode:

```toml
# ==========================================================
# SSBU Online Deluxe - Configuration File
# ==========================================================

# Enable Stealth Mode to conceal modded status from other players.
# When true, you appear completely vanilla to opponents, but can
# still view their telemetry.
stealth_mode = true

# Built-in Switch Overclocker integration.
# Set to 'false' if you use an external sysmodule (e.g., sys-clk)
overclocker = true

[render_profile_config]
# Profile used in menus (recommended: "Vanilla")
menu = "Vanilla"

# Profiles applied for offline matches
offline_match.singles = "Vanilla"
offline_match.doubles = "Vanilla"

# Profiles selected automatically when in 'Auto' mode
online_match.singles = "LessLagUltra"
online_match.doubles = "LessLag"
```

---

## 📦 Installation

> [!WARNING]
> Remove any older standalone **Latency Slider**, **VSync**, or **Less Lag** mods before installing to prevent conflicts.

### Required Prerequisites
Ensure your SD card / emulator has the following installed:
1. **Skyline** (Use the tested version bundled with SSBU Online Deluxe releases)
2. **Arcropolis**
3. **NRO Hook**
4. **Smashline**
5. **imgui-smash**
6. **ssbu-pia-manager**
7. **ssbusync** (Use the companion version provided in releases)

### Directory Structure

Place the files on your SD card (or `sdmc/` on emulator) as shown below:

```text
sdcard/
├── atmosphere/
│   └── contents/
│       ├── 00FF0000A11CE0FF/           <-- (Overclock sysmodule)
│       │   ├── exefs.nsp
│       │   └── flags/boot2.flag
│       └── 01006A800016E000/           <-- SSBU Title ID
│           ├── exefs/
│           │   ├── main.npdm
│           │   └── subsdk9
│           └── romfs/
│               └── skyline/
│                   └── plugins/
│                       ├── libarcropolis.nro
│                       ├── libimgui_smash.nro
│                       ├── libnro_hook.nro
│                       ├── libnx_over.nro
│                       ├── libsmashline_plugin.nro
│                       ├── libssbu_online_deluxe.nro   <-- THIS MOD
│                       ├── libssbu_pia_manager.nro
│                       └── libssbusync.nro
└── ultimate/
    └── ssbu_online_deluxe/
        └── config.toml                         <-- (Optional configuration)
```

---

## 🛠️ Building from Source

### Requirements
- [Rust](https://rustup.rs/) (Nightly toolchain)
- `cargo-skyline` (`cargo install cargo-skyline`)
- Target: `aarch64-skyline-switch`

### Build Command
```bash
cargo skyline build --release
```
The compiled plugin will be located at:
```text
target/aarch64-skyline-switch/release/libssbu_online_deluxe.nro
```

---

## ⚠️ Online Safety & Disclaimer

- **Protocol Conformity**: This mod operates strictly at the P2P networking layer and local render pipeline. Game servers are not involved in P2P traffic exchange.
- **SSBU 13.0.5**: SSBU 13.0.5 does not alter packet validation checks for P2P traffic.
- **Risk Notice**: As with any Nintendo Switch modding on official servers, a non-zero risk of account or console restrictions exists. Use at your own discretion. Enabling `stealth_mode = true` is highly recommended for maximum privacy.

---

## 🙌 Credits & Acknowledgments

This project builds upon pioneering work in the Smash Ultimate research and modding community:

- **[saad-script](https://github.com/saad-script)** — Original creator and maintainer of [ssbu-online-deluxe](https://github.com/saad-script/ssbu-online-deluxe).
- **Bludev** — Seminal SSBU render system research and original Less-Lag / Latency Slider implementations.
- **BlankMauser** — Creator of SsbuSync and smash-ultelier; invaluable architectural guidance on SSBU render internals.
- **Kinnay & NintendoClients Contributors** — Comprehensive network service and PIA protocol documentation.
- **Coolsonickirby** — Creator of `imgui-smash` and `imgui-api`.
- **The HDR Development Team** — For Smashline and moveset hooking infrastructure.
- **Skyline Team** — For the Switch homebrew runtime hooking framework.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** — see the [LICENSE](LICENSE) file for details.
