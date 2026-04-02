# AIOS Makefile — Build automation for Portable AI Operating System
#
# Usage:
#   make                   # show help
#   make build             # compile llama.cpp (hosted mode)
#   make install           # run full installation (Termux/hosted)
#   make image             # build bootable USB image
#   make test              # run all tests
#   make health            # run health check
#   make clean             # remove build artifacts

SHELL := /bin/bash
AIOS_ROOT := $(shell pwd)
OS_ROOT := $(AIOS_ROOT)/OS
JOBS := $(shell nproc)

.PHONY: all help build install image rootfs model first-boot \
        optimize test unit-test integration-test mobile-test \
        health benchmark clean start-daemon stop-daemon

all: help

help:
	@echo "AIOS — Portable AI Operating System"
	@echo
	@echo "Usage: make <target>"
	@echo
	@echo "Build:"
	@echo "  build              Compile llama.cpp for hosted mode"
	@echo "  rootfs             Build compressed squashfs rootfs image"
	@echo "  image              Build bootable USB image (standalone mode)"
	@echo
	@echo "Install:"
	@echo "  install            Full hosted-mode installation (Termux)"
	@echo "  model              Download quantized Llama model"
	@echo "  first-boot         Run first-boot initialization"
	@echo "  optimize           Apply S21 FE hardware optimizations"
	@echo
	@echo "Run:"
	@echo "  start              Boot AIOS (runs OS/sbin/init)"
	@echo "  start-daemon       Start Llama inference daemon in background"
	@echo "  stop-daemon        Stop Llama inference daemon"
	@echo
	@echo "Test:"
	@echo "  test               Run all tests"
	@echo "  unit-test          Run unit tests"
	@echo "  integration-test   Run integration tests"
	@echo "  mobile-test        Run S21 FE compatibility tests"
	@echo "  health             Run health check diagnostics"
	@echo "  benchmark          Run performance benchmarks"
	@echo
	@echo "Maintenance:"
	@echo "  clean              Remove build artifacts"

# ── Build targets ─────────────────────────────────────────────────────────────

build:
	@echo "Building llama.cpp..."
	@JOBS=$(JOBS) bash build/build.sh --target hosted

rootfs:
	@echo "Building rootfs squashfs..."
	@bash build/rootfs-builder.sh

image:
	@echo "Building bootable USB image..."
	@bash build/build.sh --target image

# ── Install targets ───────────────────────────────────────────────────────────

install:
	@echo "Installing AIOS (hosted mode)..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash deploy/container-installer.sh

model:
	@echo "Downloading Llama model..."
	@AIOS_HOME="$(AIOS_ROOT)" bash ai/model-quantizer/download-model.sh

first-boot:
	@echo "Running first-boot initialization..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash deploy/first-boot.sh

optimize:
	@echo "Applying phone optimizations..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash deploy/phone-optimizations.sh

# ── Run targets ───────────────────────────────────────────────────────────────

start:
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash OS/sbin/init

start-daemon:
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash ai/inference-engine/start-daemon.sh --background

stop-daemon:
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash ai/inference-engine/stop-daemon.sh

# ── Test targets ──────────────────────────────────────────────────────────────

test: unit-test integration-test mobile-test

unit-test:
	@echo "Running unit tests..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash tests/unit-tests.sh

integration-test:
	@echo "Running integration tests..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash tests/integration-tests.sh

mobile-test:
	@echo "Running mobile compatibility tests..."
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash tests/mobile-compat-tests.sh

health:
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash scripts/health-check.sh

benchmark:
	@AIOS_HOME="$(AIOS_ROOT)" OS_ROOT="$(OS_ROOT)" bash scripts/benchmark.sh

# ── Maintenance ───────────────────────────────────────────────────────────────

clean:
	@echo "Cleaning build artifacts..."
	@rm -f build/aios-rootfs.squashfs aios-s21fe.img
	@rm -f ai/llama-integration/bin/llama-cli ai/llama-integration/bin/llama-server
	@rm -rf ai/llama-integration/llama.cpp/build
	@echo "Clean complete."
