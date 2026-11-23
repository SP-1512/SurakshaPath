import '../models/data_state.dart';
import '../models/disaster_alert.dart';
import '../models/disaster_type.dart';

/// Contract interface for hazard alert feeds.
/// Team Member 4 (Data & Alerts) will integrate real-time APIs/Push feeds here.
abstract class IAlertService {
  Future<List<DisasterAlert>> getActiveAlerts({
    bool forceRefresh = false,
    DateTime? referenceTime,
  });
  Future<List<DisasterAlert>> getAlertsByDisaster(DisasterType type);
  Future<DisasterAlert?> getHighestSeverityAlert();
}

/// Baseline mock alert service with sample emergency hazard alerts.
/// Enhanced with in-memory TTL caching (5 min), timeout protection,
/// expired alert pruning, and data state tracking.
class MockAlertService implements IAlertService {
  static final MockAlertService _instance = MockAlertService._internal();
  factory MockAlertService() => _instance;
  MockAlertService._internal();

  List<DisasterAlert>? _cachedAlerts;
  DateTime? _lastFetchTime;
  DataState _currentDataState = DataState.unavailable;
  static const Duration cacheTtl = Duration(minutes: 5);
  static const Duration networkTimeout = Duration(seconds: 5);

  bool get isCacheValid =>
      _cachedAlerts != null &&
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < cacheTtl;

  DateTime? get lastFetchTime => _lastFetchTime;
  DataState get currentDataState => _currentDataState;

  void invalidateCache() {
    _cachedAlerts = null;
    _lastFetchTime = null;
    _currentDataState = DataState.unavailable;
  }

  /// Injects custom alerts for test scenarios (e.g. testing expired vs active filtering).
  void setMockAlerts(List<DisasterAlert> alerts) {
    _alerts = List.from(alerts);
    invalidateCache();
  }

  /// Restores default baseline alerts.
  void resetDefaultAlerts() {
    _alerts = List.from(_defaultAlerts);
    invalidateCache();
  }

  static final List<DisasterAlert> _defaultAlerts = [
    DisasterAlert(
      id: 'alert-001',
      title: '[DEMO SCENARIO] Cyclone Alert: Bay of Bengal System',
      description:
          'DEMO SCENARIO: Deep depression over west-central Bay of Bengal intensifying into a cyclonic storm. Gale winds up to 90 km/h and heavy coastal rain projected along Kakinada and Konaseema coast. Fishermen advised not to venture into sea.',
      disasterType: DisasterType.cyclone,
      severity: AlertSeverity.critical,
      affectedArea: 'Kakinada & Konaseema Coastal Corridor, AP',
      issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      source: 'DEMO DATA - Sample Cyclone Bulletin',
      isActionRequired: true,
    ),
    DisasterAlert(
      id: 'alert-002',
      title: '[DEMO SCENARIO] Godavari & Krishna Riparian Flood Advisory',
      description:
          'DEMO SCENARIO: High upstream inflows increasing barrage discharge. Low-lying riparian settlements in East Godavari and Krishna districts advised to monitor local advisories and avoid submerged causeways.',
      disasterType: DisasterType.flood,
      severity: AlertSeverity.warning,
      affectedArea: 'Dowleswaram & Krishna Riparian Zones, AP',
      issuedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      source: 'DEMO DATA - Sample River Advisory',
      isActionRequired: true,
    ),
    DisasterAlert(
      id: 'alert-003',
      title: '[DEMO SCENARIO] Coastal Inundation Advisory - Lowland Causeways',
      description:
          'DEMO SCENARIO: High astronomical tide combined with moderate coastal swells may cause localized waterlogging along Uppada Beach Road and coastal village access roads.',
      disasterType: DisasterType.flood,
      severity: AlertSeverity.advisory,
      affectedArea: 'Uppada Beach Corridor, Kakinada District, AP',
      issuedAt: DateTime.now().subtract(const Duration(minutes: 90)),
      expiresAt: null, // Unspecified expiration window
      source: 'DEMO DATA - Sample Coastal Bulletin',
      isActionRequired: false,
    ),
  ];

  List<DisasterAlert> _alerts = List.from(_defaultAlerts);

  @override
  Future<List<DisasterAlert>> getActiveAlerts({
    bool forceRefresh = false,
    DateTime? referenceTime,
  }) async {
    final now = referenceTime ?? DateTime.now();

    // 1. Serve from valid in-memory cache if available
    if (!forceRefresh && isCacheValid) {
      _currentDataState = DataState.cached;
      final active = _cachedAlerts!.where((a) => !a.isExpired(now)).toList();
      return List.unmodifiable(active);
    }

    // 2. Fetch fresh data with timeout guard
    try {
      final fresh = await Future.delayed(const Duration(milliseconds: 200), () {
        return List<DisasterAlert>.from(_alerts);
      }).timeout(networkTimeout);

      _cachedAlerts = fresh;
      _lastFetchTime = DateTime.now();
      _currentDataState = DataState.fresh;

      final active = fresh.where((a) => !a.isExpired(now)).toList();
      return List.unmodifiable(active);
    } catch (_) {
      // 3. Graceful offline/timeout fallback: prune expired alerts so stale
      // cached warnings are never silently presented as active
      if (_cachedAlerts != null) {
        _currentDataState = DataState.stale;
        final active = _cachedAlerts!.where((a) => !a.isExpired(now)).toList();
        return List.unmodifiable(active);
      }

      final fallbackActive = _alerts.where((a) => !a.isExpired(now)).toList();
      _currentDataState = fallbackActive.isNotEmpty ? DataState.stale : DataState.unavailable;
      return List.unmodifiable(fallbackActive);
    }
  }

  /// Returns all alerts including expired/historical ones, for transparency and record-keeping.
  Future<List<DisasterAlert>> getAllAlerts({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid) {
      return List.unmodifiable(_cachedAlerts!);
    }
    return List.unmodifiable(_alerts);
  }

  /// Returns only expired/historical alerts.
  Future<List<DisasterAlert>> getHistoricalAlerts({DateTime? referenceTime}) async {
    final now = referenceTime ?? DateTime.now();
    final all = await getAllAlerts();
    return List.unmodifiable(all.where((a) => a.isExpired(now)).toList());
  }

  @override
  Future<List<DisasterAlert>> getAlertsByDisaster(DisasterType type) async {
    final list = await getActiveAlerts();
    if (type == DisasterType.all) return list;
    return list.where((a) => a.disasterType == type).toList();
  }

  @override
  Future<DisasterAlert?> getHighestSeverityAlert() async {
    final list = await getActiveAlerts();
    if (list.isEmpty) return null;
    return list.firstWhere(
      (a) => a.severity == AlertSeverity.critical,
      orElse: () => list.first,
    );
  }
}
