#!/usr/bin/env bash
# Prepares the Fedora WSL2 build sandbox with everything build.sh and test/vm-test.sh need.
# Only run inside the sandbox (WSL Fedora), never on a daily-use system.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

dnf5 -y install \
    podman git \
    qemu-kvm qemu-img edk2-ovmf \
    mingw64-gcc \
    sshpass socat

# Let the default WSL user open /dev/kvm without sudo.
if [[ -n ${SUDO_USER:-} ]]; then
    usermod -aG kvm "$SUDO_USER"
fi
