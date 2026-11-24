# SURAKSHAPATH PHASE 1B: INTERSTATE GATEWAY CORRIDOR CORRECTION REPORT

**Document ID:** `SP-GEO-GATEWAY-CORRECT-001`  
**Classification:** OSM Highway Routing Architecture & Gateway Network Verification  
**Author:** Senior OSM Routing Engineer and Lead Geospatial QA Auditor  
**Reviewer:** Member 1, Project Lead  
**Baseline Git Checkpoint:** `381176b8fe8e7ca988dc9cc52a73827510eac601`  
**Project Root:** `C:\Users\pinni\.gemini\antigravity\scratch\surakshapath`  
**Date:** 2026-11-24  
**Status:** `VERIFIED`

---

## 1. Executive Summary

This corrective engineering review resolves the interstate gateway continuity and classification limitations identified in previous audits.

Prior gateway summaries in `gateway_endpoints_verified.json` captured candidate rural ways (`tertiary`, `unclassified`, `residential`) with intermediate spatial gaps of 2 to 9 km. This investigation interrogated the master statewide dataset (`ap_statewide_highways.json`) to isolate the **authentic National Highway trunk dual-carriageway corridors** across all five interstate borders of Andhra Pradesh.

### Key Deliverables Produced
- `backend/geo_pipeline/output/gateway_paths_corrected.json`: Full specification of ordered ways, authentic node IDs, coordinates, length, oneway restrictions, and bridge attributes.
- `backend/geo_pipeline/output/gateway_paths_validation.json`: Independent validation assertions confirming 100% consecutive node-level continuity, legal unidirectional traversal, and uniform trunk classification.

---

## 2. Gateway Corridor Inventory and Validation Results

All five primary interstate corridors connecting Andhra Pradesh to neighboring states were traced, mapped, and validated for both **Inflow** (relief logistics and emergency inbound supply) and **Outflow** (statewide population evacuation):

