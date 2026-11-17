# Steam from RPM Fusion nonfree; the repo is enabled for this transaction only (see 10-repos.sh).
source /tmp/build/lib.sh

dnf_install \
    --enablerepo=rpmfusion-nonfree \
    --enablerepo=rpmfusion-nonfree-updates \
    steam
