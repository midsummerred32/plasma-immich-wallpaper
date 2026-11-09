#!/usr/bin/env bash
set -euo pipefail
systemctl --user disable --now immich-wallpaper-update.timer || true
rm -f "$HOME/.config/systemd/user/immich-wallpaper-update.service" \
      "$HOME/.config/systemd/user/immich-wallpaper-update.timer"
systemctl --user daemon-reload
echo "Auto-update disabled."
