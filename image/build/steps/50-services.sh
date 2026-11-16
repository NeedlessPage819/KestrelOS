# Enable system services shipped in system_files/ and by packages.
systemctl enable \
    kestrel-gpu-setup.service \
    kestrel-flatpak-setup.service \
    cups.socket
