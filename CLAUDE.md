# CLAUDE.md: Instructions for Claude Code

Claude Code reads this file when working in this repository. The universal guide for AI coding agents is in `AGENTS.md`.

---

## Quick Commands

```bash
# Verification & Key Generation
make check             # Verify Java, monkeyc, and developer key
make generate-key      # Auto-generate ~/.garmin/developer_key.der (4096-bit RSA)

# Compilation
make build             # Compile Submariner.prg and RolexDaytona.prg
make build-submariner  # Compile only Submariner.prg
make build-daytona     # Compile only RolexDaytona.prg

# Sideloading (Garmin fēnix 8 via MTP)
make install           # Compile & sideload Submariner & Daytona
make install-submariner # Sideload Submariner only
make install-daytona    # Sideload Daytona only

# Simulator
make sim-submariner    # Launch CIQ simulator with Submariner
make sim-daytona       # Launch CIQ simulator with Daytona

# Cleanup
make clean             # Remove compiled binaries
```

---

## Automated Agent Installation Flow

When the user asks you to install the watch faces on their watch:

1. **Verify Environment:**
   - Run `java -version`. If missing: `brew install openjdk@21`.
   - Check if `~/.garmin/developer_key.der` exists. If missing, run `make generate-key`.
   - Check if `mtp-sendfile` exists (`which mtp-sendfile`). If missing: `brew install libmtp`.
2. **Pre-sideload Steps:**
   - Kill Garmin Express to free the USB connection: `pkill -f "Garmin Express" || true`.
   - Remind the user that the watch must be plugged in via USB and set to **MTP Mode** (*Settings > System > Advanced > USB Mode > MTP*).
3. **Install:**
   - Run `make install`.
   - If MTP CLI fails due to permissions, tell the user to open **OpenMTP** or **Android File Transfer** and copy `bin/*.prg` to `GARMIN/Apps/` on the watch.
4. **Post-install Instructions for User:**
   - Disconnect USB.
   - Long-press screen or hold middle-left button.
   - Select Watch Face (`Submariner` or `Rolex Daytona`) and tap **Customize**.

---

## Coding Guidelines

- **Target:** Garmin fēnix 8 AMOLED 47mm (`fenix847mm`), 454×454 round AMOLED.
- **Memory:** Strict 128 KB heap limit. Keep bitmaps loaded on demand (`WatchUi.loadResource`).
- **AMOLED Rules:** Sleep mode must be pure black (`0x000000`) with <10% screen luminance and minute drift (±3px) against burn-in.
- **Bezel Rule:** Never draw an outer dive bezel; the physical titanium bezel frames the dial.
- **Model Selection:** `opus` for Monkey C code and AMOLED burn-in review; `sonnet` for docs, Makefile, and resource updates.
