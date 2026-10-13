# Source card collection, version 0.8

The collection imports every distinct referenced card face in the user's new
[Bakugan Anime Style Format workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3412700725).
The save contains 2,398 card references, which resolve to 636 distinct face
cells: 197 gate cards, 392 ability cards, 46 other illustrations and one special
token. Duplicate references are merged by face URL, grid and cell, retaining
all source names, aliases, categories and paths in the manifest.

These images are available in the collection. Their printed effects have not
been verified or added to the playable rule catalogs. The existing console
card art and rules remain in their separate `cards.json` catalog.

## Extraction and provenance

`assets/imported/source_cards.json` records all 636 faces and the common back.
It includes source URLs and source file SHA-256, shipped PNG SHA-256, decoded
RGBA pixel SHA-256, atlas dimensions, grid, card cell, exact extraction rectangle,
raw caption and source description. All 636 entries have local images.

There are 139 distinct face source files. Of the 636 face cells, 523 come from
26 atlases with a 10 × 7 grid; the other 113 use a single-face 1 × 1 grid.
The downloaded atlases have widths of 4,096 pixels and heights of 3,882, 3,892 or
3,894 pixels, so their normalized cell boundaries do not all land on integral
pixels. Each boundary is independently rounded from its normalized position.
This avoids cumulative drift along a row. The resulting rectangles are copied
at native resolution without repainting, color changes or resampling.

Standalone PNG faces and the PNG back are copied byte for byte. Each other
image is saved as an exact pixel crop. The staging tool verifies every output
against the corresponding source crop before writing the manifest.

Seven animated source uploads are MP4 files. They use their first decoded,
nonblank native frame in the collection, with `source_animated: true`,
`animation_playback: false` and `transformation: first_video_frame_to_png`.
Their original source URL and MP4 byte hash are retained; the collection does
not play the source animation. The seven source captions are:

- AAAAAAAAA (Cut In Saber/Tigrerra/Haos)
- Magma Prominence (Gorem/Subterra)
- Blue Stealth (Preyas/Aquos/Subterra/Darkus)
- Boosted Dragon (Dragonoid/Pyrus)
- Gravity Chamber (Hydranoid/Darkus)
- Winds of Fury (Skyress/Ventus)
- Crystal Fang (Tigrerra/Haos)

The 637 PNGs (636 faces and one back) total 574,520,624 bytes. The manifest
retains the workshop identity and each card's collaborator caption; printed
art belongs to the original artists and the workshop contributors.

## Browser and memory

`SourceCardBrowser` provides filters, name/category search, twelve cards per
page and a full-face view with enlargement and scrolling. The browser uses
small runtime display previews, bounded to 224 × 300 pixels, for its grid.
These previews do not replace or alter the native source PNGs. Opening a card
loads its full native face. The library keeps at most twenty cached textures,
and closing the browser releases its texture references.

The parent game opens the overlay with `show_browser(kind)` and resumes after
the `closed` signal. It must suspend gameplay input while the overlay is visible.

## Reproduction and verification

Supply the audited `all-source-cards.json`, `download-jobs.json` and the public
source downloads in the research cache, then run the offline extraction:

```sh
python3 tools/stage_card_library08.py --cache /tmp/bakugan08-research
```

After the Godot editor imports the new assets, run:

```sh
godot --headless --path . --script tests/test_source_card_library.gd
```

The runtime checks cover packaged resource availability, source provenance,
native zoom dimensions, bounded display previews, cache eviction, filtering,
paging, readable full-face selection and releasing the overlay on close.

The imported 0.8 resources passed 3,893 runtime checks. An independent rational
arithmetic audit also verified the grid rectangle and native dimensions of all
636 faces. Three actual GL Compatibility views (OpenGL 4.5 llvmpipe) were rendered
and inspected: gate page 1, gate page 2 and a full native card. The views show
intact card frames, readable navigation and readable full-face text. Captures
and their validation report are in `builds/visual0.8/card-browser-*`.
