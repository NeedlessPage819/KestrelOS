# Install every package list in packages/ (one package per line).
source /tmp/build/lib.sh

for list in /tmp/build/packages/*.list; do
    echo "--- ${list##*/}"
    mapfile -t pkgs < <(read_list "$list")
    if (( ${#pkgs[@]} )); then
        dnf_install "${pkgs[@]}"
        # dnf may satisfy "foo" with foo.i686 when both arches are listed; catch that here.
        rpm -q "${pkgs[@]}" >/dev/null || die "packages from ${list##*/} missing after install"
    fi
done

# A package may pull in a newer libzstd than the base image has, while the zstd program stays
# old; zstd then refuses to run ("incorrect library version") and the initramfs can't be built
# (seen 2026-11-27: libzstd 1.6.0, zstd 1.5.7). Keep the program at the library's version.
if [[ $(rpm -q --qf '%{VERSION}' libzstd.x86_64) != "$(rpm -q --qf '%{VERSION}' zstd.x86_64)" ]]; then
    dnf5 -y upgrade zstd
fi
[[ $(rpm -q --qf '%{VERSION}' libzstd.x86_64) == "$(rpm -q --qf '%{VERSION}' zstd.x86_64)" ]] || die "zstd and libzstd versions differ"
zstd --version >/dev/null || die "zstd does not run"
