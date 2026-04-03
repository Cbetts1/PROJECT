# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Makefile for AIOSCPU disk image
#
# Targets:
#   all    - build the disk image (default)
#   image  - alias for all
#   clean  - remove build artifacts
#   help   - show this help

SHELL        := /usr/bin/env bash
SCRIPT       := ./build-image.sh
OUTPUT_IMG   := aioscpu-debian-amd64.img
WORK_DIR     := work

.PHONY: all image clean help

## Default target: build the image
all: image

## Build the AIOSCPU disk image (requires root / sudo)
image:
	@echo "[AIOSCPU] Building disk image..."
	@sudo bash $(SCRIPT)
	@echo "[AIOSCPU] Done. Image: $(OUTPUT_IMG)"

## Remove generated image and work directory
clean:
	@echo "[AIOSCPU] Cleaning build artifacts..."
	rm -rf $(WORK_DIR) $(OUTPUT_IMG)
	@echo "[AIOSCPU] Clean complete."

## Show usage information
help:
	@echo ""
	@echo "  AIOSCPU Image Builder"
	@echo "  © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal"
	@echo ""
	@echo "  Usage: make [target]"
	@echo ""
	@echo "  Targets:"
	@echo "    all / image   Build the AIOSCPU disk image (default)"
	@echo "    clean         Remove build artifacts and work directory"
	@echo "    help          Show this help message"
	@echo ""
	@echo "  Requirements:"
	@echo "    debootstrap, parted, losetup, mkfs.ext4, rsync, grub-pc-bin"
	@echo "    Must be run as root or with sudo."
	@echo ""
