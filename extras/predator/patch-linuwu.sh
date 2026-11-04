#!/bin/bash
# Idempotent patch + rebuild of the linuwu_sense DKMS driver for this laptop
# (Acer Predator PH16-71, kernel 7.2.x). Safe to re-run after a kernel or
# linuwu-sense-dkms package update overwrote the source. Needs sudo.
#
#  1. <linux/string.h> is no longer included implicitly      -> add the include
#  2. strncpy() was removed from the kernel                  -> memcpy() (all 3
#     call sites copy exactly `len` bytes and NUL-terminate themselves)
#  3. the PH16-71 quirk is the generic predator_v4 one (no four_zone_kb), so the
#     four_zoned_kb RGB sysfs group never appears
#     -> give PH16-71 its own quirk: predator_v4 (unchanged) + four_zone_kb
set -euo pipefail

SRC=/usr/src/linuwu-sense-1.0.0/src/linuwu_sense.c
KVER=$(uname -r)

[ -f "$SRC" ] || { echo "missing $SRC (is linuwu-sense-dkms installed?)"; exit 1; }

echo "[1/4] patching $SRC"
sudo python3 - "$SRC" <<'EOF'
import re, sys
p = sys.argv[1]
t = open(p).read()
orig = t

if "#include <linux/string.h>" not in t:
    t = t.replace("#include <linux/bitfield.h>", "#include <linux/string.h>\n#include <linux/bitfield.h>", 1)

t = re.sub(r"\bstrncpy\(", "memcpy(", t)

if "quirk_acer_predator_ph16_71" not in t:
    # PH16-71 already maps to the generic quirk_acer_predator_v4 (that is what
    # makes platform_profile/fan work). Give it its own quirk = predator_v4 PLUS
    # the four-zone keyboard flag, leaving everything else exactly as it was.
    quirk = """static struct quirk_entry quirk_acer_predator_ph16_71 = {
    .predator_v4 = 1,
    .four_zone_kb = 1,
};

"""
    anchor = "static struct quirk_entry quirk_acer_predator_phn16_72 = {"
    assert anchor in t, "quirk anchor not found"
    t = t.replace(anchor, quirk + anchor, 1)

    pat = re.compile(r'(DMI_MATCH\(DMI_PRODUCT_NAME, "Predator PH16-71"\),\s*\},\s*\.driver_data = &)quirk_acer_predator_v4(,)')
    t, n = pat.subn(r'\1quirk_acer_predator_ph16_71\2', t, count=1)
    assert n == 1, "PH16-71 dmi entry not found"

if t != orig:
    open(p, "w").write(t)
    print("patched")
else:
    print("already patched")
EOF
grep -nE 'linux/string.h|PH16-71|four_zone_kb = 1' "$SRC" | head

echo "[2/4] dkms install for $KVER"
# drop the cached build first, otherwise DKMS happily reinstalls the OLD binary
sudo dkms remove linuwu-sense/1.0.0 -k "$KVER" 2>/dev/null || true
sudo dkms install linuwu-sense/1.0.0 -k "$KVER"

echo "[3/4] reloading module"
sudo rmmod linuwu_sense 2>/dev/null || true
sudo modprobe linuwu_sense

echo "[4/4] result"
echo "platform_profile: $(cat /sys/firmware/acpi/platform_profile)"
ls /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/ | grep -E 'four_zoned_kb|predator_sense' || true
ls /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb 2>&1 || true
