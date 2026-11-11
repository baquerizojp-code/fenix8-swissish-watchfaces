# AGENTS.md: Developer & AI Agent Guide for Garmin fēnix 8 Watch Faces

This guide provides full instructions for AI coding assistants (**Antigravity**, **Claude Code**, **OpenAI Codex**, **Cursor**, etc.) and human developers working with this repository.

---

## 1. Project Overview & Hardware Target

A collection of luxury watch faces engineered specifically for the **Garmin fēnix 8 AMOLED 47mm** (Model: Sapphire, Titanium, Part Number: `010-02904-10`).

- **Connect IQ Product ID:** `fenix847mm`. Covers fēnix 8 47mm/51mm AMOLED, tactix 8, and quatix 8.
- **Display:** 454×454, round, **AMOLED**. CIQ API Level 6.0 (`minApiLevel="5.1.0"`).
- **Memory Limit:** Strict **128 KB** (131,072 bytes) heap memory limit.
  - Large dial background bitmaps reside in the Graphics Memory Pool and are loaded on-demand via `WatchUi.loadResource` one at a time to prevent heap exhaustion.
- **Physical Bezel Integration:** The watch face covers ONLY the inner dial disc and hands. **Do NOT draw a rotating outer bezel**; the Garmin fēnix 8 already has a physical titanium bezel.
- **Hardware Finish & Color Accent:** Garmin Spark Orange (`0xF39520`) matches the physical silicone strap and sensor guard button flank.

---

## 2. Hard AMOLED Rules (Mandatory)

Garmin OS automatically blanks any watch face that violates these AMOLED limits:

1. **Luminance Limit in Always-On (AOD):** Must stay strictly under **10% total screen luminance**.
   - Full dial background bitmaps **must be suppressed** in sleep mode.
   - Sleep mode background must be pitch black (`0x000000`).
2. **Burn-in Protection:** Static elements on the always-on face must drift up to ±4 px per minute (e.g. `(clock.min % 7) - 3`).
3. **Redraw Rate:** In sleep mode, updates occur once per minute (`onUpdate`). Per-second updates are prohibited.
4. **Testing:** Verify changes in the simulator using **Settings > Low Power Mode** and **File > View Screen Heat Map**.

---

## 3. Public Watch Faces in this Repo

### 1. Rolex Submariner Date (`apps/submariner/`)
- **App UUID:** `9e27ade869c648b2a2b41bbc84ad6640`
- **Binary:** `bin/Submariner.prg`
- **5 Selectable Dial Styles:**
  1. Submariner Date Black (`116610LN`) [DEFAULT]
  2. Submariner Date Hulk Green (`116610LV`)
  3. Submariner Date Polar White (Spark Edition)
  4. Submariner Date Stealth Black (Spark Edition)
  5. Submariner Date Full Spark Orange
- **Handset & Complications:** 3D beveled Mercedes handset with white gold framing and lume channels, Cyclops 2.5× date aperture at (380, 231) with touch-to-open Garmin Calendar.

### 2. Rolex Cosmograph Daytona (`apps/daytona/`)
- **App UUID:** `16022679ae9d46a19a6550da58899196`
- **Binary:** `bin/RolexDaytona.prg`
- **3 Selectable Dial Styles:**
  1. Daytona Panda (`126500LN-0001`) [DEFAULT]
  2. Daytona Classic Black (`126500LN-0002`)
  3. Daytona Spark Orange Racing (Fēnix 8 Edition)
- **Subdial Architecture (Hybrid Luxury):**
  - **9 o'clock Subdial:** Battery gauge needle + micro digital readout (`"85%"`)
  - **6 o'clock Subdial:** Running seconds needle (sweeps 0-60s) + micro digital steps (`"8,420"`)
  - **3 o'clock Subdial:** Heart rate gauge needle + micro digital HR (`"72 bpm"`)
- **Touch Support:** Tapping any subdial launches the corresponding Garmin glance (Battery, Steps/Activity, Heart Rate).
- **Handset:** Authentic Daytona baton handset with central groove and Chromalight lume, fine chronograph seconds needle with arrow pip and round counterweight balance.

---

## 4. Automated Agent Workflow (How to Build & Install)

When the user asks you (an AI agent) to build or install the watch faces on their watch, execute this protocol sequentially:

### Phase 1: Environment & Tool Verification
Execute the following verification checks:

1. **Java Runtime:**
   ```bash
   java -version
   ```
   *If missing:* macOS `brew install openjdk@21`; Linux `sudo apt install openjdk-21-jre`.

