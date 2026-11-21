#!/usr/bin/bash
# Kestrel OS per-model driver settings (DECISIONS.md D31): see kestrel-quirks.sh.

check() { return 0; }
depends() { return 0; }
install() {
    inst_hook pre-udev 10 "$moddir/kestrel-quirks.sh"
}
