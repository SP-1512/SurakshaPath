import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'disaster_type.dart';

enum AlertSeverity {
  advisory,
  watch,
  warning,
  critical;

  String get label {
    switch (this) {
      case AlertSeverity.advisory:
        return 'ADVISORY';
      case AlertSeverity.watch:
        return 'WATCH';
      case AlertSeverity.warning:
        return 'WARNING';
      case AlertSeverity.critical:
        return 'CRITICAL EVACUATION';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.advisory:
        return AppColors.severityAdvisory;
      case AlertSeverity.watch:
        return AppColors.severityWatch;
      case AlertSeverity.warning:
        return AppColors.severityWarning;
      case AlertSeverity.critical:
        return AppColors.severityCritical;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AlertSeverity.advisory:
        return const Color(0xFFEFF6FF);
      case AlertSeverity.watch:
        return const Color(0xFFFEF3C7);
      case AlertSeverity.warning:
        return const Color(0xFFFFEDD5);
      case AlertSeverity.critical:
        return const Color(0xFFFEE2E2);
    }
  }

  static AlertSeverity fromString(String? value) {
    if (value == null) return AlertSeverity.advisory;
    switch (value.toLowerCase()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      case 'watch':
        return AlertSeverity.watch;
      case 'advisory':
      default:
        return AlertSeverity.advisory;
    }
  }
}

/// Explicit expiry status for disaster alerts.
enum AlertExpiryStatus {
  /// The alert has an expiresAt in the future and is currently active.
  active,

  /// The alert has an expiresAt in the past and is no longer active.
  expired,

  /// The alert has no expiresAt specified (unspecified validity window).
  unspecifiedExpiry;

  String get label {
    switch (this) {
      case AlertExpiryStatus.active:
        return 'ACTIVE';
      case AlertExpiryStatus.expired:
        return 'EXPIRED';
      case AlertExpiryStatus.unspecifiedExpiry:
        return 'NO EXPIRY SPECIFIED';
    }
  }
}

/// Standard alert model shared across SurakshaPath features.
class DisasterAlert {
  final String id;
  final String title;
  final String description;
  final DisasterType disasterType;
  final AlertSeverity severity;
  final String affectedArea;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String source;
  final bool isActionRequired;

  const DisasterAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.disasterType,
    required this.severity,
    required this.affectedArea,
    required this.issuedAt,
    this.expiresAt,
    required this.source,
    this.isActionRequired = false,
  });

  factory DisasterAlert.fromJson(Map<String, dynamic> json) {
    return DisasterAlert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Disaster Notice',
      description: json['description'] as String? ?? '',
      disasterType: DisasterType.fromString(json['disasterType'] as String?),
      severity: AlertSeverity.fromString(json['severity'] as String?),
      affectedArea: json['affectedArea'] as String? ?? 'Regional area',
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      source: json['source'] as String? ?? 'Disaster Management Authority',
      isActionRequired: json['isActionRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'disasterType': disasterType.name,
      'severity': severity.name,
      'affectedArea': affectedArea,
      'issuedAt': issuedAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      'source': source,
      'isActionRequired': isActionRequired,
    };
  }

  /// Whether this alert has expired relative to [referenceTime] (defaults to DateTime.now()).
  /// Returns false if [expiresAt] is null (no expiration specified).
  bool isExpired([DateTime? referenceTime]) {
    if (expiresAt == null) return false;
    return (referenceTime ?? DateTime.now()).isAfter(expiresAt!);
  }

  /// Whether this alert is currently active relative to [referenceTime].
  /// An alert is active if it has not expired.
  bool isActive([DateTime? referenceTime]) {
    return !isExpired(referenceTime);
  }

  /// Explicit classification of the alert's expiration status.
  /// Handles null [expiresAt] explicitly without fabricating an expiration date.
  AlertExpiryStatus expiryStatus([DateTime? referenceTime]) {
    if (expiresAt == null) return AlertExpiryStatus.unspecifiedExpiry;
    final now = referenceTime ?? DateTime.now();
    return now.isAfter(expiresAt!)
        ? AlertExpiryStatus.expired
        : AlertExpiryStatus.active;
  }
}
