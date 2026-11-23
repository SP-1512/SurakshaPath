import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/models/shelter_model.dart';

/// Metadata describing a downloadable offline region.
class OfflineRegionDefinitionItem {
  final String id;
  final String name;
  final String description;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final double minZoom;
  final double maxZoom;
  final int estimatedTiles;
  final double estimatedSizeMb;

  const OfflineRegionDefinitionItem({
    required this.id,
    required this.name,
    required this.description,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.minZoom,
    required this.maxZoom,
    required this.estimatedTiles,
    required this.estimatedSizeMb,
  });

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}

/// Information about a downloaded region stored on the device.
class DownloadedRegionRecord {
  final String id;
  final String name;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final double minZoom;
  final double maxZoom;
  final int tileCount;
  final DateTime downloadedAt;

  DownloadedRegionRecord({
    required this.id,
    required this.name,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'minLat': minLat,
        'maxLat': maxLat,
        'minLon': minLon,
        'maxLon': maxLon,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'tileCount': tileCount,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedRegionRecord.fromMap(Map<String, dynamic> map) =>
      DownloadedRegionRecord(
        id: map['id'] as String,
        name: map['name'] as String,
        minLat: (map['minLat'] as num).toDouble(),
        maxLat: (map['maxLat'] as num).toDouble(),
        minLon: (map['minLon'] as num).toDouble(),
        maxLon: (map['maxLon'] as num).toDouble(),
        minZoom: (map['minZoom'] as num).toDouble(),
        maxZoom: (map['maxZoom'] as num).toDouble(),
        tileCount: (map['tileCount'] as num).toInt(),
        downloadedAt: DateTime.parse(map['downloadedAt'] as String),
      );

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}

/// Progress update during offline download.
class DownloadProgressStatus {
  final double progress; // 0.0 to 1.0
  final int completedResources;
  final int totalResources;
  final String message;
  final bool isCompleted;
  final String? error;

  const DownloadProgressStatus({
    required this.progress,
    required this.completedResources,
    required this.totalResources,
    required this.message,
    this.isCompleted = false,
    this.error,
  });

  bool get hasError => error != null;
}

/// Service managing MapLibre offline downloads, SQLite shelter cache,
/// and OpenFreeMap compliance for Coastal Andhra Pradesh.
class OfflineMapService {
  static final OfflineMapService _instance = OfflineMapService._internal();
  factory OfflineMapService() => _instance;
  OfflineMapService._internal();

  // ── OpenFreeMap & Andhra Pradesh Constants ─────────────────────────────────
  /// Public OpenFreeMap Liberty style (no API key required).
  static const String openFreeMapStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Legal attribution string required by OpenFreeMap & OpenStreetMap.
  static const String mapAttribution =
      'OpenFreeMap © OpenMapTiles | Map data © OpenStreetMap contributors';

  /// Required User-Agent identifying SurakshaPath.
  static const String userAgent = 'SurakshaPath/1.0 (com.example.surakshapath)';

  /// Andhra Pradesh state geographic center & zoom.
  static const double apCenterLat = 15.9129;
  static const double apCenterLon = 79.7400;
  static const double apInitialZoom = 6.8;

  /// OpenFreeMap single download limit: 3,000 tiles OR 50 MB.
  static const int maxPermittedTilesPerDownload = 3000;
  static const double maxPermittedMbPerDownload = 50.0;

  // ── Predefined Permitted Regions for Coastal Andhra Pradesh ────────────────
  static const List<OfflineRegionDefinitionItem> predefinedRegions = [
    OfflineRegionDefinitionItem(
      id: 'ap_kakinada_port',
      name: 'Kakinada Port & Coastal Belt',
      description: 'Cyclone-prone port sector and relief corridors (Zoom 11–13)',
      minLat: 16.90,
      maxLat: 17.05,
      minLon: 82.20,
      maxLon: 82.30,
      minZoom: 11.0,
      maxZoom: 13.0,
      estimatedTiles: 260,
      estimatedSizeMb: 3.8,
    ),
    OfflineRegionDefinitionItem(
      id: 'ap_visakhapatnam_coast',
      name: 'Visakhapatnam Harbor & Coast',
      description: 'Harbor sector and cyclone shelter belt (Zoom 11–13)',
      minLat: 17.66,
      maxLat: 17.75,
      minLon: 83.20,
      maxLon: 83.33,
      minZoom: 11.0,
      maxZoom: 13.0,
      estimatedTiles: 320,
      estimatedSizeMb: 4.5,
    ),
    OfflineRegionDefinitionItem(
      id: 'ap_vijayawada_basin',
      name: 'Vijayawada Krishna River Basin',
      description: 'Krishna flood plain and urban relief corridors (Zoom 11–13)',
      minLat: 16.48,
      maxLat: 16.55,
      minLon: 80.60,
      maxLon: 80.68,
      minZoom: 11.0,
      maxZoom: 13.0,
      estimatedTiles: 290,
      estimatedSizeMb: 4.1,
    ),
    OfflineRegionDefinitionItem(
      id: 'ap_state_overview',
      name: 'Andhra Pradesh Statewide Overview',
      description: 'Macro state boundary & major highway corridors only (Zoom 5–7)',
      minLat: 12.60,
      maxLat: 19.15,
      minLon: 76.75,
      maxLon: 84.80,
      minZoom: 5.0,
      maxZoom: 7.0,
      estimatedTiles: 450,
      estimatedSizeMb: 6.2,
    ),
  ];

  Database? _db;
  OfflineManager? _offlineManager;

  // ── Database Initialization ────────────────────────────────────────────────
  Future<void> initDatabase() async {
    if (_db != null && _db!.isOpen) return;
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final String dbPath = p.join(docs.path, 'surakshapath_offline.db');

      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (Database db, int version) async {
          // Shelters table (storing reconciled ShelterModel)
          await db.execute('''
            CREATE TABLE shelters (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              address TEXT NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              distanceKm REAL NOT NULL,
              capacityTotal INTEGER NOT NULL,
              capacityOccupied INTEGER NOT NULL,
              status TEXT NOT NULL,
              isVerified INTEGER NOT NULL,
              contactNumber TEXT NOT NULL,
              facilities TEXT NOT NULL,
              notes TEXT
            )
          ''');

          // Downloaded regions metadata table
          await db.execute('''
            CREATE TABLE downloaded_regions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              minLat REAL NOT NULL,
              maxLat REAL NOT NULL,
              minLon REAL NOT NULL,
              maxLon REAL NOT NULL,
              minZoom REAL NOT NULL,
              maxZoom REAL NOT NULL,
              tileCount INTEGER NOT NULL,
              downloadedAt TEXT NOT NULL
            )
          ''');

          await _seedDemoShelters(db);
        },
      );
      debugPrint('[OfflineMapService] Local SQLite ready at $dbPath');
    } catch (e) {
      debugPrint('[OfflineMapService] Database initialization error: $e');
    }
  }

