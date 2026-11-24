import 'dart:math' as math;
import '../models/data_state.dart';
import '../models/shelter_model.dart';

/// Contract interface for shelter directory and capacity tracking.
/// Team Member 3 (Shelter management & SOS) will plug in live Firestore / backend sync here.
abstract class IShelterService {
  Future<List<ShelterModel>> getAvailableShelters({bool forceRefresh = false});
  Future<ShelterModel?> getClosestSafeShelter([double? userLat, double? userLng]);
  Future<ShelterModel?> getShelterById(String id);
}

/// Baseline mock shelter service providing realistic shelter records for MVP Phase 1.
/// Enhanced with in-memory TTL caching (5 min), timeout protection,
/// and data provenance state tracking.
class MockShelterService implements IShelterService {
  static final MockShelterService _instance = MockShelterService._internal();
  factory MockShelterService() => _instance;
  MockShelterService._internal();

  List<ShelterModel>? _cachedShelters;
  DateTime? _lastFetchTime;
  DataState _currentDataState = DataState.unavailable;
  static const Duration cacheTtl = Duration(minutes: 5);
  static const Duration networkTimeout = Duration(seconds: 5);

  bool get isCacheValid =>
      _cachedShelters != null &&
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < cacheTtl;

  DateTime? get lastFetchTime => _lastFetchTime;
  DataState get currentDataState => _currentDataState;

  void invalidateCache() {
    _cachedShelters = null;
    _lastFetchTime = null;
    _currentDataState = DataState.unavailable;
  }

  final List<ShelterModel> _shelters = const [
    ShelterModel(
      id: 'shelter-101',
      name: 'Kakinada Multi-Purpose Cyclone Shelter (MPCS)',
      address: 'Near Port Road, Suryaraopeta, Kakinada, AP',
      latitude: 16.9604,
      longitude: 82.2382,
      distanceKm: 1.8,
      capacityTotal: 350,
      capacityOccupied: 180,
      status: ShelterStatus.open,
      isVerified: false,
      contactNumber: '+91 884 236 0101',
      facilities: ['Drinking Water', 'First Aid', 'Backup Power', 'Sanitation', 'High Ground', 'Wheelchair Accessible'],
      notes: 'DEMO DATA: Coastal storm shelter on elevated plinth. Unverified sample record.',
    ),
    ShelterModel(
      id: 'shelter-102',
      name: 'Uppada Coastal Cyclone Relief Center',
      address: 'Beach Road Corridor, Uppada, Kakinada District, AP',
      latitude: 17.0850,
      longitude: 82.3270,
      distanceKm: 4.2,
      capacityTotal: 400,
      capacityOccupied: 120,
      status: ShelterStatus.open,
      isVerified: false,
      contactNumber: '+91 884 238 4420',
      facilities: ['Drinking Water', 'First Aid Station', 'Bedding', 'Food Counter', 'Pets Allowed'],
      notes: 'DEMO DATA: Community storm shelter with open staging ground. Unverified sample record.',
    ),
    ShelterModel(
      id: 'shelter-103',
      name: 'Bhavani Island Community Center',
      address: 'Krishna River Corridor, Vijayawada, Krishna District, AP',
      latitude: 16.5180,
      longitude: 80.5980,
      distanceKm: 5.8,
      capacityTotal: 600,
      capacityOccupied: 540,
      status: ShelterStatus.open,
      isVerified: false,
      contactNumber: '+91 866 242 9000',
      facilities: ['High Elevation', 'Emergency Power', 'Ambulance Access', 'Wheelchair Accessible'],
      notes: 'DEMO DATA: Riverfront high-ground relief camp. Unverified sample record.',
    ),
  ];

  @override
  Future<List<ShelterModel>> getAvailableShelters({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid) {
      _currentDataState = DataState.cached;
      return List.unmodifiable(_cachedShelters!);
    }

    try {
      final fresh = await Future.delayed(const Duration(milliseconds: 200), () {
        return List<ShelterModel>.from(_shelters);
      }).timeout(networkTimeout);

      _cachedShelters = fresh;
      _lastFetchTime = DateTime.now();
      _currentDataState = DataState.fresh;
      return List.unmodifiable(_cachedShelters!);
    } catch (_) {
      // Graceful offline/timeout fallback
      if (_cachedShelters != null) {
        _currentDataState = DataState.stale;
        return List.unmodifiable(_cachedShelters!);
      }
      _currentDataState = _shelters.isNotEmpty ? DataState.stale : DataState.unavailable;
      return List.unmodifiable(_shelters);
    }
  }

  @override
  Future<ShelterModel?> getClosestSafeShelter([double? userLat, double? userLng]) async {
    final list = await getAvailableShelters();
    if (list.isEmpty) return null;
    final openShelters = list.where((s) => s.status == ShelterStatus.open).toList();
    final candidates = openShelters.isNotEmpty ? openShelters : List<ShelterModel>.from(list);
    if (userLat != null && userLng != null) {
      double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        const r = 6371.0;
        final dLat = (lat2 - lat1) * (math.pi / 180.0);
        final dLon = (lon2 - lon1) * (math.pi / 180.0);
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1 * (math.pi / 180.0)) * math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
        return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      }
      candidates.sort((a, b) => haversineKm(userLat, userLng, a.latitude, a.longitude)
          .compareTo(haversineKm(userLat, userLng, b.latitude, b.longitude)));
    } else {
      candidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return candidates.first;
  }

  @override
  Future<ShelterModel?> getShelterById(String id) async {
    final list = await getAvailableShelters();
    try {
      return list.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
