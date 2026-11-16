#!/usr/bin/env bash
# Runs inside the image build: executes every step in steps/ in order.
set -euo pipefail

for step in /tmp/build/steps/*.sh; do
    echo "::: ${step##*/}"
    bash -euo pipefail "$step"
done
