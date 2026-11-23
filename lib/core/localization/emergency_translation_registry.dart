import 'package:flutter/material.dart';

/// Review and vetting status for safety-critical emergency guidance content.
///
/// Life-safety directives (evacuation instructions, hazard warnings, SOS alerts)
/// must NEVER be presented to users via unvetted machine translations.
enum EmergencyTranslationStatus {
  /// Automated, provisional, or community draft. NOT verified for life-safety directives.
  draft,

  /// Submitted to certified linguistic and disaster operations reviewers; pending sign-off.
  awaitingReview,

  /// Formally vetted and approved for live emergency guidance.
  approved,
}

/// Metadata and audit trail for an emergency translation string.
class EmergencyContentRecord {
  final String key;
  final String locale;
  final String sourceEnglish;
  final String translatedText;
  final EmergencyTranslationStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const EmergencyContentRecord({
    required this.key,
    required this.locale,
    required this.sourceEnglish,
    required this.translatedText,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
  });

  bool get isApproved => status == EmergencyTranslationStatus.approved;
}

/// Resolved emergency text with explicit provenance and fallback status.
class ResolvedEmergencyContent {
  final String text;
  final bool isFallback;
  final EmergencyTranslationStatus status;
  final String? disclaimer;

  const ResolvedEmergencyContent({
    required this.text,
    required this.isFallback,
    required this.status,
    this.disclaimer,
  });
}

/// Registry and governance controller for safety-critical translations.
///
/// If a regional translation for a life-safety instruction has not been
/// formally [EmergencyTranslationStatus.approved], this registry safely falls
/// back to the canonical English directive and issues a visible disclaimer pill.
class EmergencyTranslationRegistry {
  EmergencyTranslationRegistry._();

  static final Map<String, EmergencyContentRecord> _registry = {};

  /// Default disclaimer presented when unapproved translation is held back.
  static const String fallbackDisclaimer =
      'Unverified Translation: Showing approved English guidance.';

  /// Register or update an emergency content record.
  static void register(EmergencyContentRecord record) {
    final compositeKey = _makeCompositeKey(record.key, record.locale);
    _registry[compositeKey] = record;
  }

  /// Bulk register emergency records.
  static void registerAll(List<EmergencyContentRecord> records) {
    for (final r in records) {
      register(r);
    }
  }

  /// Resolve emergency content with fail-safe fallback to English.
  static ResolvedEmergencyContent resolve({
    required String key,
    required String locale,
    required String fallbackEnglish,
  }) {
    // English source is always canonical approved source
    if (locale == 'en') {
      return ResolvedEmergencyContent(
        text: fallbackEnglish,
        isFallback: false,
        status: EmergencyTranslationStatus.approved,
      );
    }

    final compositeKey = _makeCompositeKey(key, locale);
    final record = _registry[compositeKey];

    // If no record exists or record is not approved, fail-safe to English
    if (record == null || !record.isApproved) {
      return ResolvedEmergencyContent(
        text: record?.sourceEnglish ?? fallbackEnglish,
        isFallback: true,
        status: record?.status ?? EmergencyTranslationStatus.draft,
        disclaimer: fallbackDisclaimer,
      );
    }

    // Approved regional translation
    return ResolvedEmergencyContent(
      text: record.translatedText,
      isFallback: false,
      status: EmergencyTranslationStatus.approved,
    );
  }

  /// Clear all registered records (useful for test isolation).
  static void clear() {
    _registry.clear();
  }

  static String _makeCompositeKey(String key, String locale) => '$locale:$key';
}

/// Disclaimer pill indicating when unapproved regional translations fall back to English.
class EmergencyReviewDisclaimerPill extends StatelessWidget {
  final String? message;

  const EmergencyReviewDisclaimerPill({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber 100
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8), // Amber 500
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: Color(0xFFB45309), // Amber 700
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              message ?? EmergencyTranslationRegistry.fallbackDisclaimer,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E), // Amber 800
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
