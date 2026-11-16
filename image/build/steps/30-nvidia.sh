# Nvidia driver (DECISIONS.md D5). Installed for all machines but disabled by
# /usr/lib/modprobe.d/kestrel-gpu.conf until kestrel-gpu-setup enables it.
source /tmp/build/lib.sh

akmods=/tmp/akmods-nvidia

kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel | head -n1)
kmod=$(find "$akmods/kmods" -name "kmod-nvidia-${kernel}-*.rpm" -print -quit)
[[ -n $kmod ]] || die "no Nvidia kmod for kernel ${kernel} in ${AKMODS_NVIDIA_IMAGE:-akmods image}; base and akmods images are out of sync"

# The addons package provides the Nvidia repo definition and the module signing key.
dnf_install "$akmods"/ublue-os/ublue-os-nvidia-addons-*.rpm
dnf_install \
    "$kmod" \
    nvidia-driver \
    nvidia-driver-libs.i686 \
    nvidia-driver-cuda \
    nvidia-settings \
    libva-nvidia-driver

# Driver packages may ship their own nouveau blacklist and kernel arguments; drop them so
# that non-Nvidia and pre-Turing machines are untouched (kestrel-gpu-setup decides instead).
rm -f /usr/lib/modprobe.d/nvidia*blacklist*.conf /usr/lib/bootc/kargs.d/*nvidia*.toml
