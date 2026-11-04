#!/bin/bash
# Installs the predator-profile helper + its polkit rule (needs sudo, run it yourself).
# Lets the notch control center's Power tile cycle the same four platform_profile
# modes as the Predator mode key (quiet, balanced, balanced-performance, performance).
#   - the helper only writes values the kernel lists in platform_profile_choices
#   - the polkit rule allows ONLY that program, ONLY for user viraj's active local session
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"

sudo install -m 755 -o root -g root "$D/predator-profile" /usr/local/bin/predator-profile
sudo install -m 644 -o root -g root "$D/50-predator-profile.rules" /etc/polkit-1/rules.d/50-predator-profile.rules
echo "installed:"
ls -l /usr/local/bin/predator-profile
sudo ls -l /etc/polkit-1/rules.d/50-predator-profile.rules

echo
echo "test (no password should be asked):"
pkexec /usr/local/bin/predator-profile quiet && echo "set quiet -> $(cat /sys/firmware/acpi/platform_profile)"
pkexec /usr/local/bin/predator-profile balanced && echo "set balanced -> $(cat /sys/firmware/acpi/platform_profile)"
pkexec /usr/local/bin/predator-profile bogus || echo "bogus rejected (expected)"
