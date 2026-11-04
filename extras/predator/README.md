# predator

Root-side pieces for the notch control center on the Acer Predator PH16-71.

| file | purpose |
|---|---|
| `predator-profile` | writes `platform_profile` (Power tile: quiet / balanced / balanced-performance / performance) |
| `predator-sense` | writes fan speed and keyboard RGB sysfs knobs, strictly validated |
| `qs-hotspot` | runs a hotspot (virtual AP `qsap0` + hostapd + dnsmasq + NAT) next to your Wi-Fi on the same channel, so you stay connected |
| `50-predator.rules` | polkit rule: only those three programs, only user `viraj`, only an active local session |
| `patch-linuwu.sh` | idempotent DKMS fix for kernel 7.2 + adds the `PH16-71` quirk so the RGB sysfs group exists |
| `install.sh` | installs all of the above, then runs the patch and a self-test |

Install (asks for sudo): `bash ~/.config/quickshell/extras/predator/install.sh`
After a kernel / `linuwu-sense-dkms` update that breaks the module: `bash ~/.config/quickshell/extras/predator/patch-linuwu.sh`
Uninstall: `sudo rm /usr/local/bin/{predator-profile,predator-sense,qs-hotspot} /etc/polkit-1/rules.d/50-predator.rules`

Without the helpers the shell still works: the Power tile falls back to
power-profiles-daemon's three profiles and the Fan / RGB controls are read-only/hidden.
