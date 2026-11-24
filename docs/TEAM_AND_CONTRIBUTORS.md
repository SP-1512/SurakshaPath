<p align="center">
  <img src="../assets/images/logo_white_bg.png" width="120" alt="SurakshaPath Official Logo" />
</p>

# SurakshaPath: Team Architecture & Contribution Registry

**Project Lead:** Sriram Pinninti  
**Target Repository:** `https://github.com/SP-1512/SurakshaPath`  
**Date Updated:** November 24, 2026  

---

## 1. Official Core Team Roster

| Member | Name | Role | GitHub Profile |
|:---:|---|---|:---:|
| **Member 1** | **Sriram Pinninti** | **Project Lead, System Architect, Backend, Data Management & Alerts Developer** | [@SP-1512](https://github.com/SP-1512) |
| **Member 2** | **Pragalapati Naga Bala Sai Vignesh** | **Offline Maps & GPS Developer** | [@vigneshpragalapati29-gif](https://github.com/vigneshpragalapati29-gif) |
| **Member 3** | **Mullapudi NagaRaju** | **Disaster Intelligence & Routing Developer** | [@NagaRaju2605](https://github.com/NagaRaju2605) |
| **Member 4** | **Ganta Ekanadha Sri Sai Shanmukh** | **Shelter Discovery & Emergency SOS Developer** | [@Shanmukh117-GH](https://github.com/Shanmukh117-GH) |

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
│   │   ├── routing/              # NagaRaju & Sriram (Dijkstra solver, turn-by-turn navigation HUD, corridor fallback)
│   │   ├── shelters/             # Shanmukh (Shelter discovery, capacity status, pet/accessibility filters)
│   │   ├── emergency/            # Shanmukh (Emergency SOS packet builder, 112/108 hotline dispatch)
│   │   └── disaster/             # Sriram Pinninti (Backend alert pipeline, hazard model & ingestion)
│   ├── l10n/                     # Sriram Pinninti (English & Telugu ARB bilingual engine)
│   └── navigation/               # Sriram Pinninti (Persistent 5-tab shell & router)
├── backend/
│   ├── geo_pipeline/             # Sriram Pinninti (Statewide AP boundary audits, OSM extraction)
│   └── routing/                  # Sriram Pinninti & NagaRaju (Valhalla POC service & benchmark)
├── test/                         # Sriram Pinninti (87-test verification suite coordination)
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
