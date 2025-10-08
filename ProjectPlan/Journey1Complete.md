# OpenRA Real‑World Map Automation — Journey

## Decisions
- Conda environment: always use `openra` for this project
- Mod target: Command & Conquer: Red Alert (RA)
- Default map: 2048×2048 cells at 4 m/cell (adjustable via CLI; was 512)
- Focus now: automated RA map generation from real geodata; TAK/CoT integration later
- Note: RA uses a rectangular grid without terrain height; elevation/ramps are out of scope for RA and can be revisited if we later support TS
- Tileset: TEMPERATE (confirmed)
 - Building placement (M4): OSM building multipolygons supported; placement options:
   - `--building-placement-mode {accurate,fallback,aggressive}`
   - `--building-search-radius <tiles>` (default 2; doubled in aggressive mode)
   - Optional audit: `--debug-building-audit <csv>`

## Scope (Phase 1)
- Input: MGRS center + extent (km or cells)
- Output: `.oramap` (packed) compatible with RA
- Data: OSM (roads/water), global landcover (vegetation/urban), optional DEM (for hydrology shaping only)
- Tileset mapping: real features → RA tiles (TEMPERATE, confirmed)
- Adjustability: CLI flags for cells-per-side and meters-per-cell

## Milestones
[x] M0: Design & scaffolding (1–2 days)
  - Tileset: TEMPERATE (confirmed)
  - Define `GeoTransform` metadata schema stored in `map.yaml` (for later CoT)
  - Scaffold Python CLI `tools/geogen/` with config (mod, tileset, size, meters-per-cell)

### M0 — Geospatial Data Sources (Investigation)

