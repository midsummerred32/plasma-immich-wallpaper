#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
ID=org.local.immichwallpaper
if kpackagetool6 -t Plasma/Wallpaper -l 2>/dev/null | grep -q "$ID"; then
  kpackagetool6 -t Plasma/Wallpaper -u "$ID"
else
  kpackagetool6 -t Plasma/Wallpaper -i "$ID"
fi
echo
echo "Installed. Restart the shell to load it:  kquitapp6 plasmashell && kstart plasmashell"
echo "Then: right-click desktop -> Configure Desktop and Wallpaper -> Wallpaper type: Immich Album Slideshow"
