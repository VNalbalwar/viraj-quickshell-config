#!/bin/bash
# Registers the native helper with Google Chrome (user level - no sudo, nothing outside your home).
# The only manual step left is loading the extension once; the script prints how.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
ID="$(cat "$D/EXTENSION_ID")"
HOST_NAME="com.viraj.qs_tabs"

chmod +x "$D/qs-chrome-host" "$D/qs-chrome-ctl"

for dir in "$HOME/.config/google-chrome"; do
    mkdir -p "$dir/NativeMessagingHosts"
    cat > "$dir/NativeMessagingHosts/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "Quickshell notch tab bridge",
  "path": "$D/qs-chrome-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$ID/"]
}
EOF
    echo "registered native helper: $dir/NativeMessagingHosts/$HOST_NAME.json"
done

cat <<EOF

Now load the extension ONCE in Chrome:
  1. open  chrome://extensions
  2. turn on  Developer mode  (top right)
  3. click  Load unpacked  and pick:  $D/extension
  4. it should show "Notch tab bridge" with ID $ID

After that, every tab that makes sound gets its own row (with its own mute and pause) in the notch's
Now-playing list. Uninstall: remove the extension in Chrome and delete
  ~/.config/google-chrome/NativeMessagingHosts/$HOST_NAME.json
EOF
