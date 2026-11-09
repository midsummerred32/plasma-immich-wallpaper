#!/usr/bin/env bash
set -e
kpackagetool6 -t Plasma/Wallpaper -r org.local.immichwallpaper
echo "Removed. Restart the shell:  kquitapp6 plasmashell && kstart plasmashell"
