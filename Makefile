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

DEVICE ?= fenix847mm
KEY    ?= $(HOME)/.garmin/developer_key.der

# Connect IQ SDK Detection
SDK_CFG := $(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
SDK     ?= $(shell cat "$(SDK_CFG)" 2>/dev/null | tr -d '\n')
BIN     := $(if $(SDK),$(SDK)/bin/,)

MONKEYC   := "$(BIN)monkeyc"
MONKEYDO  := "$(BIN)monkeydo"
CONNECTIQ := "$(BIN)connectiq"

.PHONY: build build-submariner build-daytona \
        install install-submariner install-daytona \
        sim-submariner sim-daytona \
        generate-key clean check

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
		echo "Install with Homebrew: brew install openjdk@21"; \
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

install-submariner: build-submariner
	@which mtp-sendfile >/dev/null 2>&1 || { \
		echo "ERROR: mtp-sendfile not found."; \
		echo "Install with Homebrew: brew install libmtp"; \
		exit 1; \
	}
	@echo "Sending Submariner.prg to Garmin fenix 8 (GARMIN/Apps)..."
	mtp-sendfile bin/Submariner.prg 16777227
	@echo "Submariner installed successfully!"

install-daytona: build-daytona
	@which mtp-sendfile >/dev/null 2>&1 || { \
		echo "ERROR: mtp-sendfile not found."; \
		echo "Install with Homebrew: brew install libmtp"; \
		exit 1; \
	}
	@echo "Sending RolexDaytona.prg to Garmin fenix 8 (GARMIN/Apps)..."
	mtp-sendfile bin/RolexDaytona.prg 16777227
	@echo "Rolex Daytona installed successfully!"

install: build
	@which mtp-sendfile >/dev/null 2>&1 || { \
		echo "ERROR: mtp-sendfile not found."; \
		echo "Install with Homebrew: brew install libmtp"; \
		exit 1; \
	}
	@echo "1/2: Sending Submariner.prg to Garmin fenix 8 (GARMIN/Apps)..."
	mtp-sendfile bin/Submariner.prg 16777227
	@echo "2/2: Sending RolexDaytona.prg to Garmin fenix 8 (GARMIN/Apps)..."
	mtp-sendfile bin/RolexDaytona.prg 16777227
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
