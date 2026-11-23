# SurakshaPath - Architecture & Team Integration Guide (MVP)

## 1. System Vision
SurakshaPath is a disaster evacuation assistance mobile application created for real-world emergency situations (cyclones, flash floods, earthquakes, urban fires).
The system prioritizes high-contrast visibility, minimal cognitive load under stress, low battery consumption, and offline-first availability.

---

## 2. Team Member Module Allocation (3-Day MVP Plan)

```
========================================================================================
Member             Module / Ownership                Target Path & Artifacts
========================================================================================
Architect (Lead)   Phase 1 Foundation, Theme, Shell  `lib/app`, `lib/core`, `lib/navigation`
Member 1           Offline Maps & GPS Subsystem      `lib/features/map/`
Member 2           Disaster Routing & Avoidance      `lib/features/routing/`
Member 3           Shelter Management & SOS Center   `lib/features/shelters/`, `emergency/`
Member 4           Data Feeds & Hazard Alerts        `lib/features/disaster/`, `assets/data/`
========================================================================================
```

---

## 3. Core Directory Layout

```
lib/
  main.dart                      # Application bootstrap & System UI overlays
  app/
    app.dart                     # MaterialApp, Theme binding, and route configuration
  core/
    constants/                   # Colors, Dimensions, Strings, Semantics
    theme/                       # Material 3 light & disaster high-contrast themes
    models/                      # Interoperable data contracts (Alerts, Shelters, Location)
    services/                    # Contract interfaces & mock fallbacks
  features/
    home/                        # Responsive Home Dashboard & Widgets
    map/                         # Offline Map screen & GPS puck (Member 1)
    disaster/                    # Disaster intelligence & alert feeds (Member 4)
    routing/                     # Safe evacuation route generation (Member 2)
    shelters/                    # Shelter directory & capacity indicators (Member 3)
    emergency/                   # Emergency SOS & broadcast dispatch (Member 3)
  navigation/
    app_router.dart              # Named route paths and generators
    main_navigation_shell.dart   # Persistent 5-tab bottom navigation shell
assets/
  images/                        # Logos and vector emergency badges
  icons/                         # Custom hazard icons
  data/                          # Bundled JSON for 100% offline fallback
docs/                            # Architecture and module contracts
backend/                         # Backend sync specifications
test/                            # Unit & widget integration tests
```

---

## 4. Contract Interfaces for Independent Team Development

### A. Location Service Contract (`lib/core/services/location_service.dart`)
```dart
abstract class ILocationService {
  Future<UserLocation> getCurrentLocation();
  Stream<UserLocation> getLocationStream();
  bool isGpsEnabled();
}
```
*Member 1 task*: Replace `MockLocationService` with `geolocator` plugin integration without breaking caller widgets.

### B. Shelter Service Contract (`lib/core/services/shelter_service.dart`)
```dart
abstract class IShelterService {
  Future<List<ShelterModel>> getAvailableShelters();
  Future<ShelterModel?> getClosestSafeShelter();
  Future<ShelterModel?> getShelterById(String id);
}
```
*Member 3 task*: Plug in Firestore collection sync or local SQLite cache.

### C. Alert Service Contract (`lib/core/services/alert_service.dart`)
```dart
abstract class IAlertService {
  Future<List<DisasterAlert>> getActiveAlerts();
  Future<List<DisasterAlert>> getAlertsByDisaster(DisasterType type);
  Future<DisasterAlert?> getHighestSeverityAlert();
}
```
*Member 4 task*: Hook into IMD/SDMA weather alert endpoints or push notifications.

---

## 5. Offline Operation Strategy
1. **Fallback Bundled Data**: `assets/data/sample_shelters.json` and `sample_alerts.json` are bundled inside the APK. If cellular network drops, the app falls back immediately to bundled data.
2. **GPS Accuracy**: Relies directly on satellite GPS coordinates (`accuracyMeters`) regardless of internet connection.
3. **Emergency Helplines**: Local emergency tel-URIs (`tel:112`, `tel:1070`, `tel:108`) work over cellular voice networks without internet data.
