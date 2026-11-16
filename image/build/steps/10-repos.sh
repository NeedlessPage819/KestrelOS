# RPM Fusion, needed only for Steam. The base image takes its multimedia packages from negativo17,
# so RPM Fusion stays disabled and is only enabled for the Steam transaction (25-steam.sh).
source /tmp/build/lib.sh

fedora=$(rpm -E %fedora)

if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null; then
    dnf_install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora}.noarch.rpm"
fi

for repo in $(dnf5 repo list --all --json | grep -o '"id":"rpmfusion-[^"]*"' | cut -d'"' -f4); do
    dnf5 config-manager setopt "${repo}.enabled=0"
done
