# SURAKSHAPATH: GEOSPATIAL DATA PROVENANCE & ROAD AUDIT
**Authentic OpenStreetMap Road Network Verification for Andhra Pradesh**

**Report Generated:** 2026-11-24 05:25:16Z  
**Pipeline Source:** `backend/geo_pipeline/`  
**Dataset Source:** OpenStreetMap (OSM) Contributors under ODbL 1.0  
**Extraction File:** `backend/geo_pipeline/output/ap_extracted_highways.json`  
**Spatial Representation:** WGS-84 (EPSG:4326)  

---

## 1. SUMMARY AUDIT METRICS

| Metric | Measured Value | Verification Status |
|---|---|:---:|
| **Total Road Segments Extracted** | **196,266 ways** | VERIFIED GENUINE OSM |
| **Total Navigable Network Length** | **18,983.46 km** | MEASURED HAVERSINE |
| **Highways with Official Reference (NH/SH)** | **16,550 segments** | VERIFIED REFS |
| **Ways with Named Toponyms** | **22,192 segments** | LOCALLY TAGGED |
| **Bridges & Overpasses Identified** | **2,457 segments** | TAGGED `bridge=yes` |
| **Fords & Vulnerable Causeways** | **46 segments** | TAGGED `ford=yes` |
| **One-Way Directed Segments** | **7,499 segments** | TOPOLOGICALLY RESTRICTED |

---

## 2. HIGHWAY CLASSIFICATION BREAKDOWN

| Highway Class | Segment Count | Cumulative Length (km) | Emergency Transit Suitability |
|---|---:|---:|---|
| `residential` | 151,371 | 10,863.08 km | Local access only |
| `tertiary` | 14,578 | 2,035.38 km | Secondary evacuation bypass |
| `unclassified` | 11,788 | 3,092.66 km | Local access only |
| `secondary` | 9,817 | 1,414.31 km | Secondary evacuation bypass |
| `primary` | 6,075 | 974.69 km | Primary evacuation corridor |
| `trunk` | 2,637 | 603.34 km | Primary evacuation corridor |

---

## 3. PAVEMENT SURFACE ATTRIBUTION HONESTY

| Recorded Surface | Segment Count | Classification Honesty Rule |
|---|---:|---|
| `unspecified` | 185,687 | Unverified Default Surface |
| `asphalt` | 4,867 | Verified Paved (All-Weather) |
| `unpaved` | 3,819 | Verified Unpaved (Fair-Weather) |
| `dirt` | 878 | Verified Unpaved (Fair-Weather) |
| `concrete` | 488 | Verified Paved (All-Weather) |
| `paved` | 220 | Verified Paved (All-Weather) |
| `ground` | 214 | Verified Unpaved (Fair-Weather) |
| `compacted` | 49 | Unverified Default Surface |
| `concrete:lanes` | 14 | Unverified Default Surface |
| `cement` | 9 | Unverified Default Surface |
| `concrete:plates` | 8 | Unverified Default Surface |
| `cobblestone` | 3 | Unverified Default Surface |
| `gravel` | 3 | Verified Unpaved (Fair-Weather) |
| `fine_gravel` | 3 | Unverified Default Surface |
| `upaved` | 2 | Unverified Default Surface |
| `wood` | 1 | Unverified Default Surface |
| `sand` | 1 | Unverified Default Surface |

---

## 4. LEGAL & ATTRIBUTION COMPLIANCE (ODbL 1.0)

1. **Required Attribution:**
   `Map data © OpenStreetMap contributors under ODbL 1.0`
   The attribution string must appear on the frontend map display and API responses.
2. **Data Transformation Integrity:**
   No fake or synthetic road edges were generated. All nodes and way IDs are direct OpenStreetMap identifiers.
3. **Pavement Integrity Standard:**
   Roads with `surface=unspecified` are strictly labeled as unverified in routing outputs and are not falsely promoted to all-weather status.
