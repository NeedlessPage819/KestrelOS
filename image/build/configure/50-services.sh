# Enable system services shipped in system_files/ and by packages.
systemctl enable \
    kestrel-gpu-setup.service \
    kestrel-flatpak-setup.service \
    cups.socket

# Flathub is the only app source (DECISIONS.md D8); Fedora's Flatpak remote would show duplicates.
systemctl disable flatpak-add-fedora-repos.service
