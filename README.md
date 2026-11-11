# Luxury Rolex Watch Faces for Garmin fēnix 8 AMOLED 47mm

An authentic, high-fidelity luxury watch face collection designed and engineered specifically for the **Garmin fēnix 8 AMOLED 47mm** (Sapphire, Titanium with Spark Orange/Graphite Band, Ref. `010-02904-10`).

Includes the **Rolex Submariner Date** (5 selectable styles) and the **Rolex Cosmograph Daytona** (3 selectable styles with live interactive subdials), featuring strict AMOLED burn-in protection, custom 3D handsets, and exact hardware color matching.

---

## The Watch Face Collections

### 1. Rolex Submariner Date (`apps/submariner/`)
- **5 On-Device Selectable Styles:**
  1. **Submariner Date Black (`116610LN`):** The timeless classic deep black matte dial with polished Maxi-Dial markers and crisp white typography.
  2. **Submariner Date Hulk Green (`116610LV`):** The iconic sunburst emerald green dial face.
  3. **Submariner Date Polar White (Spark Edition):** Arctic white dial with phantom gunmetal markers, high-contrast hands, and "SUBMARINER" in **Garmin Spark Orange** (homage to Explorer II Polar).
  4. **Submariner Date Stealth Black (Spark Edition):** Matte black dial with "SUBMARINER" in **Garmin Spark Orange** (homage to the Single Red Submariner 1680).
  5. **Submariner Date Full Spark Orange:** Full vibrant sunburst Spark Orange dial matching the fēnix 8's silicone strap and button protector.
- **Handset & Complications:** 3D beveled Mercedes hour hand, sword minute hand, lollipop seconds hand with customizable accent colors, and a live 2.5× Cyclops date window at 3 o'clock (touch-and-hold launches Garmin Calendar).

---

### 2. Rolex Cosmograph Daytona (`apps/daytona/`)
- **3 On-Device Selectable Styles:**
  1. **Daytona Panda (`126500LN-0001`):** High-contrast lacquer white dial with black snailed chronograph rings.
  2. **Daytona Classic Black (`126500LN-0002`):** Sunray black dial with silver snailed rings.
  3. **Daytona Spark Orange Racing:** Custom Fēnix 8 racing edition with Spark Orange accents.
- **Live Interactive Subdial Architecture:**
  - **9 o'clock Subdial:** Battery reserve needle gauge + micro digital battery percentage (`85%`). Tapping launches Garmin Battery manager.
  - **6 o'clock Subdial:** Running seconds needle (sweeps 0–60s) + micro digital step counter (`8,420`). Tapping launches Garmin Activity/Steps glance.
  - **3 o'clock Subdial:** Heart rate gauge needle + micro digital HR readout (`72 bpm`). Tapping launches Garmin Heart Rate glance.
- **Handset:** 18ct white gold baton handset with Chromalight luminescence and fine chronograph seconds needle with arrow counterweight.

---

## Hardware & AMOLED Protection

- **Target Device:** Connect IQ product ID `fenix847mm` (454×454, round, AMOLED, CIQ API Level 6.0).
- **Physical Bezel Integration:** Designed exclusively for the inner dial disc and hands. It intentionally omits any simulated ceramic bezel, framing the watchface directly against the watch's physical titanium bezel.
- **Hardware Color Match:** Seconds hand and dial accents default to **Garmin Spark Orange** (`0xF39520`), matching the watch's silicone strap and flank sensor guard.
- **Strict AMOLED Always-On (AOD) Protection:**
  - Screen luminance is maintained strictly **under 10%** in low-power mode.
  - In sleep mode, full-color dial backgrounds are turned completely off to pitch black (`0x000000`).
  - Geometric markers and hands drift ±3 pixels per minute to prevent OLED burn-in.

---

## 🤖 One-Shot Install with an AI Agent

If you use an AI coding assistant such as **Claude Code**, **Google Antigravity**, **Cursor**, or **OpenAI Codex**, the agent can build and install the watch faces for you automatically!

1. Connect your Garmin fēnix 8 to your computer via USB.
2. Ensure the watch is in **MTP mode** (*Settings > System > Advanced > USB Mode > MTP*).
3. Close Garmin Express.
4. Clone this repository and ask your agent:
   > *"Build and install these watch faces on my connected Garmin fēnix 8."*

