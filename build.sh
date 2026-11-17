#!/usr/bin/env bash
# Kestrel OS build. Run inside the build sandbox (see README.md), never on a daily-use system.
#
#   sudo ./build.sh image          build the system container image
#   sudo ./build.sh iso            image + live ISO (try, then install)  -> out/kestrel-<ver>-<date>.iso
#   sudo ./build.sh installer-iso  image + plain installer ISO (also BIOS) -> out/kestrel-<ver>-<date>-installer.iso
#   sudo ./build.sh test-iso       image + unattended test ISO (VM only) -> out/test/autoinstall.iso
#
# All inputs are pinned in config.env; resolved digests and the package list land in out/.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source config.env

readonly OUT=out
readonly TAG="localhost/${IMAGE_NAME}:${FEDORA_VERSION}"
readonly LIVE_TAG="localhost/${IMAGE_NAME}-live:${FEDORA_VERSION}"

die() { echo "ERROR: $*" >&2; exit 1; }

build_image() {
    podman build \
        --pull=newer \
        --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
        --build-arg BASE_IMAGE="$BASE_IMAGE" \
        --build-arg AKMODS_NVIDIA_IMAGE="$AKMODS_NVIDIA_IMAGE" \
        --build-arg OS_NAME="$OS_NAME" \
        --build-arg IMAGE_NAME="$IMAGE_NAME" \
        --build-arg WHITESUR_ICONS_REPO="$WHITESUR_ICONS_REPO" \
        --build-arg WHITESUR_ICONS_TAG="$WHITESUR_ICONS_TAG" \
        --build-arg WHITESUR_ICONS_COMMIT="$WHITESUR_ICONS_COMMIT" \
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
        echo "input:   $WHITESUR_ICONS_REPO $WHITESUR_ICONS_TAG $WHITESUR_ICONS_COMMIT"
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

# Live ISO (DECISIONS.md D22): a live image built on top of the Kestrel image, packed by
# iso/live/build-iso.sh together with the plain image as the installer's payload.
# $1: ISO file name
build_live_iso() {
    local name=$1 payload=$OUT/live/payload
    podman build         --build-arg BASE_IMAGE="$TAG"         --build-arg FEDORA_VERSION="$FEDORA_VERSION"         --tag "$LIVE_TAG"         image/live/
    rm -rf "$payload" && mkdir -p "$OUT/live"
    # Compressed layers keep the ISO small; gzip is what the installer reads for sure.
    podman push --compression-format gzip --force-compression "$TAG" "oci:$payload"
    podman run --rm         --cap-add sys_admin --security-opt label=disable         --mount type=image,source="$LIVE_TAG",dst=/rootfs         -v "$PWD/$payload:/oci:ro"         -v "$PWD/iso/live:/src:ro"         -v "$PWD/$OUT:/output"         -e ISO_LABEL="Kestrel-${FEDORA_VERSION}" -e ISO_NAME="$name" -e OS_NAME="$OS_NAME"         "registry.fedoraproject.org/fedora:${FEDORA_VERSION}"         bash /src/build-iso.sh
    rm -rf "$payload"
}

[[ $EUID -eq 0 ]] || die "run as root: bootc-image-builder needs rootful podman"
# Hand build results back to the invoking user, so tests can run without root.
trap '[[ -n ${SUDO_UID:-} && -d $OUT ]] && chown -R "$SUDO_UID:$SUDO_GID" "$OUT"' EXIT

case "${1:-}" in
    image)
        build_image ;;
    iso)
        build_image
        build_live_iso "${IMAGE_NAME}-${FEDORA_VERSION}-$(date +%Y%m%d).iso" ;;
    installer-iso)
        build_image
        build_iso iso/release.toml "$OUT" "${IMAGE_NAME}-${FEDORA_VERSION}-$(date +%Y%m%d)-installer.iso" ;;
    test-iso)
        build_image
        build_iso test/autoinstall.toml "$OUT/test" autoinstall.iso ;;
    *)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        exit 2 ;;
esac
