# Nvidia driver (DECISIONS.md D5). Installed for all machines but disabled by
# /usr/lib/modprobe.d/kestrel-gpu.conf until kestrel-gpu-setup enables it.
source /tmp/build/lib.sh

akmods=/tmp/akmods-nvidia

kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel | head -n1)
kmod=$(find "$akmods/kmods" -name "kmod-nvidia-${kernel}-*.rpm" -print -quit)
[[ -n $kmod ]] || die "no Nvidia kmod for kernel ${kernel} in ${AKMODS_NVIDIA_IMAGE:-akmods image}; base and akmods images are out of sync"

# The addons package provides the Nvidia repo definition and the module signing key.
dnf_install "$akmods"/ublue-os/ublue-os-nvidia-addons-*.rpm
pkgs=(
    nvidia-driver.x86_64
    nvidia-driver-libs.x86_64
    nvidia-driver-libs.i686
    nvidia-driver-cuda.x86_64
    nvidia-settings.x86_64
    libva-nvidia-driver.x86_64
)
dnf_install "$kmod" "${pkgs[@]}"
rpm -q "${pkgs[@]}" >/dev/null || die "Nvidia packages missing after install"

# The driver packages blacklist nouveau/nova for every machine. Keep their power-management
# options but drop the blacklist, so non-Nvidia and pre-Turing machines are untouched;
# kestrel-gpu-setup adds the blacklist only where nvidia-open is used.
sed -i '/^blacklist /d' /usr/lib/modprobe.d/nvidia*.conf
rm -f /usr/lib/bootc/kargs.d/*nvidia*.toml
if grep -rqsE '^blacklist (nouveau|nova)' /usr/lib/modprobe.d /usr/lib/bootc/kargs.d; then
    die "a global nouveau/nova blacklist is still present"
fi
