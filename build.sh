#!/usr/bin/env bash
# Kestrel OS build. Run inside the build sandbox (see README.md), never on a daily-use system.
#
#   sudo ./build.sh image      build the system container image
#   sudo ./build.sh iso        image + interactive installer ISO     -> out/kestrel-<ver>-<date>.iso
#   sudo ./build.sh test-iso   image + unattended test ISO (VM only) -> out/test/autoinstall.iso
#
# All inputs are pinned in config.env; resolved digests and the package list land in out/.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source config.env

readonly OUT=out
readonly TAG="localhost/${IMAGE_NAME}:${FEDORA_VERSION}"

die() { echo "ERROR: $*" >&2; exit 1; }

build_image() {
    podman build \
        --pull=newer \
        --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
        --build-arg BASE_IMAGE="$BASE_IMAGE" \
        --build-arg AKMODS_NVIDIA_IMAGE="$AKMODS_NVIDIA_IMAGE" \
        --build-arg OS_NAME="$OS_NAME" \
        --build-arg IMAGE_NAME="$IMAGE_NAME" \
        --tag "$TAG" \
        image/
    write_manifest
}

# Records exactly what went into this build, so it can be reproduced and compared.
write_manifest() {
    mkdir -p "$OUT"
    {
        echo "built:   $(date -u +%FT%TZ)"
        echo "git:     $(git rev-parse HEAD 2>/dev/null || echo unknown)$(git diff --quiet 2>/dev/null || echo ' (dirty)')"
        echo "image:   $TAG $(podman image inspect --format '{{.Digest}}' "$TAG")"
        local ref
        for ref in "$BASE_IMAGE:$FEDORA_VERSION" "$AKMODS_NVIDIA_IMAGE:main-$FEDORA_VERSION"; do
            echo "input:   $ref $(podman image inspect --format '{{.Digest}}' "$ref")"
        done
    } >"$OUT/manifest.txt"
    podman run --rm "$TAG" rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort >"$OUT/packages.txt"
}

# $1: bootc-image-builder config, $2: output directory, $3: ISO file name
build_iso() {
    local config=$1 dest=$2 name=$3
    mkdir -p "$dest"
    podman run --rm --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v "$PWD/$config:/config.toml:ro" \
        -v "$PWD/$dest:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "$BIB_IMAGE" \
        --type anaconda-iso \
        --rootfs btrfs \
        "$TAG"
    mv "$dest/bootiso/install.iso" "$dest/$name"
    rm -rf "$dest/bootiso"
}

[[ $EUID -eq 0 ]] || die "run as root: bootc-image-builder needs rootful podman"
# Hand build results back to the invoking user, so tests can run without root.
trap '[[ -n ${SUDO_UID:-} && -d $OUT ]] && chown -R "$SUDO_UID:$SUDO_GID" "$OUT"' EXIT

case "${1:-}" in
    image)
        build_image ;;
    iso)
        build_image
        build_iso iso/release.toml "$OUT" "${IMAGE_NAME}-${FEDORA_VERSION}-$(date +%Y%m%d).iso" ;;
    test-iso)
        build_image
        build_iso test/autoinstall.toml "$OUT/test" autoinstall.iso ;;
    *)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 2 ;;
esac
