import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/models/disaster_alert.dart';
import '../../../core/models/disaster_type.dart';

/// Clean, high-legibility card rendering an active disaster alert on the dashboard.
/// Follows Apple-like clarity with clear severity distinction and Demo Data tagging.
class AlertCard extends StatefulWidget {
  final DisasterAlert alert;

  const AlertCard({
    super.key,
    required this.alert,
  });

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _isExpanded = false;

  String _getFlaticonForDisaster(DisasterType type) {
    switch (type) {
      case DisasterType.cyclone:
        return AppIcons.cyclone;
      case DisasterType.flood:
        return AppIcons.flood;
      default:
        return AppIcons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final isExpired = alert.isExpired();
    final isCritical = alert.severity == AlertSeverity.critical && !isExpired;

    return Container(
      decoration: BoxDecoration(
        color: isExpired ? AppColors.surfaceSoft : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isExpired
              ? AppColors.border
              : (isCritical
                  ? AppColors.emergencyRed.withOpacity(0.5)
                  : AppColors.border),
          width: isCritical ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Severity Chip + Icon + Demo Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isExpired ? AppColors.slate : alert.severity.color,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  isExpired ? 'EXPIRED' : alert.severity.label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FlaticonView(
                assetPath: _getFlaticonForDisaster(alert.disasterType),
                size: 14,
                color: isExpired ? AppColors.slate : alert.severity.color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  alert.disasterType.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isExpired ? AppColors.slate : alert.severity.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEMO DATA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),

          // Affected Area
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  alert.affectedArea,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description (expandable)
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
            maxLines: _isExpanded ? 10 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Source and Read more
          Row(
            children: [
              Expanded(
                child: Text(
                  'Source: ${alert.source}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Less' : 'Read more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isExpired ? AppColors.slate : alert.severity.color,
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 14,
                        color: isExpired ? AppColors.slate : alert.severity.color,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Expiry and Validity Status Line
          Row(
            children: [
              Icon(
                isExpired
                    ? Icons.history_rounded
                    : (alert.expiresAt == null
                        ? Icons.info_outline_rounded
                        : Icons.access_time_rounded),
                size: 12,
                color: isExpired ? AppColors.critical : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isExpired
                      ? 'Expired at ${alert.expiresAt!.hour.toString().padLeft(2, '0')}:${alert.expiresAt!.minute.toString().padLeft(2, '0')} (Historical record)'
                      : (alert.expiresAt == null
                          ? 'No expiry specified (Advisory notice)'
                          : 'Active until ${alert.expiresAt!.hour.toString().padLeft(2, '0')}:${alert.expiresAt!.minute.toString().padLeft(2, '0')}'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? AppColors.critical : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
