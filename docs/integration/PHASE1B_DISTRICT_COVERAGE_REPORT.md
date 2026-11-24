# SURAKSHAPATH: PHASE 1B DISTRICT-BY-DISTRICT COVERAGE & TOPOLOGY REPORT
## Comprehensive Geospatial Analysis Across All 26 Districts of Andhra Pradesh

**Project:** SurakshaPath  
**Author:** Member 5 (Backend, Data & Alerts)  
**Reviewer:** Member 1 (Project Lead)  
**Date:** November 24, 2026  
**Scope:** 26 Administrative Districts of Andhra Pradesh, India ($162,970\text{ km}^2$, 679 Mandals)  
**Baseline Dataset:** OpenStreetMap Contributors under ODbL 1.0 / AP Gazette No. 497 (April 3, 2022)

---

## 1. Executive Summary

This report delivers the comprehensive **District-by-District Road Network and Graph Topology Audit** required under Phase 1B of the SurakshaPath Andhra Pradesh Statewide Expansion.

The audit evaluates road density, classification distributions, surface tagging completeness, structural water crossings (bridges, tunnels, causeways), and network graph connectivity across all **26 reorganized districts** of Andhra Pradesh, utilizing the verified OpenStreetMap India sub-region PBF extract (`india-latest.osm.pbf`, $1.60\text{ GB}$, MD5 `d6f78178723593eee9621515fee25946`).

### Key Statewide Findings:
1. **100% Administrative Coverage:** Verified authentic OpenStreetMap road networks across all 26 post-2022 administrative districts.
2. **Total Mapped Road Network:**
   - **Inside AP Administrative Districts:** **616,777 road segments** totaling **253,876.07 km** of authentic road infrastructure.
   - **Interstate Gateway Buffer Corridors (25–50 km):** **187,165 road segments** totaling **85,121.58 km**, ensuring seamless evacuation continuity into Odisha, Tamil Nadu, Telangana, and Karnataka.
   - **Total Extracted Statewide Dataset:** **803,942 road segments** totaling **338,997.65 km**.
3. **Emergency Structural Indexing:** Cataloged **26,214 bridges**, **1,143 tunnels**, and **152 flood-prone fords/causeways** statewide.
4. **Rural Surface Tagging Reality:** Across rural Andhra Pradesh, approximately $97.4\%$ of minor village roads in OpenStreetMap currently carry an `unspecified` surface tag. The SurakshaPath routing engine addresses this through a **1.5x flood safety penalty** on unclassified rural tracks, prioritizing certified all-weather paved state corridors during active flood warnings.

---

## 2. Statewide 26-District Coverage Master Matrix

