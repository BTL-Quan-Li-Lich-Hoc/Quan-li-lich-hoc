# Tiên Môn Premium assets

Do not substitute files in this directory with legacy Tiên Môn assets.

Canonical layout after running `tools/tien_mon_premium/import_assets.py`:

```text
assets/tien_mon_premium/
├── app_backgrounds/
│   ├── tienmon_1_1440x2560.png
│   ├── ...
│   └── tienmon_8_1440x2560.png
├── widget_overview/
│   ├── wid_sang.png
│   ├── wid_chieu.png
│   └── w_toi.png
├── fonts/
│   └── FzCoTrang.ttf
└── scene_manifest.json
```

The manifest records the exact SHA-256 values of every supplied scene plus the time mapping.

Important: `wid_sang.png` is supplied at 2020x779 while the afternoon/night sources are 1774x887. Do not distort it to force a common ratio. The Premium widget renderer must preserve source geometry and use a safe composition/fill strategy rather than stretch/squash.
