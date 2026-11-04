#!/bin/bash
# Installs the Predator helpers + polkit rule and patches the driver (needs sudo,
# run it yourself). Powers the notch control center's Power, Fan and Keyboard RGB.
#   - helpers only write values they validate (see predator-profile / predator-sense)
#   - the polkit rule allows ONLY those two programs, ONLY user viraj, ONLY an
#     active local session
# Re-runnable. Pass --no-driver to skip the DKMS patch/rebuild/reload.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"

sudo install -m 755 -o root -g root "$D/predator-profile" /usr/local/bin/predator-profile
sudo install -m 755 -o root -g root "$D/predator-sense" /usr/local/bin/predator-sense
sudo install -m 644 -o root -g root "$D/50-predator.rules" /etc/polkit-1/rules.d/50-predator.rules
sudo rm -f /etc/polkit-1/rules.d/50-predator-profile.rules   # superseded by 50-predator.rules
echo "installed:"
ls -l /usr/local/bin/predator-profile /usr/local/bin/predator-sense
sudo ls -l /etc/polkit-1/rules.d/50-predator.rules

if [ "${1:-}" != "--no-driver" ]; then
    echo
    bash "$D/patch-linuwu.sh"
fi

echo
echo "self-test (no password should be asked):"
pkexec /usr/local/bin/predator-profile balanced && echo "profile ok -> $(cat /sys/firmware/acpi/platform_profile)"
pkexec /usr/local/bin/predator-sense fan 0,0 && echo "fan ok (auto)"
pkexec /usr/local/bin/predator-sense fan 999,0 2>/dev/null || echo "invalid fan value rejected (expected)"
