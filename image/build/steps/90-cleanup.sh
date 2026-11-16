# Leave nothing from the build behind in the image. `bootc container lint` checks the rest.
dnf5 clean all
rm -rf /tmp/build /var/log/dnf5.log* /var/lib/dnf
