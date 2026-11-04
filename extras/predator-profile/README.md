# predator-profile

Root helper + polkit rule so the control center's **Power** tile can cycle the
Predator's four platform profiles like the hardware mode key does.
Without it the tile falls back to power-profiles-daemon's three profiles.

Install (asks for sudo once): `bash ~/.config/quickshell/extras/predator-profile/install.sh`
Uninstall: `sudo rm /usr/local/bin/predator-profile /etc/polkit-1/rules.d/50-predator-profile.rules`
