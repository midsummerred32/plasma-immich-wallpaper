#!/usr/bin/env bash
# Install a systemd *user* timer that runs update.sh once a day.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

cat > "$UNIT_DIR/immich-wallpaper-update.service" << EOF
[Unit]
Description=Update the Immich Album Slideshow wallpaper plugin

[Service]
Type=oneshot
ExecStart=$DIR/update.sh
EOF

cat > "$UNIT_DIR/immich-wallpaper-update.timer" << EOF
[Unit]
Description=Daily check for Immich Album Slideshow updates

[Timer]
OnStartupSec=5min
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now immich-wallpaper-update.timer
echo "Auto-update enabled (daily). Check it with: systemctl --user list-timers | grep immich"
echo "Run an update right now with: $DIR/update.sh"
