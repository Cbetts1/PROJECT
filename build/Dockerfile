# Dockerfile — AIOS hosted container image
# Builds a minimal aarch64 Linux environment that runs on Termux/proot

FROM ubuntu:22.04 AS base

ARG TARGETARCH=arm64
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash busybox-static curl wget git \
    build-essential cmake make pkg-config \
    python3 python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── llama.cpp build stage ─────────────────────────────────────────────────────
FROM base AS llama-builder

WORKDIR /build
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git
WORKDIR /build/llama.cpp
RUN cmake -B build \
      -DLLAMA_NATIVE=OFF \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=ON \
      -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j$(nproc) --target llama-cli llama-server

# ── AIOS root filesystem stage ────────────────────────────────────────────────
FROM base AS aios

ENV OS_ROOT=/aios/OS
WORKDIR /aios

# Copy repository contents
COPY . /aios/

# Install llama-cli binary
COPY --from=llama-builder /build/llama.cpp/build/bin/llama-cli /aios/ai/llama-integration/bin/llama-cli
COPY --from=llama-builder /build/llama.cpp/build/bin/llama-server /aios/ai/llama-integration/bin/llama-server

# Make all scripts executable
RUN find /aios -name '*.sh' -exec chmod +x {} \; \
    && chmod +x /aios/OS/bin/* /aios/OS/sbin/* 2>/dev/null || true

# Create required runtime directories
RUN mkdir -p \
    /aios/OS/proc/aura/context \
    /aios/OS/proc/aura/memory \
    /aios/OS/var/log \
    /aios/OS/var/run \
    /aios/OS/var/service \
    /aios/llama_model \
    /aios/OS/overlay/upper \
    /aios/OS/overlay/work \
    /aios/OS/overlay/merged

# Default environment
ENV OS_ROOT=/aios/OS \
    AIOS_HOME=/aios \
    PATH="/aios/OS/bin:/aios/OS/sbin:/aios/ai/llama-integration/bin:${PATH}"

ENTRYPOINT ["bash", "/aios/OS/sbin/init"]