2. **Garmin Connect IQ SDK:**
   Verify `current-sdk.cfg` exists: macOS `~/Library/Application Support/Garmin/ConnectIQ/`, Linux `~/.Garmin/ConnectIQ/`. Run `make check`.
   *If missing:* Direct the user to install the SDK and download the `fenix847mm` device target via Garmin's Connect IQ SDK Manager (`https://developer.garmin.com/connect-iq/sdk/`).

3. **Developer Key (`developer_key.der`):**
   Verify `~/.garmin/developer_key.der` exists.
   *If missing:* Run:
   ```bash
   make generate-key
   ```
   This automatically generates a 4096-bit RSA developer key at `~/.garmin/developer_key.der`.

4. **MTP CLI Tool:**
   ```bash
   which mtp-sendfile
   ```
   *If missing:* macOS `brew install libmtp`; Linux `sudo apt install mtp-tools` (Fedora: `libmtp-examples`).

5. **Watch Model (`DEVICE`):**
   Ask the user which watch they have and map it to a `DEVICE` (see README "Supported Watches"): `fenix847mm` (fēnix 8 47/51mm AMOLED, tactix 8, quatix 8, default) or `fenix8pro47mm` (fēnix 8 Pro). Other models are not supported; do not build for them.

### Phase 2: Pre-Sideload Checklist
Before running the install command:
1. **Garmin Express Check:** Close Garmin Express so it does not hold an exclusive lock on the USB interface:
   ```bash
   pkill -f "Garmin Express" || true
   ```
2. **Watch Connection:** Ensure the Garmin fēnix 8 is connected via USB cable and set to **MTP Mode** (*Settings > System > Advanced > USB Mode > MTP*).

### Phase 3: Build & Sideload
Compile and transfer both watch faces in one shot (add `DEVICE=<id>` for non-default models):
```bash
make install
```
* Or for an individual watch face:
  ```bash
  make install-submariner  # Only Submariner
  make install-daytona     # Only Daytona
  ```

*Folder Destination:* files go to the `/GARMIN/Apps` path on the watch (override with `MTP_DIR=...`). The Makefile fails loudly if the folder or device is not found.

*No device found:* if the watch is set to MTP but not detected, have the user power-cycle the watch and reconnect; the USB mode change only applies after a restart.

*GUI Fallback:* If MTP command fails (e.g., USB permission denied or no libmtp):
1. Run `make build` to generate the `.prg` files in `bin/`.
2. Inform the user to open **OpenMTP** (macOS) or their file manager (Linux) and drag `bin/Submariner.prg` and `bin/RolexDaytona.prg` into the `GARMIN/Apps/` folder on the watch storage.

### Phase 4: User Instructions
Tell the user:
1. Disconnect the watch from the USB cable.
2. Long-press the screen (or hold the middle-left button) to open the Watch Face selector.
3. Select **Submariner** or **Rolex Daytona**.
4. Tap **Customize** to pick your preferred dial colorway and seconds hand accent!

---

## 5. Code Architecture

Each watch face under `apps/<name>/` is a fully self-contained Connect IQ application:

- `manifest.xml`: Contains the unique App UUID, target devices (`fenix847mm`, `fenix8pro47mm`), and permissions (such as `ComplicationSubscriber` for touch-to-glance navigation).
- `monkey.jungle`: Monkey C build jungle setting (`project.manifest = manifest.xml`).
- `source/FaceApp.mc`: App lifecycle entry point; instantiates View and Delegate.
- `source/FaceView.mc`: Core rendering engine:
  - Full-power render path: High-resolution dial bitmap, date/subdials, custom anti-aliased hands.
  - Low-power Always-On (AOD) path: Pure black background, dimmed vector markers, <10% screen luminance, minute-by-minute anti-burn-in drift.
  - Memory management: `WatchUi.loadResource` loads only 1 dial bitmap at a time, releasing previous references before loading new styles.
- `source/FaceDelegate.mc`: Handles on-device settings edits (`onWatchFaceConfigEdited`) and touch interactions (`onPress` to deep-link to Garmin Calendar, Battery, Steps, or HR glances).
- `source/Theme.mc`: Horological color definitions, `SPARK_ORANGE` (`0xF39520`), style IDs, and `dim()` calculation.
- `resources/configs/watchface.xml`: On-device customization menu (styles, accent colors, lume colors).
- `resources/drawables/`: Launcher icon and 454×454 dial background PNGs.

---

## 6. Development & Testing Commands

```bash
make build             # Compiles Submariner and Daytona
make install           # Compiles and sideloads both to fenix 8 via MTP
make sim-submariner    # Launches Connect IQ simulator with Submariner
make sim-daytona       # Launches Connect IQ simulator with Daytona
make clean             # Deletes bin/
```
