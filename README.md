# Immich Album Slideshow for KDE Plasma 6

A KDE Plasma 6 wallpaper plugin that turns selected [Immich](https://immich.app) albums into a desktop slideshow.

## Features

- Pick any of your Immich albums (including albums shared with you) from the wallpaper settings
- Crossfading slideshow with a configurable interval, optional shuffle
- Crop-to-fill, fit, or stretch positioning
- Preview or full-size image quality
- **Previous Photo** / **Next Photo** items in the desktop right-click menu
- Re-reads your albums every 6 hours, so new photos show up on their own
- Photos only (videos are skipped)

## Requirements

- KDE Plasma 6
- An Immich server reachable from your desktop
- An Immich API key with permission to read albums and assets

## Install

```sh
git clone https://github.com/midsummerred32/plasma-immich-wallpaper.git
cd plasma-immich-wallpaper
./install.sh
kquitapp6 plasmashell && kstart plasmashell
```

Then right-click the desktop → **Configure Desktop and Wallpaper** → set **Wallpaper type** to **Immich Album Slideshow**.

To remove it: `./uninstall.sh`.

## Updating

If you installed from a `git clone`, update with:

```sh
./update.sh
kquitapp6 plasmashell && kstart plasmashell
```

To check for updates automatically every day (systemd user timer):

```sh
./enable-autoupdate.sh      # turn on
./disable-autoupdate.sh     # turn off
```

When a new version is installed you get a desktop notification. The new code only takes effect after Plasma restarts
(`kquitapp6 plasmashell && kstart plasmashell`, or log out and back in); the plugin never restarts your desktop on its own.

Auto-update installs whatever is on the `main` branch of your clone's remote, so only use it with a repository you trust.

## Setup

1. Enter your Immich server URL (for example `http://192.168.1.10:2283`) and your API key
   (Immich → Account Settings → API Keys).
2. Click **Load albums** and tick the albums you want.
3. Choose the interval, shuffle, positioning and quality, then apply.

## Notes and limitations

- **API key storage:** the key is saved in plain text in Plasma's config
  (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`). Use a read-only key.
- **API key in image URLs:** images are loaded with the key as an `apiKey` query parameter,
  so it can appear in server access logs. This is fine on a trusted LAN; avoid using it over the open internet.
- **HTTPS:** self-signed certificates are not supported. Use plain HTTP on your LAN or a properly signed certificate.
- **Archived photos** are not shown (Immich's search skips them by default).
- **Image quality:** "Preview" uses the preview size configured in Immich (1440px by default). "Full size" needs a recent Immich server and falls back to preview if the server rejects it.
- The album's photos are listed through Immich's `POST /api/search/metadata`, because newer Immich versions no longer return assets from `GET /api/albums/{id}`.

## Troubleshooting

- Plasma keeps running old code until the shell restarts: `kquitapp6 plasmashell && kstart plasmashell`.
- If the wallpaper shows a message, it says what Immich returned (for example `HTTP 403` means the key lacks permission).
- Plugin logs: `journalctl --user -b | grep -i immich | tail -n 30`

## License

MIT, see [LICENSE](LICENSE).
