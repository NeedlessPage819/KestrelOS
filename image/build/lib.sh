# Shared helpers for build steps. Source it; do not execute.

# Print the entries of a package list file, without comments and blank lines.
read_list() {
    grep -Ev '^[[:space:]]*(#|$)' "$1" | sed 's/[[:space:]]*#.*//'
}

dnf_install() {
    dnf5 -y install "$@"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}
