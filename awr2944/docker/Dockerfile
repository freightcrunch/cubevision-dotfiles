# ============================================================================
# TI MMWAVE-MCUPLUS-SDK + ARM toolchain reproducible build environment.
#
# TI's SDK installer is x86_64-only, and the TI-CGT-ARMLLVM compiler is also
# x86_64-only. We therefore build this image as linux/amd64 and rely on
# docker buildx + qemu-user-static for arm64 Linux hosts. On macOS (Apple
# Silicon or Intel) Docker Desktop transparently handles the platform pinning.
#
# Build:
#   docker buildx build --platform linux/amd64 -t awr2944-sdk:latest .
#
# Or via docker compose (see docker-compose.yml).
# ============================================================================

# Pin to Ubuntu 22.04 — MMWAVE-MCUPLUS-SDK 4.6+ release notes list 18.04/22.04
# as the supported Linux hosts. 22.04 avoids EOL'd 18.04 while staying close
# enough to TI's validated configuration.
FROM --platform=linux/amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# ----- System dependencies --------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      git \
      libc6-dev-i386 \
      libncurses5 \
      libusb-1.0-0 \
      libxrender1 libxtst6 libxi6 libgtk-3-0 libnss3 libasound2 \
      make \
      mono-runtime \
      ninja-build \
      openjdk-17-jre-headless \
      pkg-config \
      python3 python3-pip python3-venv \
      sudo \
      unzip \
      wget \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ----- Non-root build user --------------------------------------------------
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
RUN groupadd --gid ${GID} ${USERNAME} \
 && useradd  --uid ${UID} --gid ${GID} -m -s /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}

# ----- TI tool versions (pin these explicitly for reproducibility) ----------
# Check https://www.ti.com/tool/MMWAVE-MCUPLUS-SDK for the current release.
# These defaults match the AWR2944-supporting 04.07.00.01 GA (update as needed).
ARG MMWAVE_SDK_VERSION=04_07_00_01
ARG SYSCONFIG_VERSION=1.21.0.3721
ARG TI_CGT_ARMLLVM_VERSION=3.2.2.LTS
ARG GCC_ARM_VERSION=13.2.rel1

# Installer URLs are documented in docs/02-toolchains.md. They are NOT embedded
# here because TI requires click-through acceptance; users must download the
# installers themselves and mount them at /installers, then re-run the install
# stage:
#   docker compose run --rm sdk /opt/scripts/install-ti-sdk.sh
#
# This keeps the image redistributable without violating TI's EULA.

# ----- GNU Arm Embedded (from Arm, not ubuntu apt) --------------------------
RUN curl -fsSL \
      "https://developer.arm.com/-/media/Files/downloads/gnu/${GCC_ARM_VERSION}/binrel/arm-gnu-toolchain-${GCC_ARM_VERSION}-x86_64-arm-none-eabi.tar.xz" \
      -o /tmp/arm-gnu.tar.xz \
 && mkdir -p /opt/arm-gnu-toolchain \
 && tar -xJf /tmp/arm-gnu.tar.xz -C /opt/arm-gnu-toolchain --strip-components=1 \
 && rm /tmp/arm-gnu.tar.xz
ENV PATH=/opt/arm-gnu-toolchain/bin:${PATH}

# ----- Rust (for cross-compiling R5F firmware from Rust) --------------------
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:${PATH}

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile minimal \
 && rustup target add armv7r-none-eabihf \
 && rustup component add rust-src rustfmt clippy llvm-tools-preview \
 && chmod -R a+rw /opt/cargo /opt/rustup

# ----- TI SDK install scaffolding ------------------------------------------
# The user-supplied installer is mounted at /installers at runtime, and
# install-ti-sdk.sh handles the silent-install incantation. /ti is the
# canonical install prefix used throughout TI's Makefiles.
RUN mkdir -p /ti /installers /workspace /opt/scripts \
 && chown -R ${USERNAME}:${USERNAME} /ti /workspace

COPY install-ti-sdk.sh /opt/scripts/install-ti-sdk.sh
COPY entrypoint.sh     /opt/scripts/entrypoint.sh
RUN chmod a+rx /opt/scripts/*.sh

ENV MMWAVE_SDK_INSTALL_PATH=/ti/mmwave_mcuplus_sdk_${MMWAVE_SDK_VERSION}
ENV TI_INSTALL_PATH=/ti
ENV GCC_ARM_PATH=/opt/arm-gnu-toolchain

USER ${USERNAME}
WORKDIR /workspace

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
CMD ["bash"]