  /// Seeds authentic Coastal AP shelter records with honest demo flags.
  Future<void> _seedDemoShelters(Database db) async {
    final List<ShelterModel> defaultShelters = [
      const ShelterModel(
        id: 'shelter-101',
        name: 'Kakinada Multi-Purpose Cyclone Shelter (MPCS)',
        address: 'Collectorate Road, Kakinada, Andhra Pradesh 533001',
        latitude: 16.9891,
        longitude: 82.2475,
        distanceKm: 0.8,
        capacityTotal: 350,
        capacityOccupied: 170,
        status: ShelterStatus.open,
        isVerified: false,
        contactNumber: '0884-2361234',
        facilities: ['Drinking Water', 'Medical First Aid', 'Backup Power', 'Wheelchair Accessible'],
        notes: 'DEMO DATA ONLY - Unverified capacity. Coastal AP demonstration.',
      ),
      const ShelterModel(
        id: 'shelter-102',
        name: 'Uppada Coastal Cyclone Relief Center',
        address: 'Beach Road, Uppada, Kakinada District, AP 533448',
        latitude: 17.0850,
        longitude: 82.3290,
        distanceKm: 3.2,
        capacityTotal: 250,
        capacityOccupied: 95,
        status: ShelterStatus.open,
        isVerified: false,
        contactNumber: '0884-2395678',
        facilities: ['Drinking Water', 'Restrooms', 'Pets Allowed'],
        notes: 'DEMO DATA ONLY - Unverified capacity. Coastal AP demonstration.',
      ),
      const ShelterModel(
        id: 'shelter-103',
        name: 'Bhavani Island Community Center',
        address: 'Krishna River Front, Vijayawada, AP 520012',
        latitude: 16.5167,
        longitude: 80.5975,
        distanceKm: 5.6,
        capacityTotal: 500,
        capacityOccupied: 480,
        status: ShelterStatus.nearFull,
        isVerified: false,
        contactNumber: '0866-2429999',
        facilities: ['High Elevation', 'Medical Aid', 'Wheelchair Accessible'],
        notes: 'DEMO DATA ONLY - Elevated flood shelter zone.',
      ),
      const ShelterModel(
        id: 'shelter-104',
        name: 'Visakhapatnam Harbor Relief Center',
        address: 'Port Area, Visakhapatnam, AP 530035',
        latitude: 17.6868,
        longitude: 83.2185,
        distanceKm: 4.1,
        capacityTotal: 400,
        capacityOccupied: 120,
        status: ShelterStatus.open,
        isVerified: false,
        contactNumber: '0891-2560000',
        facilities: ['Storm Shutters', 'Drinking Water', 'Backup Power'],
        notes: 'DEMO DATA ONLY - Cyclone relief transit sector.',
      ),
    ];

    for (final s in defaultShelters) {
      await db.insert(
        'shelters',
        {
          'id': s.id,
          'name': s.name,
          'address': s.address,
          'latitude': s.latitude,
          'longitude': s.longitude,
          'distanceKm': s.distanceKm,
          'capacityTotal': s.capacityTotal,
          'capacityOccupied': s.capacityOccupied,
          'status': s.status.name,
          'isVerified': s.isVerified ? 1 : 0,
          'contactNumber': s.contactNumber,
          'facilities': jsonEncode(s.facilities),
          'notes': s.notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Retrieves locally saved shelters with optional accessibility / pet filters.
  Future<List<ShelterModel>> getSavedShelters({
    bool? petsAllowed,
    bool? accessible,
  }) async {
    try {
      await initDatabase();
      if (_db == null) return _fallbackShelters(petsAllowed: petsAllowed, accessible: accessible);

      final List<Map<String, dynamic>> rows = await _db!.query('shelters');
      if (rows.isEmpty) {
        return _fallbackShelters(petsAllowed: petsAllowed, accessible: accessible);
      }

      List<ShelterModel> list = rows.map((r) {
        List<String> fac = [];
        try {
          fac = (jsonDecode(r['facilities'] as String) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}

        return ShelterModel(
          id: r['id'] as String,
          name: r['name'] as String,
          address: r['address'] as String,
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
          distanceKm: (r['distanceKm'] as num).toDouble(),
          capacityTotal: (r['capacityTotal'] as num).toInt(),
          capacityOccupied: (r['capacityOccupied'] as num).toInt(),
          status: ShelterStatus.fromString(r['status'] as String?),
          isVerified: (r['isVerified'] as int?) == 1,
          contactNumber: r['contactNumber'] as String,
          facilities: fac,
          notes: r['notes'] as String?,
        );
      }).toList();

      if (petsAllowed == true) {
        list = list.where((s) => s.hasPetsAllowed).toList();
      }
      if (accessible == true) {
        list = list.where((s) => s.isAccessible).toList();
      }

      return list;
    } catch (e) {
      debugPrint('[OfflineMapService] Error fetching shelters: $e');
      return _fallbackShelters(petsAllowed: petsAllowed, accessible: accessible);
    }
  }

  List<ShelterModel> _fallbackShelters({bool? petsAllowed, bool? accessible}) {
    List<ShelterModel> list = const [
      ShelterModel(
        id: 'shelter-101',
        name: 'Kakinada Multi-Purpose Cyclone Shelter (MPCS)',
        address: 'Collectorate Road, Kakinada, AP',
        latitude: 16.9891,
        longitude: 82.2475,
        distanceKm: 0.8,
        capacityTotal: 350,
        capacityOccupied: 170,
        status: ShelterStatus.open,
        isVerified: false,
        contactNumber: '0884-2361234',
        facilities: ['Drinking Water', 'Medical First Aid', 'Wheelchair Accessible'],
        notes: 'DEMO DATA ONLY - Unverified capacity.',
      ),
      ShelterModel(
        id: 'shelter-102',
        name: 'Uppada Coastal Cyclone Relief Center',
        address: 'Beach Road, Uppada, AP',
        latitude: 17.0850,
        longitude: 82.3290,
        distanceKm: 3.2,
        capacityTotal: 250,
        capacityOccupied: 95,
        status: ShelterStatus.open,
        isVerified: false,
        contactNumber: '0884-2395678',
        facilities: ['Drinking Water', 'Pets Allowed'],
        notes: 'DEMO DATA ONLY - Unverified capacity.',
      ),
    ];
    if (petsAllowed == true) list = list.where((s) => s.hasPetsAllowed).toList();
    if (accessible == true) list = list.where((s) => s.isAccessible).toList();
    return list;
  }

  // ── Offline Manager Setup ──────────────────────────────────────────────────
  Future<OfflineManager?> getOfflineManager() async {
    if (kIsWeb) return null;
    if (_offlineManager != null) return _offlineManager;
    try {
      _offlineManager = await OfflineManager.createInstance();
      return _offlineManager;
    } catch (e) {
      debugPrint('[OfflineMapService] OfflineManager init error: $e');
      return null;
    }
  }

  // ── Tile Count Estimator (OpenFreeMap Limit Enforcement) ─────────────────────
  static int estimateTileCount({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required double minZoom,
    required double maxZoom,
  }) {
    int totalTiles = 0;
    final int startZ = minZoom.floor();
    final int endZ = maxZoom.ceil();

    for (int z = startZ; z <= endZ; z++) {
      final double n = math.pow(2.0, z).toDouble();

      final double xMin = ((minLon + 180.0) / 360.0 * n).clamp(0.0, n - 1);
      final double xMax = ((maxLon + 180.0) / 360.0 * n).clamp(0.0, n - 1);

      final double radMinLat = (minLat * math.pi / 180.0).clamp(-1.4844, 1.4844);
      final double radMaxLat = (maxLat * math.pi / 180.0).clamp(-1.4844, 1.4844);

      final double yMin = ((1.0 -
                  math.log(math.tan(radMaxLat) + 1.0 / math.cos(radMaxLat)) /
                      math.pi) /
              2.0 *
              n)
          .clamp(0.0, n - 1);

      final double yMax = ((1.0 -
                  math.log(math.tan(radMinLat) + 1.0 / math.cos(radMinLat)) /
                      math.pi) /
              2.0 *
              n)
          .clamp(0.0, n - 1);

      final int tilesX = (xMax.floor() - xMin.floor()).abs() + 1;
      final int tilesY = (yMax.floor() - yMin.floor()).abs() + 1;

      totalTiles += (tilesX * tilesY);
    }
    return totalTiles;
  }

  // ── Offline Region Download (ZERO SIMULATION, HONEST FAILURE) ───────────────
  Stream<DownloadProgressStatus> downloadRegion(
    OfflineRegionDefinitionItem item,
  ) async* {
    if (kIsWeb) {
      yield const DownloadProgressStatus(
        progress: 0.0,
        completedResources: 0,
        totalResources: 0,
        message: 'Offline downloads not supported on Flutter Web.',
        error: 'Platform unsupported',
      );
      return;
    }

    final int estimatedTiles = estimateTileCount(
      minLat: item.minLat,
      maxLat: item.maxLat,
      minLon: item.minLon,
      maxLon: item.maxLon,
      minZoom: item.minZoom,
      maxZoom: item.maxZoom,
    );

    if (estimatedTiles > maxPermittedTilesPerDownload) {
      yield DownloadProgressStatus(
        progress: 0.0,
        completedResources: 0,
        totalResources: estimatedTiles,
        message:
            'Region exceeds OpenFreeMap limit of $maxPermittedTilesPerDownload tiles (Requested: $estimatedTiles tiles).',
        error: 'Tile limit exceeded',
      );
      return;
    }

    yield DownloadProgressStatus(
      progress: 0.05,
      completedResources: 0,
      totalResources: estimatedTiles,
      message: 'Connecting to native tile manager for ${item.name}...',
    );

    try {
      final manager = await getOfflineManager();
      if (manager == null) {
        // Honest failure report: never simulate success or write fake records
        yield DownloadProgressStatus(
          progress: 0.0,
          completedResources: 0,
          totalResources: estimatedTiles,
          message: 'Native MapLibre offline manager is unavailable on this device/environment.',
          error: 'Native manager unavailable',
          isCompleted: false,
        );
        return;
      }

      final bounds = GeoBox(
        west: item.minLon,
        south: item.minLat,
        east: item.maxLon,
        north: item.maxLat,
      );

      final definition = OfflineTilePyramidRegionDefinition(
        bounds: bounds,
        styleUrl: openFreeMapStyleUrl,
        minZoom: item.minZoom,
        maxZoom: item.maxZoom,
        pixelRatio: 1.0,
      );

      final downloadStream = manager.downloadRegion(
        definition: definition,
        metadata: {'name': item.name, 'id': item.id},
      );

      bool completedSuccessfully = false;

      await for (final update in downloadStream) {
        if (update.downloadCompleted) {
          // Persist record ONLY when confirmed by native engine
          await _saveDownloadedRegionRecord(
            DownloadedRegionRecord(
              id: item.id,
              name: item.name,
              minLat: item.minLat,
              maxLat: item.maxLat,
              minLon: item.minLon,
              maxLon: item.maxLon,
              minZoom: item.minZoom,
              maxZoom: item.maxZoom,
              tileCount: estimatedTiles,
              downloadedAt: DateTime.now(),
            ),
          );

          completedSuccessfully = true;
          yield DownloadProgressStatus(
            progress: 1.0,
            completedResources: estimatedTiles,
            totalResources: estimatedTiles,
            message: 'Download complete: ${item.name} stored for offline use.',
            isCompleted: true,
          );
          break;
        } else {
          final completed = update.status.completedResourceCount;
          final required = math.max(update.status.requiredResourceCount, estimatedTiles);
          final double pVal = required > 0 ? (completed / required).clamp(0.0, 0.99) : 0.1;

          yield DownloadProgressStatus(
            progress: pVal,
            completedResources: completed,
            totalResources: required,
            message: 'Downloading tiles ($completed / $required)...',
          );
        }
      }

      if (!completedSuccessfully) {
        yield DownloadProgressStatus(
          progress: 0.0,
          completedResources: 0,
          totalResources: estimatedTiles,
          message: 'Download terminated before completion. No offline record saved.',
          error: 'Incomplete download',
        );
      }
    } catch (e) {
      debugPrint('[OfflineMapService] Native download failure: $e');
      // Honest failure: do NOT simulate or write fake records
      yield DownloadProgressStatus(
        progress: 0.0,
        completedResources: 0,
        totalResources: estimatedTiles,
        message: 'Download failed: $e',
        error: e.toString(),
        isCompleted: false,
      );
    }
  }

  // ── Downloaded Regions Management ──────────────────────────────────────────
  Future<void> _saveDownloadedRegionRecord(DownloadedRegionRecord record) async {
    await initDatabase();
    if (_db != null) {
      await _db!.insert(
        'downloaded_regions',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Retrieves list of all persisted offline regions from SQLite.
  Future<List<DownloadedRegionRecord>> getDownloadedRegions() async {
    try {
      await initDatabase();
      if (_db == null) return [];
      final List<Map<String, dynamic>> rows =
          await _db!.query('downloaded_regions', orderBy: 'downloadedAt DESC');
      return rows.map((r) => DownloadedRegionRecord.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[OfflineMapService] Error getting downloaded regions: $e');
      return [];
    }
  }

  /// Deletes a downloaded region record from local SQLite.
  Future<void> deleteRegion(String id) async {
    try {
      await initDatabase();
      if (_db != null) {
        await _db!.delete('downloaded_regions', where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('[OfflineMapService] Error deleting region: $e');
    }
  }

  /// Checks if a coordinate falls inside any downloaded region bounding box.
  /// Note: Geographical bounding-box check; actual tile rendering is managed by native cache.
  Future<bool> isLocationInsideDownloadedRegion(
      double latitude, double longitude) async {
    final regions = await getDownloadedRegions();
    for (final r in regions) {
      if (r.contains(latitude, longitude)) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _offlineManager?.dispose();
    _offlineManager = null;
    _db?.close();
    _db = null;
  }
}
