# SurakshaPath: Team Architecture & Contribution Registry

**Project Lead:** Sriram Pinninti  
**Target Repository:** `https://github.com/SP-1512/SurakshaPath`  
**Date Updated:** November 24, 2026  

---

## 1. Official Core Team Roster

| Member | Full Name | Project Role | GitHub Profile | Module Domain |
|:---:|---|---|:---:|---|
| **1** | **Sriram Pinninti** | **Project Lead & System Architect** | [@SP-1512](https://github.com/SP-1512) | Project Coordination, Foundation, UI Shell, GIS Pipeline, Integration |
| **2** | **Pragalapati Naga Bala Sai Vignesh** | **Offline Maps & GPS Subsystem** | [@vigneshpragalapati29-gif](https://github.com/vigneshpragalapati29-gif) | MapLibre Native, OpenFreeMap, GNSS Telemetry, SQLite Tile Caching |
| **3** | **Mullapudi NagaRaju** | **Disaster Intelligence & Routing** | [@NagaRaju2605](https://github.com/NagaRaju2605) | Dijkstra Engine, Hazard Avoidance, Spatial Math, Graph Modeling |
| **4** | **Ganta Ekanadha Sri Sai Shanmukh** | **Shelter Discovery & Emergency SOS** | [@Shanmukh117-GH](https://github.com/Shanmukh117-GH) | Shelter Catalog, Civil Defense Models, SOS Packets, 112/108 Telephony |

---

## 2. Technical Ownership by Codebase Path

```
surakshapath/
├── lib/
│   ├── app/                      # Sriram Pinninti (App bootstrap, route tables)
│   ├── core/
│   │   ├── constants/            # Sriram Pinninti (Design tokens, strings, dimensions)
│   │   ├── models/               # Shanmukh (ShelterModel), NagaRaju (GeoPoint), Sriram (UserLocation)
│   │   └── services/             # Core contracts & interfaces (All members)
│   ├── features/
│   │   ├── home/                 # Sriram Pinninti (Situation Hero Dashboard, bilingual shell)
│   │   ├── map/                  # Sai Vignesh (MapLibre vector view, SQLite cache, GPS telemetry)
│   │   ├── routing/              # NagaRaju (Dijkstra solver, hazard penalty routing, corridor fallback)
│   │   ├── shelters/             # Shanmukh (Shelter discovery, capacity status, pet/accessibility filters)
│   │   └── emergency/            # Shanmukh (Emergency SOS packet builder, 112/108 hotline dispatch)
│   ├── l10n/                     # Sriram Pinninti (English & Telugu ARB bilingual engine)
│   └── navigation/               # Sriram Pinninti (Persistent 5-tab shell & router)
├── backend/
│   ├── geo_pipeline/             # Sriram Pinninti (Statewide AP boundary audits, OSM extraction)
│   └── routing/                  # Sriram Pinninti & NagaRaju (Valhalla POC service & benchmark)
├── test/                         # Sriram Pinninti (83-test verification suite coordination)
└── docs/                         # Team Architectural & Integration Audits
```

---

## 3. GitHub Collaboration & Branch Management Protocols

### 3.1 Repository Permission Strategy
- **Repository Owner:** `@SP-1512` (Admin)
- **Team Collaborators:** `@vigneshpragalapati29-gif`, `@NagaRaju2605`, `@Shanmukh117-GH`
- **Assigned Role:** `Write` access (collaborators can push feature branches, create pull requests, assign issues, and participate in code reviews).
- **Admin Safeguard:** No collaborator is granted administrative permissions to protect repository settings, branch deletion, and security secrets.

### 3.2 Branching Convention
All collaborative feature development must follow strict branch naming prefixes:
- `feature/map-<feature-name>` (Sai Vignesh)
- `feature/routing-<feature-name>` (NagaRaju)
- `feature/shelter-<feature-name>` (Shanmukh)
- `feature/core-<feature-name>` (Sriram)
- `fix/<defect-id>` (All members)

### 3.3 Pull Request Verification Checklist
Before any pull request is merged into `main`:
1. **Static Analysis:** `flutter analyze` must report `0 issues`.
2. **Automated Tests:** `flutter test` must pass 100% of tests.
3. **Data Honesty:** New code must never introduce fabricated GPS fixes, simulated agency citations, or unverified shelter counts.
4. **Peer Review:** At least one peer review approval from the Project Lead or module owner.
