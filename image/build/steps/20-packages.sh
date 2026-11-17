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
