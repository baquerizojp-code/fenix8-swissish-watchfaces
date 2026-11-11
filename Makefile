# Rolex Luxury Watch Faces for Garmin fēnix 8 AMOLED 47mm
#
# Primary Targets:
#   make build              compile both Submariner.prg and RolexDaytona.prg
#   make build-submariner   compile bin/Submariner.prg
#   make build-daytona      compile bin/RolexDaytona.prg
#   make install            compile and sideload Submariner and Daytona to watch via MTP!
#   make install-submariner sideload only Submariner to watch
#   make install-daytona    sideload only Rolex Daytona to watch
#   make sim-submariner     open Connect IQ simulator with Submariner
#   make sim-daytona        open Connect IQ simulator with Rolex Daytona
#   make generate-key       auto-generate ~/.garmin/developer_key.der if missing
#   make check              verify Java, monkeyc compiler, and developer key
#
# Other watch models: pass DEVICE, e.g. make install DEVICE=fenix8pro47mm
#   fenix847mm     fēnix 8 47mm/51mm AMOLED, tactix 8, quatix 8 (default)
#   fenix8pro47mm  fēnix 8 Pro 47mm/51mm (AMOLED & MicroLED), quatix 8 Pro

DEVICE  ?= fenix847mm
KEY     ?= $(HOME)/.garmin/developer_key.der
MTP_DIR ?= /GARMIN/Apps

# Connect IQ SDK Detection (macOS or Linux SDK Manager)
UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
SDK_CFG := $(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
PKG_HINT := brew install libmtp
JAVA_HINT := brew install openjdk@21
else
SDK_CFG := $(HOME)/.Garmin/ConnectIQ/current-sdk.cfg
PKG_HINT := sudo apt install mtp-tools  (Fedora: sudo dnf install libmtp-examples)
JAVA_HINT := sudo apt install openjdk-21-jre  (Fedora: sudo dnf install java-21-openjdk)
endif
SDK     ?= $(shell cat "$(SDK_CFG)" 2>/dev/null | tr -d '\n')
BIN     := $(if $(SDK),$(SDK)/bin/,)

MONKEYC   := "$(BIN)monkeyc"
MONKEYDO  := "$(BIN)monkeydo"
CONNECTIQ := "$(BIN)connectiq"

.PHONY: build build-submariner build-daytona \
        install install-submariner install-daytona \
        sim-submariner sim-daytona \
        generate-key clean check check-mtp

# Send one .prg to the watch. mtp-sendfile exits 0 even when the folder is
# missing, so its output is checked for the failure message.
define mtp_send
	@echo "Sending $(1) to $(MTP_DIR) on the watch..."
	@out=$$(mtp-sendfile "$(1)" "$(MTP_DIR)" 2>&1); status=$$?; echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -qiE "could not be found|no devices|error"; then \
		echo "ERROR: transfer failed. Check the watch is in MTP mode and Garmin Express is closed."; \
		echo "Fallback: copy $(1) to GARMIN/Apps with OpenMTP (macOS) or your file manager (Linux)."; \
		exit 1; \
	fi
endef

generate-key:
	@if [ -f "$(KEY)" ]; then \
		echo "Developer key already exists at $(KEY)"; \
	else \
		mkdir -p $(HOME)/.garmin && \
		openssl genpkey -algorithm RSA -outform DER -out "$(KEY)" -pkeyopt rsa_keygen_bits:4096 && \
		echo "Generated 4096-bit developer key at $(KEY)"; \
	fi

check:
	@java -version >/dev/null 2>&1 || { \
		echo "ERROR: Java not found."; \
		echo "Install with: $(JAVA_HINT)"; \
		exit 1; \
	}
	@test -x $(MONKEYC) || { \
		echo "ERROR: Connect IQ compiler (monkeyc) not found."; \
		echo "Install Garmin Connect IQ SDK via SDK Manager:"; \
		echo "https://developer.garmin.com/connect-iq/sdk/"; \
		exit 1; \
	}
	@test -f "$(KEY)" || { \
		echo "ERROR: Developer key not found at $(KEY)."; \
		echo "Run 'make generate-key' or create one via Connect IQ SDK Manager."; \
		exit 1; \
	}

build-submariner: check
	@mkdir -p bin
	$(MONKEYC) -d $(DEVICE) -f apps/submariner/monkey.jungle -o bin/Submariner.prg -y "$(KEY)" -w -l 3
	@echo "Built: bin/Submariner.prg"

build-daytona: check
	@mkdir -p bin
	$(MONKEYC) -d $(DEVICE) -f apps/daytona/monkey.jungle -o bin/RolexDaytona.prg -y "$(KEY)" -w -l 3
	@echo "Built: bin/RolexDaytona.prg"

build: build-submariner build-daytona

check-mtp:
	@which mtp-sendfile >/dev/null 2>&1 || { \
		echo "ERROR: mtp-sendfile not found."; \
		echo "Install with: $(PKG_HINT)"; \
		exit 1; \
	}

install-submariner: build-submariner check-mtp
	$(call mtp_send,bin/Submariner.prg)
	@echo "Submariner installed successfully!"

install-daytona: build-daytona check-mtp
	$(call mtp_send,bin/RolexDaytona.prg)
	@echo "Rolex Daytona installed successfully!"

install: build check-mtp
	$(call mtp_send,bin/Submariner.prg)
	$(call mtp_send,bin/RolexDaytona.prg)
	@echo "All watch faces installed successfully! Select 'Submariner' or 'Rolex Daytona' from your watch face menu."

sim-submariner: build-submariner
	$(CONNECTIQ) &
	@sleep 2
	$(MONKEYDO) bin/Submariner.prg $(DEVICE)

sim-daytona: build-daytona
	$(CONNECTIQ) &
	@sleep 2
	$(MONKEYDO) bin/RolexDaytona.prg $(DEVICE)

clean:
	rm -rf bin

# Optional local overrides / targets (ignored in git)
-include Makefile.local
