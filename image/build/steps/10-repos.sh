# Third-party repositories: RPM Fusion (Steam lives in rpmfusion-nonfree-steam).
source /tmp/build/lib.sh

fedora=$(rpm -E %fedora)

if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null; then
    dnf_install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora}.noarch.rpm"
fi

dnf5 config-manager setopt rpmfusion-nonfree-steam.enabled=1
