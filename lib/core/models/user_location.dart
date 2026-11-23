/// Origin and authenticity of geographic coordinates.
enum LocationProvenance {
  liveGps,
  manualSelection,
  demo;

  String get label {
    switch (this) {
      case LocationProvenance.liveGps:
        return 'LIVE GPS FIX';
      case LocationProvenance.manualSelection:
        return 'MANUALLY SELECTED';
      case LocationProvenance.demo:
        return 'DEMO LOCATION';
    }
  }

  static LocationProvenance fromString(String? val) {
    switch (val) {
      case 'liveGps':
        return LocationProvenance.liveGps;
      case 'manualSelection':
        return LocationProvenance.manualSelection;
      case 'demo':
      default:
        return LocationProvenance.demo;
    }
  }
}

/// Represents the user's current GPS location and geographic metadata.
class UserLocation {
  final double latitude;
  final double longitude;
  final String locationName;
  final String subArea;
  final double? accuracyMeters;
  final DateTime timestamp;
  final bool isGpsActive;
  final bool isMock;
  final LocationProvenance provenance;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.subArea,
    this.accuracyMeters,
    required this.timestamp,
    this.isGpsActive = false,
    this.isMock = false,
    this.provenance = LocationProvenance.demo,
  });

  /// Default baseline location for demonstration in Coastal Andhra Pradesh (Kakinada Coastal Corridor).
  /// Explicitly marked as mock/simulated with no hardware GPS lock and no fabricated accuracy telemetry.
  factory UserLocation.mockDefault() {
    return UserLocation(
      latitude: 16.9891,
      longitude: 82.2475,
      locationName: 'Kakinada Port Corridor',
      subArea: 'Kakinada District, Andhra Pradesh',
      accuracyMeters: null, // No real GPS telemetry available
      timestamp: DateTime.now(),
      isGpsActive: false, // Hardware GPS is not active
      isMock: true,
      provenance: LocationProvenance.demo,
    );
  }

  /// Factory for verified live hardware GPS coordinates.
  factory UserLocation.live({
    required double latitude,
    required double longitude,
    required String locationName,
    required String subArea,
    required double accuracyMeters,
    DateTime? timestamp,
  }) {
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      subArea: subArea,
      accuracyMeters: accuracyMeters,
      timestamp: timestamp ?? DateTime.now(),
      isGpsActive: true,
      isMock: false,
      provenance: LocationProvenance.liveGps,
    );
  }

  /// Factory for user manually selected corridor / district.
  factory UserLocation.manual({
    required double latitude,
    required double longitude,
    required String locationName,
    required String subArea,
    DateTime? timestamp,
  }) {
    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      subArea: subArea,
      accuracyMeters: null, // Manually selected coordinates have no GPS telemetry
      timestamp: timestamp ?? DateTime.now(),
      isGpsActive: false,
      isMock: true,
      provenance: LocationProvenance.manualSelection,
    );
  }

  /// Whether this location represents an active, verified device GPS fix.
  bool get isLiveFix => !isMock && isGpsActive && accuracyMeters != null;

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E';

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'subArea': subArea,
      'accuracyMeters': accuracyMeters,
      'timestamp': timestamp.toIso8601String(),
      'isGpsActive': isGpsActive,
      'isMock': isMock,
      'provenance': provenance.name,
    };
  }

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    final isMockVal = json['isMock'] as bool? ?? true;
    final provenanceVal = json['provenance'] != null
        ? LocationProvenance.fromString(json['provenance'] as String)
        : (isMockVal ? LocationProvenance.demo : LocationProvenance.liveGps);

    return UserLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 16.9891,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 82.2475,
      locationName: json['locationName'] as String? ?? 'Kakinada Port Corridor',
      subArea: json['subArea'] as String? ?? 'Kakinada District, Andhra Pradesh',
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isGpsActive: json['isGpsActive'] as bool? ?? false,
      isMock: isMockVal,
      provenance: provenanceVal,
    );
  }
}
