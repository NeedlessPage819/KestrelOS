#!/usr/bin/env bash
# Runs inside the image build: executes every step of one phase in order, then cleans up.
#   install    packages and drivers (slow, cached as long as package lists don't change)
#   configure  system configuration that depends on system_files/ (fast)
set -euo pipefail

phase=${1:?usage: build.sh install|configure}

for step in "/tmp/build/$phase"/*.sh; do
    echo "::: $phase/${step##*/}"
    bash -euo pipefail "$step"
done

bash -euo pipefail /tmp/build/cleanup.sh
