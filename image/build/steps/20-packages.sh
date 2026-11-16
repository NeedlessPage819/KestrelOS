# Install every package list in packages/ (one package per line).
source /tmp/build/lib.sh

for list in /tmp/build/packages/*.list; do
    echo "--- ${list##*/}"
    mapfile -t pkgs < <(read_list "$list")
    if (( ${#pkgs[@]} )); then
        dnf_install "${pkgs[@]}"
    fi
done
