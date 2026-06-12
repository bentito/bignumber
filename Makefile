# Kindle Big Number Display Makefile

KINDLE_MOUNT = /Volumes/Kindle
KINDLE_DEST = $(KINDLE_MOUNT)/extensions/bignumber
SRC_DIR = src/extensions/bignumber
IMAGES_DIR = $(SRC_DIR)/images
VENV_DIR = .venv
VENV_PIP = $(VENV_DIR)/bin/pip
VENV_PYTHON = $(VENV_DIR)/bin/python3

.PHONY: all images wait-mount check-crlf deploy clean help

all: images

# Help command to guide developers
help:
	@echo "Available Makefile targets:"
	@echo "  make images      - Build the Python venv, install Pillow, and generate number images"
	@echo "  make wait-mount  - Wait / check for Kindle mounted at $(KINDLE_MOUNT)"
	@echo "  make check-crlf  - Scan scripts for fatal Windows CRLF line endings"
	@echo "  make deploy      - Wait for connection, deploy, sync buffers, and eject Kindle safely"
	@echo "  make clean       - Clean temporary macOS artifacts, python venv, and generated images"

# Rule to create virtual environment and install Pillow
$(VENV_DIR):
	@echo "Creating Python virtual environment in $(VENV_DIR)..."
	python3 -m venv $(VENV_DIR)
	@echo "Installing Pillow..."
	$(VENV_PIP) install --quiet Pillow

# Rule to generate images
images: $(VENV_DIR)
	@echo "Generating 600x800 grayscale number PNGs..."
	$(VENV_PYTHON) scripts/generate_images.py $(IMAGES_DIR)

# Wait for Kindle to be mounted (blocks if not connected)
wait-mount:
	@if [ ! -d "$(KINDLE_MOUNT)" ]; then \
		echo "Kindle is not currently mounted at $(KINDLE_MOUNT)."; \
		echo "Please connect your Kindle via USB (or press Ctrl+C to cancel)..."; \
		while [ ! -d "$(KINDLE_MOUNT)" ]; do \
			sleep 1; \
		done; \
		echo "Kindle connection detected!"; \
		sleep 1; \
	fi
	@echo "Kindle mount verified."

# Check for CRLF line endings in src/
check-crlf:
	@echo "Scanning for Windows CRLF line endings in $(SRC_DIR)..."
	@if grep -r -I -l $$'\r' $(SRC_DIR)/; then \
		echo "Error: Found CRLF line endings in the scripts above!"; \
		echo "They will cause legacy Linux execution to fail. Please convert to LF."; \
		exit 1; \
	else \
		echo "No CRLF line endings detected. Clean!"; \
	fi

# Deploy files to Kindle
deploy: images wait-mount check-crlf
	@echo "Enforcing execution permissions on shell scripts..."
	@chmod +x $(SRC_DIR)/*.sh 2>/dev/null || true
	@echo "Deploying bignumber extension to Kindle at $(KINDLE_DEST)..."
	@mkdir -p "$(KINDLE_DEST)"
	rsync -rtv --delete --exclude='.DS_Store' $(SRC_DIR)/ "$(KINDLE_DEST)/"
	@echo "Flushing filesystem buffers..."
	@sync
	@sleep 2
	@echo "Ejecting Kindle safely..."
	@diskutil eject "$(KINDLE_MOUNT)" || echo "Warning: Could not eject Kindle automatically. Please eject manually."
	@echo ""
	@echo "============================================================"
	@echo " Kindle has been safely ejected! You can now unplug it."
	@echo "============================================================"
	@echo ""

# Clean up build/deployment artifacts
clean:
	@echo "Cleaning workspace of macOS artifacts, virtual environments, and generated images..."
	rm -rf $(VENV_DIR)
	rm -rf $(IMAGES_DIR)
	find . -name ".DS_Store" -depth -exec rm {} \;
	@echo "Clean completed successfully."