- __OpenStreetMap (OSM)__
  - Coverage: global; features: `highway`, `waterway`, `natural=water`, `landuse=forest/wood`.
  - Access: Overpass API (e.g., https://overpass-api.de/api/interpreter). Add caching to avoid rate limits.
  - License: ODbL 1.0 (attribution required; share‑alike for derived databases).

- __Land Cover (vegetation/urban)__
  - ESA WorldCover 10 m (2021/2023), CC BY 4.0. Good global 10 m classes (tree/shrub/grass/cropland/built‑up/water).
  - Copernicus CGLS‑LC100 100 m. Coarser fallback if 10 m not needed/available.
  - Use: derive vegetation mask and suppress trees in built‑up.

- __Surface Water (augment OSM)__
  - JRC Global Surface Water (30 m), CC BY 4.0. Use permanent water mask to fill gaps where OSM is sparse.
  - Optional: HydroRIVERS/HydroLAKES (verify terms; cite appropriately) for large‑scale rivers/lakes.

- __Elevation (optional)__
  - Copernicus DEM GLO‑30 (30 m). Only for future hydrology shaping/shorelines; not required for RA tiles.

- __Satellite Imagery (optional QA)__
  - Sentinel‑2 L2A (10 m) / Landsat 8/9 (30 m) for visual validation; not ingested in MVP.

- __Recommended MVP Baseline__
  - OSM: roads + water polygons/major waterways.
  - ESA WorldCover 10 m: vegetation/built‑up mask.
  - JRC GSW permanent water: fallback/augmentation for lakes/rivers.
  - No DEM in M1; revisit in M2 for shoreline/river shaping.

- __Implementation Notes__
  - Reproject everything to AOI UTM; align to `meters_per_cell` grid.
  - Conflict resolution: roads > water > vegetation; built‑up suppresses tree actors.
  - Record dataset names + version/year + license in `map.yaml` metadata (Attributions) for reproducibility.

- [x] M1: MVP terrain + roads + water (3–5 days)
  - Ingest AOI from MGRS, fetch OSM roads/water, landcover
  - Rasterize to grid at 4 m/cell, map to RA tiles (grass/forest/water/road classes)
  - Build `map.yaml` + `map.bin`; pack `.oramap` via OpenRA Utility
  - Visual QA in RA editor/game
 
 - [x] M2: Shorelines, rivers, and tile smoothing (3–4 days) — completed 2025-08-13
    - Improve coast/river edges using RA shoreline/river tiles and transitions
    - Handle road widths/classes and intersections using appropriate road templates
    - Add simple settlement/urban patches from landcover

- [x] M3: Georectification metadata + validation (2–3 days) — completed 2025-08-13
  - Embed `GeoTransform` (UTM zone, origin, meters-per-cell, rotation) in `map.yaml`
  - Provide a small validation tool (offline) to convert sample cells ↔ lat/lon to verify alignment
  - Added CLI flags: `--validate-geotransform`, `--validate-cell`, `--validate-latlon`
  - Validation (AOI `18STD8232530244`, 512×512 @ 4 m/cell):
    - cell→lat/lon→cell round-trip error ≈ 6.6e-05 m (near zero)
    - lat/lon corners→cell→lat/lon round-trip error ≈ 2.828 m (expected half-cell snap at 4 m/cell)
    - center→cell→lat/lon round-trip error ≈ 2.828 m (expected)
  - Example:
    - `conda run -n openra python tools/geogen/cli.py --mgrs "18STD8232530244" --cells 512 --meters-per-cell 4.0 --rotation-deg 0 --validate-geotransform --validate-cell 10,10 --validate-latlon 34.59095969035479,-77.37344138155518 --pretty`

- [x] M4: Building and Vegetation/detail pass (3–5 days) — completed 2025-08-13
  - Forest density patches; optional tree actor sprinkling (performance-aware)
  - building actors must be accurate as much as possible based on OSM data (performance-aware)
  - Tune tile/actor ratios for fidelity vs performance

- [x] M5: Packaging & docs (1–2 days) — completed 2025-08-13
  - Updated `tools/geogen/README.md` (conda `openra`, default 2048 cells, common recipes, auto-install docs)
  - Added "Caching & reproducibility" section (`--osm-cache-dir`, `--worldcover-year`, `--gsw-version`)
  - Added `tools/geogen/DATA_SOURCES.md` (OSM/WorldCover/GSW licensing + attribution examples)
  - Verified CLI flags via `--help`; documented vegetation/building tuning options
  - Prepared example commands for AOI `18STD5154840177` (screenshots optional)


- [x] M6: TAK/CoT integration — MCV CoT-on-Spawn
  - Plan (active — 2025-08-15):
    - [ ]Fix YAML crash in `mods/ra/rules/vehicles.yaml` by dedenting `JEEP:` to top level and removing a duplicated stray `JEEP` trait block. Verify `MCV:` remains top-level and includes `CoTOnSpawnBroadcaster` with `Callsign: MCV`. [Completed 2025-08-15]
    - [ ]Rebuild solution and relaunch RA via `launch-game.cmd Game.Mod=ra`. [In progress]
    - [ ]Start Skirmish on georectified map `RealWorld 18STE8317202799` (auto-installed into `%APPDATA%/OpenRA/maps/ra/{DEV_VERSION}`).
    - [ ]On match start, confirm MCV spawns and the trait emits a CoT UDP packet to `127.0.0.1:4242`.
      - Check `%APPDATA%/OpenRA/Logs/cot.log` for lines:
        - `spawn init endpoint=127.0.0.1:4242 callsign=MCV type=...`
        - `send spawn actor=MCV lat=... lon=... target=127.0.0.1:4242 bytes=...`
        - `payload <event ...>` (full CoT XML)
    - [ ]Verify TAKX receives the contact over UDP 4242 (localhost).
    - Scope note: Only the starting Construction Vehicle (MCV) spawn broadcast is required now; other assets will be added later.
    - Fallback behavior: If the map lacks georeference, the trait logs `skip spawn no lat/lon` and sends nothing.
  - Acceptance (M6):
    - RA launches without YamlException.
    - Skirmish loads the georectified map and spawns an MCV for the player.
    - A CoT UDP packet is emitted on spawn with lat/lon matching the map location (within a few meters expected at 4 m/cell).
    - TAKX displays the contact with callsign `MCV`.

  - Add OpenRA trait(s) for `WPos → Lat/Lon` and CoT UDP/TCP sender
  - In‑game debug overlay for cursor Lat/Lon (optional)
  - Cursor on target xml example that be recievd in TAKX

  - Example Infantry fully capable
<?xml version="1.0" encoding="UTF-8"?><event access="Undefined" how="m-g-g" stale="2026-08-14T13:21:13.625Z" start="2025-08-14T13:21:13.625Z" time="2025-08-14T13:21:13.625Z" type="a-f-G-U-C-I" uid="337bd33a-17b8-4831-9fbe-38117e0a97d9" version="2.0">
    <point ce="9999999.0" hae="919.3767468565838" lat="34.41668411733689" le="9999999.0" lon="-116.27391807952694"/>
    <detail>
        <link parent_callsign="OpenRA" production_time="2025-08-14T13:07:25.765Z" relation="p-p" type="a-f-G-U-C" uid="b1591796-3011-5083-94fd-20ab8331af9b"/>
        <color argb="-1" value="-1"/>
        <archive/>
        <__milsym id="SFGCUCI---*****"/>
        <contact callsign="F.14.090725"/>
    </detail>
</event>

  - Example Infantry Damaged
<?xml version="1.0" encoding="UTF-8"?><event access="Undefined" how="m-g-g" stale="2026-08-14T15:00:43.143Z" start="2025-08-14T15:00:43.143Z" time="2025-08-14T15:00:43.143Z" type="a-f-G-U-C-I" uid="0045b05a-f554-4079-b5e9-4eb80cf68bb9" version="2.0">
    <point ce="9999999.0" hae="908.9888723073076" lat="34.41679757647907" le="9999999.0" lon="-116.27175298065038"/>
    <detail>
        <link parent_callsign="MARTA_BK" production_time="2025-08-14T13:07:40.179Z" relation="p-p" type="a-f-G-U-C" uid="b1591796-3011-5083-94fd-20ab8331af9b"/>
        <archive/>
        <color argb="-1" value="-1"/>
        <contact callsign="F.14.090740"/>
        <__milsym id="SFGDUCI---*****"/>
    </detail>
</event>

  - Example Infantry detroyed
<?xml version="1.0" encoding="UTF-8"?><event access="Undefined" how="m-g-g" stale="2026-08-14T15:01:06.596Z" start="2025-08-14T15:01:06.596Z" time="2025-08-14T15:01:06.596Z" type="a-f-G-U-C-I" uid="908c128d-e3b1-41e6-94a9-8846063c3e8a" version="2.0">
    <point ce="9999999.0" hae="866.5017562246052" lat="34.41671008037398" le="9999999.0" lon="-116.26935872995574"/>
    <detail>
        <link parent_callsign="MARTA_BK" production_time="2025-08-14T13:07:49.023Z" relation="p-p" type="a-f-G-U-C" uid="b1591796-3011-5083-94fd-20ab8331af9b"/>
        <archive/>
        <color argb="-1" value="-1"/>
        <contact callsign="F.14.090749"/>
        <__milsym id="SFGXUCI---*****"/>
    </detail>
</event>

  - Work with QA to identify Mil2525C events that are needed tanks, builfing types, airborne assets, etc


## Acceptance Criteria (Phase 1)
- Given an MGRS center and size, the CLI generates a RA `.oramap` that:
  - Loads in RA, shows roads/water/landcover plausibly placed
  - Includes `GeoTransform` metadata for future CoT work
  - Can be regenerated with different cells-per-side and meters-per-cell without code changes


## Progress Update — 2025-08-09
- Completed:
  - Implemented OSM overlay rasterization (roads, waterways, forest polygons → RA tiles/actors).
  - Fixed Overpass query to include node coordinates via recursion; overlay now draws roads/water.
  - Added Overpass caching and CLI flags: `--osm-cache-dir`, `--no-osm-cache`, `--overlay-osm`, width/vegetation controls.
  - Added map.yaml Metadata block (GeoTransform, Attributions) and .oramap packaging (map.yaml + map.bin).
  - Generated sample `.oramap`: `output/11SNS0938625517_roads.oramap` with overlay stats.
  - Implemented per-highway and per-waterway width mapping with support for explicit `width=*` tag overrides.
  - Suppressed vegetation (tree actors) inside OSM built-up landuse (`residential/industrial/commercial`).
  - Added extra debug counters in overlay stats: `forest_cells`, `builtup_cells`.
  - Implemented optional ESA WorldCover (built-up + forest preference) and JRC GSW (water augmentation) ingestion via `--worldcover-path` / `--gsw-path`; gracefully skipped if paths are not provided or `rasterio` is unavailable.

- Partially complete:
  - WorldCover/GSW ingestion implemented behind optional file paths; needs validation with sample rasters and metadata version/year wiring.
  - Road width per type implemented; road template mapping and intersections/smoothing pending.
  - Vegetation actors placed in OSM forests; built-up suppression active (OSM landuse + optional WorldCover built-up).
  - GeoTransform validation tool pending.

- Artifacts:
  - `output/11SNS0938625517_roads.oramap`
  - overlay_stats (AOI 11SNS0938625517): water_cells=189, road_cells=15643, veg_actors=169
  - `output/11SNS0938625517_widths.oramap`
  - overlay_stats (width-mapped AOI): water_cells=410, road_cells=15885, veg_actors=164, forest_cells=1069, builtup_cells=0

## Progress Update — 2025-08-10
- Completed:
  - Versioned Overpass cache key (includes full query) to avoid stale cached JSON without nodes.
  - Auto-default WorldCover `DatasetYear` and GSW `DatasetVersion` to current year when flags omitted; metadata writer now serializes these keys.
  - Generated playtest `.oramap` with spawns for AOI `11SNT7843695894`: `output/11SNT7843695894_playtest.oramap`.
- Visual QA: RA editor/game load ok; roads visible; georectification confirmed.
- Artifacts:
  - overlay_stats (AOI 11SNT7843695894): water_cells=0, road_cells=9330, veg_actors=0, road_ways=32, road_segments=992

## Next Actions (Updated — 2025-08-10)
- Implement rotation-aware overlay (apply `rotation_deg` in `lat/lon → cell` transform; handle bounds/clipping).
- Validate ESA WorldCover 10 m / JRC GSW ingestion with sample rasters; tune thresholds. (Metadata year/version now wired.)
- Road details: map highway classes to RA road templates where available; add simple intersection widening/smoothing.
- Optional: `--debug-overlay` flag to print extended stats and optionally write debug PNGs of layers for QA.
 - Visual QA in RA editor/game on the generated AOIs (e.g., `11SNT7843695894_playtest.oramap`).

## Progress Update — 2025-08-13 (PM)
- Completed:
  - Default map size set to 2048×2048 @ 4 m/cell for improved road/water fidelity.
  - Overpass query updated to include `relation['building']` and deeper recursion to fetch member ways and nodes.
  - Building placement improvements: centroid anchoring + configurable search radius; fallback sizes (`2x2 → 2x1/1x2 → 1x1`); optional placement audit CSV; new flags documented above.
- Notes:
  - Larger default extent increases OSM coverage and produces more faithful hydrology/road networks.
  - Caching remains enabled by default (`.cache/osm`).

