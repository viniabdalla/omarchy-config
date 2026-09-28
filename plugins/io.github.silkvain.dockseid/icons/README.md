# Bundled icon library

Vector (SVG) icons that Dockseid uses **before** the system icon theme. If an
app isn't listed here, the dock falls back to the system icon.

`index.json` maps an app key to a file in this folder (or, for pure black/white
artwork, to a pair of files: dark art for light themes, light art for dark themes):

```json
{ "version": 1, "icons": {
  "obsidian": "obsidian.svg",
  "X": { "onLight": "x-black.svg", "onDark": "x-white.svg" }
} }
```

- A key is the app's desktop entry id (e.g. `code`, `org.kde.krita`) or its
  `Icon=` name (e.g. `vscode`). The desktop entry id is tried first.
- Values must be plain `name.svg` file names in this folder (no paths).
- Icons are drawn at the exact pixel size shown, so SVGs stay sharp.

Only add icons you are allowed to redistribute, and note their license/source
below.

## Sources and licenses

Fetched once (not at runtime) and checked for scripts, event handlers, external
references and embedded images before being added. Logos remain the property of
their owners; most of these are trademarks. "unknown" means the license could not
be verified — remove those files (and their index entries) if you redistribute
the plugin.

| App | File(s) | Source | License | Note |
|---|---|---|---|---|
| Brave Origin (standard Brave lion) | brave-origin.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/brave.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Brave Origin (standard Brave lion) logo is a trademark of its owner. |
| Chromium | chromium.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/chromium.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Chromium logo is a trademark of its owner. |
| CMake | cmake-gui.svg | https://commons.wikimedia.org/wiki/Special:FilePath/Cmake.svg | unknown (Commons file page license not checked) | CMake logo belongs to Kitware. |
| DaVinci Resolve | davinciresolve.svg | https://commons.wikimedia.org/wiki/Special:FilePath/DaVinci_Resolve_17_logo.svg | unknown (Commons file page license not checked) | DaVinci Resolve is a trademark of Blackmagic Design. |
| Discord | discord.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/discord.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Discord logo is a trademark of its owner. |
| Docker | docker.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/docker.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Docker logo is a trademark of its owner. |
| Google Contacts | google-contacts.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/google-contacts.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Google Contacts logo is a trademark of its owner. |
| Google Maps | google-maps.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/google-maps.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Google Maps logo is a trademark of its owner. |
| Google Messages | google-messages.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/google-messages.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Google Messages logo is a trademark of its owner. |
| Google Photos | google-photos.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/google-photos.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Google Photos logo is a trademark of its owner. |
| Krita | org.kde.krita.svg | https://raw.githubusercontent.com/KDE/krita/master/krita/pics/branding/default/sc-apps-krita.svgz | GPL-3.0 (repo license; branding artwork terms not separately verified) | Krita name/logo belong to the Krita Foundation. |
| Neovim | nvim.svg | https://raw.githubusercontent.com/neovim/neovim.github.io/master/static/logos/neovim-mark-flat.svg | MIT (repo license; logo terms not separately verified) | Neovim logo by Jason Long; check project logo terms. |
| Netflix | netflix.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/netflix.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Netflix logo is a trademark of its owner. |
| Obsidian | obsidian.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/obsidian.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Obsidian logo is a trademark of its owner. |
| Proton Mail | mail.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proton-mail.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Proton Mail logo is a trademark of its owner. |
| Spotify | spotify.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/spotify.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Spotify logo is a trademark of its owner. |
| Steam | steam.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/steam.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Steam logo is a trademark of its owner. |
| Visual Studio Code | code.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/visual-studio-code.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | Visual Studio Code logo is a trademark of its owner. |
| WhatsApp | whatsapp.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/whatsapp.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | WhatsApp logo is a trademark of its owner. |
| X (formerly Twitter) | x-black.svg + x-white.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/x.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | X (formerly Twitter) logo is a trademark of its owner. |
| YouTube | youtube.svg | https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/youtube.svg | Apache-2.0 (repo license; individual logos remain property of their owners) | YouTube logo is a trademark of its owner. |
| Zed | zed-black.svg + zed-white.svg | https://raw.githubusercontent.com/zed-industries/zed/main/assets/images/zed_logo.svg | unknown (GitHub reports NOASSERTION for repo; not verified for this asset) | Zed logo is a trademark of Zed Industries. |

X and Zed are pure black artwork, so each ships as `*-black.svg` (used on light
themes) and `*-white.svg` (used on dark themes), made by changing only the fill.
Krita's upstream file was gzip-compressed (`.svgz`) and was decompressed to plain
SVG.

`davinciresolve.svg` is modified from the source: its 360 tiny ring slices were
replaced by 180 clean wedges (same colours, same centre and outer radius) and
the ring was made about 2.8 units thick instead of about 1.0, because the
original ring is under one pixel wide at dock size and breaks up. This also
cut the file from 148 KB to 31 KB.