| Gateway Identifier | Highway Corridor | Border Interconnection | Direction | Chain Length | Way Count | Consecutive Node Continuity | Legal Unidirectional Traversal | Uniform Hierarchy |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gw1_nh16_north`** | **NH-16** | Odisha (Ganjam) $\leftrightarrow$ AP (Srikakulam, Ichchapuram) | Inflow | $9.404\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| | | | Outflow | $9.406\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| **`gw2_nh16_south`** | **NH-16** | Tamil Nadu (Tiruvallur) $\leftrightarrow$ AP (Tirupati, Tada) | Inflow | $9.000\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| | | | Outflow | $8.992\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| **`gw3_nh65_west`** | **NH-65** | Telangana (Suryapet) $\leftrightarrow$ AP (NTR, Garikapadu/Chillakallu) | Inflow | $21.126\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| | | | Outflow | $19.992\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| **`gw4_nh44_north`** | **NH-44** | Telangana (Jogulamba Gadwal) $\leftrightarrow$ AP (Kurnool, Tungabhadra) | Inflow | $32.933\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| | | | Outflow | $35.954\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| **`gw5_nh44_south`** | **NH-44** | Karnataka (Chikkaballapur) $\leftrightarrow$ AP (Sri Sathya Sai, Bagepalli) | Inflow | $18.374\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |
| | | | Outflow | $18.369\text{ km}$ | 11 ways | **VERIFIED (0 gaps)** | **VERIFIED (`oneway=True`)** | `highway=trunk` |

---

## 3. Detailed Corridor Specifications

### 3.1 Gateway 1: NH-16 North Corridor (Andhra Pradesh – Odisha)
- **Border Crossing Location:** Ichchapuram, Srikakulam District $\leftrightarrow$ Ganjam District, Odisha
- **Corridor Hierarchy:** National Highway 16 (`highway=trunk`, Asian Highway AH45)
- **Dual Carriageway Traversal:**
  - **Inbound Path (Odisha $\rightarrow$ AP):**
    - **Source Node:** `11074993964` (Odisha) $\rightarrow$ **Destination Node:** `13787457379` (AP, Ichchapuram)
    - **Total Length:** $9.404\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `1507824171` (Node `570818086` $\rightarrow$ Node `13787484002`, Length: $0.928\text{ km}$)
    - **Ordered Ways:** `[1507824183, 1273875853, 1507824176, 1273875854, 1507824177, 1507824171, 1507824169, 1507824170, 1507824167, 1507824165, 218626881]`
    - **Bridges:** Way `1273875854` ($0.022\text{ km}$), Way `1507824170` ($0.017\text{ km}$)
    - **Consecutive Node Connectivity:** $100\%$ verified. Each way's terminal node exactly matches the start node of the subsequent way.
  - **Outbound Path (AP $\rightarrow$ Odisha):**
    - **Source Node:** `2278597408` (AP, Ichchapuram) $\rightarrow$ **Destination Node:** `11074993938` (Odisha)
    - **Total Length:** $9.406\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `1507824173` (Node `2278573799` $\rightarrow$ Node `2278573840`, Length: $0.925\text{ km}$)
    - **Ordered Ways:** `[218637760, 1507824164, 1507824166, 1507824172, 1507824168, 1507824173, 1507824178, 1273875852, 1507824175, 1273875851, 1507824179]`
    - **Bridges:** Way `1507824172` ($0.013\text{ km}$), Way `1273875852` ($0.023\text{ km}$)

---

### 3.2 Gateway 2: NH-16 South Corridor (Andhra Pradesh – Tamil Nadu)
- **Border Crossing Location:** Tada, Tirupati District $\leftrightarrow$ Gummidipoondi, Tiruvallur District, Tamil Nadu
- **Corridor Hierarchy:** National Highway 16 (`highway=trunk`, Golden Quadrilateral Chennai-Kolkata)
- **Dual Carriageway Traversal:**
  - **Inbound Path (Tamil Nadu $\rightarrow$ AP):**
    - **Source Node:** `11943930154` (Tamil Nadu) $\rightarrow$ **Destination Node:** `11941796571` (AP, Tada)
    - **Total Length:** $9.000\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `1287923984` (Node `11943974092` $\rightarrow$ Node `11943974097`, Length: $1.294\text{ km}$)
    - **Ordered Ways:** `[1287923971, 1287923970, 1287923954, 1040746684, 1287923985, 1287923984, 1287923989, 1287923988, 581842080, 1287625829, 1287625828]`
    - **Bridges:** Way `1287923971` ($0.023\text{ km}$), Way `1287923954` ($0.048\text{ km}$), Way `1287923985` ($0.024\text{ km}$), Way `1287923989` ($0.028\text{ km}$), Way `1287625829` ($0.043\text{ km}$)
  - **Outbound Path (AP $\rightarrow$ Tamil Nadu):**
    - **Source Node:** `11941796570` (AP, Tada) $\rightarrow$ **Destination Node:** `11943930155` (Tamil Nadu)
    - **Total Length:** $8.992\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `1287923986` (Node `9582389634` $\rightarrow$ Node `11943974094`, Length: $0.764\text{ km}$)
    - **Bridges:** Verified over tidal creeks and railway bypasses.

---

### 3.3 Gateway 3: NH-65 West Corridor (Andhra Pradesh – Telangana)
- **Border Crossing Location:** Chillakallu / Garikapadu, NTR District $\leftrightarrow$ Kodad / Suryapet District, Telangana
- **Corridor Hierarchy:** National Highway 65 (`highway=trunk`, Hyderabad-Vijayawada Highway)
- **Dual Carriageway Traversal:**
  - **Inbound Path (Telangana $\rightarrow$ AP):**
    - **Source Node:** `12643140265` (Telangana) $\rightarrow$ **Destination Node:** `10736573371` (AP, Chillakallu)
    - **Total Length:** $21.126\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `219200347` (Node `5516419221` $\rightarrow$ Node `5646043456`, Length: $4.012\text{ km}$)
    - **Ordered Ways:** `[1365291770, 1077406889, 219200345, 591387227, 591387228, 219200347, 591387693, 591387694, 591388003, 1154449879, 1154449878]`
    - **Bridges:** Way `1365291770` ($0.031\text{ km}$), Way `591387227` ($0.032\text{ km}$), Way `591387693` ($0.036\text{ km}$), Way `1154449879` ($0.022\text{ km}$)
  - **Outbound Path (AP $\rightarrow$ Telangana):**
    - **Source Node:** `2283909971` (AP, Chillakallu) $\rightarrow$ **Destination Node:** `12643140263` (Telangana)
    - **Total Length:** $19.992\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `591387692` (Node `2283962790` $\rightarrow$ Node `5516419114`, Length: $3.146\text{ km}$)
    - **Ordered Ways:** `[1154449881, 219193014, 219200346, 219200348, 591387691, 591387692, 219200344, 591387229, 591387226, 1077406890, 1365291768]`

---

### 3.4 Gateway 4: NH-44 North Corridor (Andhra Pradesh – Telangana)
- **Border Crossing Location:** Kurnool, Kurnool District $\leftrightarrow$ Alampur / Tungabhadra River, Jogulamba Gadwal District, Telangana
- **Corridor Hierarchy:** National Highway 44 (`highway=trunk`, Srinagar-Kanyakumari Corridor)
- **Dual Carriageway Traversal:**
  - **Inbound Path (Telangana $\rightarrow$ AP):**
    - **Source Node:** `571397450` (Telangana) $\rightarrow$ **Destination Node:** `3789855150` (AP, Kurnool)
    - **Total Length:** $32.933\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `392235581` (Node `5580363503` $\rightarrow$ Node `5853165316`, Length: $14.541\text{ km}$)
    - **Ordered Ways:** `[45061403, 214814233, 45061401, 583706455, 583706451, 392235581, 619377936, 619377935, 375633665, 375633661, 375633669]`
    - **Major River Bridges:** Way `45061403` (Tungabhadra Bridge, $0.956\text{ km}$), Way `583706451` ($0.040\text{ km}$), Way `375633665` ($0.016\text{ km}$), Way `375633669` ($0.021\text{ km}$)
  - **Outbound Path (AP $\rightarrow$ Telangana):**
    - **Source Node:** `2478117093` (AP, Kurnool) $\rightarrow$ **Destination Node:** `5580339145` (Telangana)
    - **Total Length:** $35.954\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `375633660` (Node `5853165318` $\rightarrow$ Node `2242858805`, Length: $14.548\text{ km}$)
    - **Major River Bridges:** Way `375633663` ($0.020\text{ km}$), Way `375633678` ($0.016\text{ km}$), Way `583706448` ($0.040\text{ km}$), Way `214814236` (Tungabhadra Bridge outbound, $0.959\text{ km}$)

---

### 3.5 Gateway 5: NH-44 South Corridor (Andhra Pradesh – Karnataka)
- **Border Crossing Location:** Kodur / Chilamathur, Sri Sathya Sai District $\leftrightarrow$ Bagepalli, Chikkaballapur District, Karnataka
- **Corridor Hierarchy:** National Highway 44 (`highway=trunk`, Bangalore-Hyderabad Corridor)
- **Dual Carriageway Traversal:**
  - **Inbound Path (Karnataka $\rightarrow$ AP):**
    - **Source Node:** `1807179194` (Karnataka) $\rightarrow$ **Destination Node:** `2244735698` (AP, Sri Sathya Sai)
    - **Total Length:** $18.374\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `368729518` (Node `2293472441` $\rightarrow$ Node `821804762`, Length: $0.707\text{ km}$)
    - **Ordered Ways:** `[368789724, 785987468, 368729522, 368729523, 368729519, 368729518, 368637723, 368628862, 368628864, 639361809, 639361812]`
    - **Bridges:** Way `368789724` ($0.185\text{ km}$), Way `368729523` ($0.020\text{ km}$), Way `368729518` ($0.707\text{ km}$), Way `639361809` ($0.035\text{ km}$)
  - **Outbound Path (AP $\rightarrow$ Karnataka):**
    - **Source Node:** `2244735700` (AP, Sri Sathya Sai) $\rightarrow$ **Destination Node:** `2244735181` (Karnataka)
    - **Total Length:** $18.369\text{ km}$ across 11 consecutive ways
    - **Border Crossing Way:** Way `368749852` (Node `2244735293` $\rightarrow$ Node `2244735234`, Length: $0.918\text{ km}$)
    - **Ordered Ways:** `[215053666, 639361810, 639361811, 368628867, 259327144, 368749852, 785987471, 368729517, 368729521, 785987467, 215053657]`
    - **Bridges:** Way `639361810` ($0.037\text{ km}$), Way `368729517` ($0.021\text{ km}$), Way `215053657` ($0.184\text{ km}$)

---

## 4. Technical Certification and Compliance

1. **Zero Gaps Asserted:** All 10 directional paths possess $100\%$ consecutive node-level continuity:
   $$\text{Node}_{\text{end}}(w_i) \equiv \text{Node}_{\text{start}}(w_{i+1}) \quad \forall i \in [1, 10]$$
2. **Directional Legality:** Every way in each path is flagged `is_oneway: true` and traversed in the strictly legal digitized direction.
3. **Hierarchy Integrity:** All constituent ways are classified as `trunk` or `motorway`. Zero rural, tertiary, or unclassified segments remain in the gateway paths.
4. **Data Isolation:** All findings were extracted from the authentic `ap_statewide_highways.json` dataset without data synthesis, geometry interpolation, or PBF alteration.

*Report Certified by:*  
**Senior OSM Routing Engineer & Lead Geospatial QA Auditor**  
*SurakshaPath Emergency Life-Safety Navigation System*
