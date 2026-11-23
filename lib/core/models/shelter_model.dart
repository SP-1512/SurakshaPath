import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ShelterStatus {
  open,
  nearFull,
  full,
  closed;

  String get label {
    switch (this) {
      case ShelterStatus.open:
        return 'OPEN & AVAILABLE';
      case ShelterStatus.nearFull:
        return 'NEAR CAPACITY';
      case ShelterStatus.full:
        return 'FULL';
      case ShelterStatus.closed:
        return 'TEMPORARILY CLOSED';
    }
  }

  String get displayName => label;

  Color get color {
    switch (this) {
      case ShelterStatus.open:
        return AppColors.statusOpen;
      case ShelterStatus.nearFull:
        return AppColors.statusNearFull;
      case ShelterStatus.full:
        return AppColors.statusFull;
      case ShelterStatus.closed:
        return AppColors.statusClosed;
    }
  }

  static ShelterStatus fromString(String? value) {
    if (value == null) return ShelterStatus.open;
    switch (value.toLowerCase()) {
      case 'open':
        return ShelterStatus.open;
      case 'near_full':
      case 'nearfull':
        return ShelterStatus.nearFull;
      case 'full':
        return ShelterStatus.full;
      case 'closed':
      default:
        return ShelterStatus.closed;
    }
  }
}

/// Model representing emergency relief shelters and community safe zones.
class ShelterModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final int capacityTotal;
  final int capacityOccupied;
  final ShelterStatus status;
  final bool isVerified;
  final String contactNumber;
  final List<String> facilities;
  final String? notes;

  const ShelterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.capacityTotal,
    required this.capacityOccupied,
    required this.status,
    this.isVerified = true,
    required this.contactNumber,
    this.facilities = const [],
    this.notes,
  });

  int get availableSpots => (capacityTotal - capacityOccupied).clamp(0, capacityTotal);
  double get occupancyRate => capacityTotal > 0 ? (capacityOccupied / capacityTotal).clamp(0.0, 1.0) : 0.0;
  int get totalCapacity => capacityTotal;
  int get currentOccupancy => capacityOccupied;

  bool get hasWater =>
      facilities.any((f) => f.toLowerCase().contains('water') || f.toLowerCase().contains('drinking'));
  bool get hasMedical =>
      facilities.any((f) => f.toLowerCase().contains('medical') || f.toLowerCase().contains('aid'));
  bool get hasPower =>
      facilities.any((f) => f.toLowerCase().contains('power') || f.toLowerCase().contains('generator'));
  bool get hasBed =>
      facilities.any((f) => f.toLowerCase().contains('bed') || f.toLowerCase().contains('blanket'));
  bool get hasPetsAllowed =>
      facilities.any((f) => f.toLowerCase().contains('pet') || f.toLowerCase().contains('animal'));
  bool get isAccessible =>
      facilities.any((f) => f.toLowerCase().contains('access') || f.toLowerCase().contains('ramp') || f.toLowerCase().contains('wheelchair'));

  factory ShelterModel.fromJson(Map<String, dynamic> json) {
    return ShelterModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Emergency Shelter',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      capacityTotal: (json['capacityTotal'] as num?)?.toInt() ?? 100,
      capacityOccupied: (json['capacityOccupied'] as num?)?.toInt() ?? 0,
      status: ShelterStatus.fromString(json['status'] as String?),
      isVerified: json['isVerified'] as bool? ?? true,
      contactNumber: json['contactNumber'] as String? ?? '112',
      facilities: (json['facilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
      'capacityTotal': capacityTotal,
      'capacityOccupied': capacityOccupied,
      'status': status.name,
      'isVerified': isVerified,
      'contactNumber': contactNumber,
      'facilities': facilities,
      if (notes != null) 'notes': notes,
    };
  }
}