| District Name | Administrative Zone | Headquarters | Mandals | Mapped Roads | Total Road Length (km) | Paved % | Bridges | Fords / Causeways |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Alluri Sitharama Raju** | North Coast (Ghat/Agency) | Paderu | 22 | 9,832 | 9,228.33 km | 5.8% | 776 | 18 |
| **Anakapalli** | North Coast | Anakapalli | 24 | 13,002 | 5,902.63 km | 2.2% | 500 | 9 |
| **Ananthapuramu** | Rayalaseema | Anantapur | 31 | 31,767 | 17,937.44 km | 1.9% | 1,326 | 4 |
| **Annamayya** | Rayalaseema | Rayachoti | 30 | 21,760 | 11,742.00 km | 2.6% | 631 | 2 |
| **Bapatla** | South Coast | Bapatla | 25 | 18,870 | 7,710.64 km | 1.9% | 915 | 0 |
| **Chittoor** | Rayalaseema (Southern) | Chittoor | 31 | 15,609 | 8,724.83 km | 5.6% | 463 | 1 |
| **Dr. B.R. Ambedkar Konaseema** | Godavari Delta (Riparian) | Amalapuram | 22 | 7,290 | 3,528.97 km | 3.1% | 428 | 2 |
| **East Godavari** | Godavari Delta | Rajamahendravaram | 19 | 24,516 | 7,005.24 km | 2.4% | 495 | 0 |
| **Eluru** | Godavari/Krishna Basin | Eluru | 28 | 42,551 | 12,718.42 km | 1.1% | 1,139 | 5 |
| **Guntur** | South Coast Plain | Guntur | 18 | 44,540 | 11,306.09 km | 1.7% | 1,401 | 4 |
| **Kakinada** | Godavari Delta | Kakinada | 21 | 25,565 | 7,021.23 km | 1.7% | 671 | 11 |
| **Krishna** | Krishna Delta | Machilipatnam | 25 | 44,020 | 12,205.12 km | 1.4% | 1,645 | 4 |
| **Kurnool** | Rayalaseema | Kurnool | 26 | 25,752 | 12,996.17 km | 2.4% | 952 | 0 |
| **NTR** | Krishna Basin | Vijayawada | 20 | 31,611 | 9,439.45 km | 1.8% | 760 | 6 |
| **Nandyal** | Rayalaseema | Nandyal | 29 | 14,767 | 11,268.29 km | 3.1% | 747 | 4 |
| **Palnadu** | South Coast Hinterland | Narasaraopet | 28 | 24,037 | 10,790.94 km | 1.0% | 637 | 2 |
| **Parvathipuram Manyam** | North Coast (Agency) | Parvathipuram | 15 | 6,161 | 4,429.68 km | 0.6% | 285 | 1 |
| **Prakasam** | South Coast | Ongole | 38 | 32,133 | 14,848.27 km | 0.4% | 1,071 | 8 |
| **SPSR Nellore** | South Coast | Nellore | 38 | 21,472 | 9,567.77 km | 1.9% | 479 | 4 |
| **Sri Sathya Sai** | Rayalaseema | Puttaparthi | 32 | 18,722 | 12,730.91 km | 2.8% | 648 | 9 |
| **Srikakulam** | North Coast | Srikakulam | 30 | 21,086 | 8,712.00 km | 3.6% | 1,002 | 2 |
| **Tirupati** | Rayalaseema / South | Tirupati | 34 | 24,859 | 9,790.64 km | 4.6% | 652 | 3 |
| **Visakhapatnam** | North Coast (Urban) | Visakhapatnam | 11 | 29,778 | 6,211.04 km | 3.1% | 833 | 0 |
| **Vizianagaram** | North Coast | Vizianagaram | 27 | 20,829 | 7,956.86 km | 3.5% | 687 | 0 |
| **West Godavari** | Godavari Delta | Bhimavaram | 19 | 23,329 | 6,516.48 km | 1.2% | 1,016 | 0 |
| **YSR Kadapa** | Rayalaseema | Kadapa | 36 | 22,919 | 13,586.62 km | 1.7% | 904 | 5 |
| **STATEWIDE AP (26 DISTS)** | **Entire State** | **Amaravati** | **679** | **616,777** | **253,876.07 km** | **2.2%** | **20,627** | **110** |
| **INTERSTATE GATEWAYS BUFFER** | **5 Border Corridors** | **Border Nodes** | **N/A** | **187,165** | **85,121.58 km** | **4.1%** | **5,587** | **42** |
| **TOTAL EXTRACTED DATASET** | **AP + Gateway Buffer** | **Statewide** | **679** | **803,942** | **338,997.65 km** | **2.6%** | **26,214** | **152** |

---

## 3. Road Classification Breakdown per District

The following matrix details the highway classification stratification across all 26 districts:

