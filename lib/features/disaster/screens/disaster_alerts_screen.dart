import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/disaster_alert.dart';
import '../../../core/models/disaster_type.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../navigation/app_router.dart';

/// Module Screen: Disaster Alert & Intelligence Center.
/// Tesla & PlayStation inspired: Clear severity hierarchy, distinct cinematic treatment
/// for critical alerts, minimal notification cards, and grounded data sources.
class DisasterAlertsScreen extends StatefulWidget {
  const DisasterAlertsScreen({super.key});

  @override
  State<DisasterAlertsScreen> createState() => _DisasterAlertsScreenState();
}

class _DisasterAlertsScreenState extends State<DisasterAlertsScreen> {
  final IAlertService _alertService = MockAlertService();
  List<DisasterAlert> _allAlerts = [];
  List<DisasterAlert> _filteredAlerts = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final data = await _alertService.getActiveAlerts();
    if (mounted) {
      setState(() {
        _allAlerts = data;
        _applyFilter(_selectedFilter);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'Critical') {
        _filteredAlerts = _allAlerts
            .where((a) => a.severity == AlertSeverity.critical)
            .toList();
      } else if (filter == 'High Risk') {
        _filteredAlerts = _allAlerts
            .where((a) =>
                a.severity == AlertSeverity.critical ||
                a.severity == AlertSeverity.warning)
            .toList();
      } else {
        _filteredAlerts = _allAlerts;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = _allAlerts
        .where((a) => a.severity == AlertSeverity.critical)
        .length;

    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppHeader(customTitle: AppStrings.navAlerts),
          body: Column(
        children: [
          // 1. Filter Chips Header (Horizontally scrollable for small devices)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All (${_allAlerts.length})', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Critical ($criticalCount)', 'Critical'),
                  const SizedBox(width: 8),
                  _buildFilterChip('High Risk', 'High Risk'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 2. Alerts Feed
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    color: AppColors.brandBlueDeep,
                    child: _filteredAlerts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppDimensions.space24),
                              child: Text(
                                'No active hazard alerts in this severity category.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppDimensions.space16),
                            itemCount: _filteredAlerts.length + 1, // +1 for survival guidelines
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppDimensions.space14),
                            itemBuilder: (context, index) {
                              if (index < _filteredAlerts.length) {
                                final alert = _filteredAlerts[index];
                                if (alert.severity == AlertSeverity.critical) {
                                  return _CriticalAlertHeroCard(alert: alert);
                                } else {
                                  return _StandardAlertCard(alert: alert);
                                }
                              } else {
                                return const _SurvivalGuidelinesCard();
                              }
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  },
);
}

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyFilter(value),
      selectedColor: AppColors.brandBlueDeep,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.brandBlueDeep : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
    );
  }
}

/// Cinematic PlayStation/Tesla Hero card for Critical Alerts.
class _CriticalAlertHeroCard extends StatelessWidget {
  final DisasterAlert alert;

  const _CriticalAlertHeroCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1113), // Deep dark crimson surface
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium), // 12px
        border: Border.all(color: AppColors.emergencyRed, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33DC2626),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Pill & Source Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlaticonView(
                      assetPath: AppIcons.warning,
                      size: 12,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'CRITICAL EVACUATION ALERT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Text(
                  'Sample data',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space14),

          // Title
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Affected Location
          Row(
            children: [
              const FlaticonView(
                assetPath: AppIcons.pin,
                size: 14,
                color: Color(0xFFFCA5A5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Affected Area: ${alert.affectedArea}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            alert.description,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppDimensions.space16),

          // Actionable Checklist Box
          Container(
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immediate Safety Directives:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 6),
                _ChecklistRow(text: 'Evacuate coastal low-lying sectors immediately'),
                _ChecklistRow(text: 'Move along designated high-ground corridors'),
                _ChecklistRow(text: 'Secure drinking water and essential medications'),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),

          // Source & Timestamp Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Source: ${alert.source}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Issued 2 hours ago',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space14),

          // Action: Find Nearby Shelter
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.shelters);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Find safe shelters now',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String text;

  const _ChecklistRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: AppColors.emeraldGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard structured alert card for warnings and advisories (Apple Clarity).
class _StandardAlertCard extends StatelessWidget {
  final DisasterAlert alert;

  const _StandardAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isWarning = alert.severity == AlertSeverity.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium), // 12px
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Severity & Flaticon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: alert.severity.color,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  alert.severity.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FlaticonView(
                assetPath: alert.disasterType == DisasterType.flood
                    ? AppIcons.flood
                    : AppIcons.warning,
                size: 16,
                color: alert.severity.color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  alert.disasterType.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: alert.severity.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sample data',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),

          // Area
          Text(
            'Area: ${alert.affectedArea}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Source: ${alert.source}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isWarning ? '45 mins ago' : '90 mins ago',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Offline Emergency Preparedness Guidelines.
class _SurvivalGuidelinesCard extends StatelessWidget {
  const _SurvivalGuidelinesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.brandBlueDeep),
              SizedBox(width: 8),
              Text(
                'Emergency Survival Checklist',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '• Keep phone charged and save offline maps.\n• Pack 3L drinking water per family member.\n• Keep government ID, cash, and essential medicines in a waterproof bag.\n• In floodwaters: Never drive through standing water or low underpasses.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