The repository includes [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md), giving the agent step-by-step instructions to verify your environment, auto-generate keys, compile the binaries, and sideload them to your watch!

---

## 🛠️ Manual Installation Guide (For Humans)

### Prerequisites

1. **Java Runtime (JDK 17 or 21):**
   ```bash
   # macOS (Homebrew)
   brew install openjdk@21
   ```
2. **Garmin Connect IQ SDK:**
   - Download the **Connect IQ SDK Manager**: [Garmin Developer Site](https://developer.garmin.com/connect-iq/sdk/)
   - Open SDK Manager and download the latest SDK.
   - In SDK Manager under **Devices**, download the **fēnix® 8 47mm** (`fenix847mm`).
3. **Developer Key (`developer_key.der`):**
   - You need a 4096-bit RSA developer key to sign Connect IQ apps.
   - Run the included command to generate one instantly:
     ```bash
     make generate-key
     ```
     *(This creates `~/.garmin/developer_key.der`).*
4. **MTP Transfer Tool (macOS):**
   ```bash
   brew install libmtp
   ```

---

### Step-by-Step Installation

#### 1. Prepare Watch Connection
1. Connect your Garmin fēnix 8 to your computer via USB.
2. On the watch, when prompted (or in *Settings > System > Advanced > USB Mode*), choose **MTP**.
3. **Important:** Make sure **Garmin Express is closed completely**; otherwise, it will lock the USB interface and prevent MTP file transfers.

#### 2. Option A: One-Command Sideload (`make install`)
Run:
```bash
make install
```
This will:
1. Verify Java, the Connect IQ compiler, and developer key.
2. Compile both `bin/Submariner.prg` and `bin/RolexDaytona.prg`.
3. Sideload both watch faces directly into `GARMIN/Apps/` on your watch via MTP.

#### 3. Option B: Manual Drag-and-Drop (OpenMTP or Android File Transfer)
If you prefer a graphical tool or are on Windows/Linux:
1. Compile the binaries:
   ```bash
   make build
   ```
   *(Creates `bin/Submariner.prg` and `bin/RolexDaytona.prg`).*
2. Open **OpenMTP** or **Android File Transfer**.
3. Navigate to `GARMIN/Apps/` on the watch storage.
4. Drag and drop `bin/Submariner.prg` and `bin/RolexDaytona.prg` into `GARMIN/Apps/`.

---

## Customizing on the Watch

1. Disconnect the watch from USB.
2. On your watch face, **long-press the screen** (or hold the middle-left button).
3. Select **Watch Face** from the menu.
4. Scroll to **Submariner** or **Rolex Daytona** and tap **Apply**.
5. Tap **Customize** to choose your preferred dial colorway, accent colors, and lume preferences!

---

## Useful Makefile Commands

```bash
make build             # Compile Submariner and Daytona
make install           # Compile and sideload both to watch via MTP
make build-submariner  # Compile only Submariner
make build-daytona     # Compile only Rolex Daytona
make install-submariner # Sideload only Submariner
make install-daytona   # Sideload only Rolex Daytona
make sim-submariner    # Launch Connect IQ simulator with Submariner
make sim-daytona       # Launch Connect IQ simulator with Rolex Daytona
make generate-key      # Auto-generate ~/.garmin/developer_key.der
make check             # Verify development tools & environment
make clean             # Clean up compiled binaries
```

---

## Troubleshooting

- **Error: `mtp-sendfile: Device or resource busy`:**
  - Garmin Express or another MTP app is running in the background. Quit Garmin Express completely (`pkill -f "Garmin Express"`).
- **Error: `monkeyc not found`:**
  - Make sure you downloaded the SDK via Garmin Connect IQ SDK Manager and set it as the active SDK.
- **Error: `Developer key not found`:**
  - Run `make generate-key` to create one automatically at `~/.garmin/developer_key.der`.

---

## License & Disclaimer

Released under the [MIT License](LICENSE). You are free to use, modify, and share it.

Personal project created for watch enthusiasm and technical experimentation on Garmin Connect IQ hardware. Not affiliated with, sponsored by, or endorsed by Rolex SA or Garmin Ltd. Rolex, Submariner, Daytona, Garmin, and fēnix are trademarks of their respective owners; the MIT License covers this code only and grants no rights to those marks.
