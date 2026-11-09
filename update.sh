#!/usr/bin/env bash
# Pull the latest version of this repo and reinstall the plugin if anything changed.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [ ! -d .git ]; then
  echo "This folder isn't a git clone, so it can't self-update." >&2
  echo "Clone it with: git clone https://github.com/midsummerred32/plasma-immich-wallpaper.git" >&2
  exit 1
fi

before=$(git rev-parse HEAD)
git pull --ff-only --quiet
after=$(git rev-parse HEAD)

if [ "$before" != "$after" ]; then
  ./install.sh > /dev/null
  echo "Updated ${before:0:7} -> ${after:0:7}"
  if command -v notify-send > /dev/null; then
    notify-send -i preferences-desktop-wallpaper "Immich Album Slideshow updated" \
      "Restart Plasma to apply it: kquitapp6 plasmashell && kstart plasmashell (or log out and back in)."
  fi
else
  echo "Already up to date (${after:0:7})"
fi