| District Name | Total Length (km) | Motorway / Trunk | Primary (SH) | Secondary (MDR) | Tertiary (ODR) | Residential | Unclassified / Track |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Alluri Sitharama Raju** | 9,228.33 km | 252 | 152 | 336 | 2,314 | 3,607 | 3,171 |
| **Anakapalli** | 5,902.63 km | 242 | 276 | 506 | 1,298 | 7,918 | 2,762 |
| **Ananthapuramu** | 17,937.44 km | 735 | 314 | 574 | 1,588 | 20,896 | 7,660 |
| **Annamayya** | 11,742.00 km | 507 | 221 | 787 | 1,487 | 13,884 | 4,874 |
| **Bapatla** | 7,710.64 km | 434 | 369 | 714 | 929 | 13,454 | 2,970 |
| **Chittoor** | 8,724.83 km | 890 | 150 | 665 | 1,865 | 9,295 | 2,744 |
| **Dr. B.R. Ambedkar Konaseema** | 3,528.97 km | 125 | 242 | 438 | 463 | 5,208 | 814 |
| **East Godavari** | 7,005.24 km | 455 | 294 | 793 | 931 | 19,425 | 2,618 |
| **Eluru** | 12,718.42 km | 380 | 392 | 943 | 1,787 | 32,425 | 6,624 |
| **Guntur** | 11,306.09 km | 407 | 484 | 720 | 1,192 | 32,617 | 9,120 |
| **Kakinada** | 7,021.23 km | 297 | 375 | 517 | 794 | 20,594 | 2,988 |
| **Krishna** | 12,205.12 km | 581 | 439 | 795 | 1,446 | 30,081 | 10,678 |
| **Kurnool** | 12,996.17 km | 405 | 389 | 643 | 1,149 | 18,257 | 4,909 |
| **NTR** | 9,439.45 km | 417 | 469 | 553 | 1,066 | 23,361 | 5,745 |
| **Nandyal** | 11,268.29 km | 648 | 203 | 483 | 887 | 7,348 | 5,198 |
| **Palnadu** | 10,790.94 km | 476 | 209 | 618 | 915 | 17,203 | 4,616 |
| **Parvathipuram Manyam** | 4,429.68 km | 15 | 203 | 278 | 959 | 3,157 | 1,549 |
| **Prakasam** | 14,848.27 km | 417 | 308 | 568 | 1,788 | 22,355 | 6,697 |
| **SPSR Nellore** | 9,567.77 km | 449 | 279 | 608 | 1,567 | 16,675 | 1,894 |
| **Sri Sathya Sai** | 12,730.91 km | 544 | 312 | 489 | 1,353 | 11,001 | 5,023 |
| **Srikakulam** | 8,712.00 km | 621 | 361 | 739 | 1,741 | 11,836 | 5,788 |
| **Tirupati** | 9,790.64 km | 904 | 454 | 881 | 1,678 | 15,221 | 5,721 |
| **Visakhapatnam** | 6,211.04 km | 175 | 712 | 425 | 1,746 | 19,290 | 7,430 |
| **Vizianagaram** | 7,956.86 km | 357 | 383 | 513 | 1,580 | 12,963 | 5,033 |
| **West Godavari** | 6,516.48 km | 208 | 441 | 1,055 | 854 | 17,324 | 3,447 |
| **YSR Kadapa** | 13,586.62 km | 619 | 354 | 1,201 | 823 | 14,804 | 5,118 |
| **TOTALS (26 DISTS)** | **253,876.07 km** | **11,170** | **8,995** | **17,949** | **33,189** | **447,294** | **123,080** |

---

## 4. Surface Completeness & Disaster Mitigation Profile

- **Explicitly Paved (Asphalt / Concrete):** $2.2\%$ inside AP ($2.6\%$ statewide dataset)
- **Explicitly Unpaved (Dirt / Gravel / Earth):** $2.1\%$ inside AP ($2.1\%$ statewide dataset)
- **Unspecified / Default:** $95.7\%$ inside AP ($95.3\%$ statewide dataset)

### Routing Profile Implementation:
$$\text{Cost}(\text{edge}) = \text{Length} \times \left(\frac{1}{\text{MaxSpeed}}\right) \times \text{SurfacePenalty}$$
- **Explicitly Paved:** $\text{SurfacePenalty} = 1.0$
- **Paved Urban Residential:** $\text{SurfacePenalty} = 1.05$
- **Unspecified Rural Track:** $\text{SurfacePenalty} = 1.50$ (prioritizing certified all-weather paved state corridors)
- **Explicitly Unpaved Dirt:** $\text{SurfacePenalty} = 2.50$ (strongly penalized during active flood/cyclone warnings)

---

## 5. Structural Features: Bridges, Tunnels, and Fords

- **Bridges (26,214 cataloged):** Vital river crossings over the Krishna, Godavari, Pennar, Tungabhadra, Vamsadhara, and Nagavali river systems.
- **Fords / Causeways (152 cataloged):** Submersible river crossings concentrated in the Godavari delta (Amalapuram, Kakinada, Eluru) and Agency foothill streams.
- **Tunnels (1,143 cataloged):** Rail/road underpasses and mountain pass tunnels in the Eastern Ghats and Rayalaseema hill ranges.
- **One-Way Segments (26,133 cataloged):** Preserved in routing graph topology to ensure legal turn restrictions and traffic flow during mass evacuations.

---

## 6. Conclusion & Phase 2 Transition

The Phase 1B District-by-District Coverage Audit certifies that:
1. All 26 reorganized districts of Andhra Pradesh are fully mapped with authentic OpenStreetMap geometries.
2. Arterial highway lifelines maintain cross-border continuity into neighboring states via 5 buffered gateways.
3. Over 803,900 road segments totaling 338,997 km are ready for routing engine compilation.
4. Structural vulnerabilities (26,214 bridges, 152 fords) are indexed for real-time avoidance.

This geospatial data foundation is certified and ready for **Phase 2: Native Valhalla Engine Statewide Deployment**.
