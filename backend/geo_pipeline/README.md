# SurakshaPath Geospatial Data Pipeline (`backend/geo_pipeline/`)

## 1. Overview
This pipeline establishes a reproducible, automated geospatial workflow for acquiring, validating, and extracting OpenStreetMap transport data for the 26 districts of Andhra Pradesh, India ($162,970\text{ km}^2$).

It replaces manual, handcrafted test fixtures with authentic OpenStreetMap geometries, preserving road classifications, bridges, tidal causeways, one-way restrictions, and surface tags.

---

## 2. Directory Structure

```
backend/geo_pipeline/
├── boundaries/
│   ├── andhra_pradesh_boundary.geojson  # High-precision state boundary polygon (WGS84)
│   └── districts_26_metadata.json       # Master metadata for all 26 post-2022 districts
├── config/
│   └── extraction_config.yaml          # Extraction parameters, buffer distances & tag rules
├── scripts/
│   ├── 01_fetch_osm.py                 # Acquires genuine OSM data (pilot Overpass & statewide PBF)
│   ├── 02_validate_boundaries.py       # Validates state geometry and 26-district metadata
│   ├── 03_extract_highways.py          # Extracts highways, buffers boundaries, separates footpaths
│   └── 04_generate_provenance_report.py# Generates verified data provenance report
├── output/                             # Target directory for extracted PBFs and GeoJSONs
└── logs/                               # Execution logs and checksum validation records
```

---

## 3. Operational Execution

### Step 1: Validate Boundaries
```bash
python backend/geo_pipeline/scripts/02_validate_boundaries.py
```
Validates the state polygon geometry and 26-district metadata against Survey of India standards.

### Step 2: Acquire OSM Transport Data
```bash
python backend/geo_pipeline/scripts/01_fetch_osm.py
```
Retrieves genuine OpenStreetMap highway elements. In Phase 1A, it captures the real Coastal Disaster Corridor pilot sector.

### Step 3: Extract and Filter Highways
```bash
python backend/geo_pipeline/scripts/03_extract_highways.py
```
Applies the 15 km geographic boundary buffer, extracts vehicle-routable ways, computes exact Haversine lengths, and generates `output/ap_extracted_highways.json` and `output/ap_extracted_highways.geojson`.

### Step 4: Generate Provenance Report
```bash
python backend/geo_pipeline/scripts/04_generate_provenance_report.py
```
Compiles a quantitative audit report documenting cumulative kilometers, highway classifications, and bridge/causeway counts.

---

## 4. Legal Compliance & Attribution
Data sourced from OpenStreetMap contributors under the Open Data Commons Open Database License (ODbL) 1.0.  
All client applications and routing responses must display:  
`Map data © OpenStreetMap contributors under ODbL 1.0`
