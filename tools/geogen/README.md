# geogen (OpenRA real-world map generator)

Phase 1 scaffolding for generating RA `.oramap` maps from real-world data.

## Features (Phase 1 through M4)
- RA TEMPERATE tileset targeting.
- AOI from MGRS with default map size 2048×2048 at 4 m/cell.
- OSM overlay: roads (width-aware), water (areas + waterways), vegetation (tree actors), buildings (civilian actors).
- Optional datasets: ESA WorldCover (built-up/forest masks), JRC GSW (water augmentation).
- map.yaml embeds GeoTransform (UTM, meters_per_cell, rotation) and Attributions (dataset versions).
- Packages `.oramap` and can auto-install into OpenRA maps directory.
- Validation flags to check GeoTransform and coordinate round-trips.

## Environment
Use the conda environment `openra` (Python 3.10):

```bash
# Core deps
conda run -n openra pip install -r tools/geogen/requirements.txt

# Optional (required for WorldCover/GSW ingestion)
conda install -n openra -c conda-forge rasterio
```

## Usage
```bash
conda run -n openra python -m tools.geogen.cli \
  --mgrs "33TWN1234567890" \
  --cells 2048 \
  --meters-per-cell 4 \
  --pretty
```

### Common recipes

1) Generate and install a full overlay `.oramap` (roads, water, vegetation, buildings):

Recommendation

If your near-term focus is TAK visualization and road network accuracy at town/city scale, switch to 3 m/cell. It cleanly resolves residential streets and gives vehicles about a cell wide—enough to feel “real” for placement and LOS without over-shrinking the AOI.

Use 2 m/cell for tight urban scenarios where alleys, parking lots, or formation spacing matters.

Stay at 4 m/cell when you need large AOIs (> ~6–8 km on a side) and roads/river geometry is more important than vehicle-scale detail.

```bash
conda run -n openra python -m tools.geogen.cli \
  --mgrs "18STD5154840177" \
  --overlay-osm --overlay-osm-buildings \
  --write-oramap output/18STD5154840177_realworld.oramap \
  --players 8 --place-spawns \
  --install-openra --install-release 20250330 \
  --road-width-m 8 --waterway-width-m 6 \
  --veg-density 0.15 --max-veg-actors 4000 \
  --veg-min-spacing 2 --veg-patch-size 32 --veg-patch-boost 1.5 \
  --suppress-veg-near-roads 1 --suppress-veg-near-buildings 1 \
  --building-placement-mode aggressive --building-search-radius 3 \
  --pretty
```

2) Use optional datasets (requires rasterio):

```bash
conda run -n openra python -m tools.geogen.cli \
  --mgrs "18STD5154840177" \
  --overlay-osm --overlay-osm-buildings \
  --use-worldcover --worldcover-path tools/data/worldcover/ESA_WorldCover_10m_2021.tif \
  --augment-water-gsw --gsw-path tools/data/gsw/occurrence_80W_40Nv1_4_2021.tif \
  --gsw-min-occurrence 75 \
  --write-oramap output/18STD5154840177_worldcover_gsw.oramap \
  --install-openra --install-release 20250330 \
  --pretty
```

3) OSM summary only (no `.oramap`):

```bash
conda run -n openra python -m tools.geogen.cli \
  --mgrs "33TWN1234567890" \
  --cells 2048 \
  --meters-per-cell 4 \
  --osm-summary \
  --pretty
```

Output includes AOI center, UTM zone, bbox, and overlay stats. `.oramap` packages map.yaml + map.bin and can be copied to OpenRA automatically.

## Packaging & Docs (M5)
- Auto-install target (macOS): `~/Library/Application Support/OpenRA/maps/ra/release-<tag>` when `--install-openra --install-release <tag>` are used.
- New vegetation tuning flags:
  - `--veg-min-spacing`, `--veg-patch-size`, `--veg-patch-boost`
  - `--suppress-veg-near-roads`, `--suppress-veg-near-buildings`
- Buildings:
  - `--overlay-osm-buildings`, `--building-placement-mode`, `--building-search-radius`, `--debug-building-audit`
- Data sources & licenses (cite in map.yaml Attributions):
  - OSM (ODbL 1.0)
  - ESA WorldCover 10 m (CC BY 4.0)
  - JRC Global Surface Water (CC BY 4.0)

## Caching & reproducibility
- __OSM Overpass cache__: `--osm-cache-dir .cache/osm` (default). Disable with `--no-osm-cache`.
- __Dataset metadata__: include dataset versioning in map.yaml Attributions using:
  - `--worldcover-year <YYYY>` (e.g., 2021)
  - `--gsw-version <YYYY>` (e.g., 2023)
- __Example__:
```bash
conda run -n openra python -m tools.geogen.cli \
  --mgrs "18STD5154840177" \
  --overlay-osm --overlay-osm-buildings \
  --use-worldcover --worldcover-path tools/data/worldcover/ESA_WorldCover_10m_2021.tif \
  --augment-water-gsw --gsw-path tools/data/gsw/occurrence_80W_40Nv1_4_2021.tif \
  --worldcover-year 2021 --gsw-version 2021 \
  --write-oramap output/18STD5154840177_repro.oramap --install-openra --install-release 20250330
```

4 m/cell → 2.05 km × 2.05 km

3 m/cell → 1.54 km × 1.54 km

2 m/cell → 1.02 km × 1.02 km

1 m/cell → 0.51 km × 0.51 km

Example Script for Geo Maps
Make sure you run the command from the OpenRA_WoW directory

Set-Location g:\WindSurf\OpenRA_WoW\OpenRA_WoW

conda run -n openra python -m tools.geogen.cli `
  --mgrs 17SPA7768033011 `
  --cells 512 `
  --meters-per-cell 4 `
  --no-osm-cache `
  --overlay-osm `
  --overlay-osm-buildings `
  --players 4 `
  --place-spawns `
  --write-oramap "output\17SPA_Seperation_realworld.oramap" `
  --install-openra `
  --install-path "$env:APPDATA\OpenRA\maps\ra\{DEV_VERSION}" `
  --road-width-m 8 `
  --waterway-width-m 40 `
  --veg-density 0.15 `
  --max-veg-actors 8000 `
  --veg-min-spacing 2 `
  --veg-patch-size 32 `
  --veg-patch-boost 1.5 `
  --suppress-veg-near-roads 1 `
  --suppress-veg-near-buildings 1 `
  --building-placement-mode aggressive `
  --building-search-radius 3 `
  --pretty