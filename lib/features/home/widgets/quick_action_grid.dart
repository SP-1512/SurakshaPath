import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';

/// Revolut & Apple-inspired minimal quick action navigation row.
/// Features 4 circular vector action nodes with crisp typography and generous whitespace.
class QuickActionGrid extends StatelessWidget {
  final VoidCallback onOpenMap;
  final VoidCallback onOpenShelters;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenHelplines;

  const QuickActionGrid({
    super.key,
    required this.onOpenMap,
    required this.onOpenShelters,
    required this.onOpenAlerts,
    required this.onOpenHelplines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.space4),
          child: Text(
            AppStrings.sectionQuickActions,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space12),

        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                flaticonAsset: AppIcons.map,
                iconColor: AppColors.brandBlueDeep,
                bgColor: const Color(0xFFEFF6FF),
                title: 'Evac Map',
                subtitle: 'Simulated corridors',
                onTap: onOpenMap,
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: _QuickActionCard(
                flaticonAsset: AppIcons.shelter,
                iconColor: AppColors.emeraldGreen,
                bgColor: const Color(0xFFECFDF5),
                title: 'Safe Shelters',
                subtitle: 'Directory & spots',
                onTap: onOpenShelters,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                flaticonAsset: AppIcons.warning,
                iconColor: AppColors.warningOrange,
                bgColor: const Color(0xFFFFF7ED),
                title: 'Hazard Alerts',
                subtitle: 'Safety advisories',
                onTap: onOpenAlerts,
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: _QuickActionCard(
                flaticonAsset: AppIcons.phone,
                iconColor: AppColors.emergencyRed,
                bgColor: const Color(0xFFFEE2E2),
                title: 'Helplines',
                subtitle: '112, NDRF, Ambulance',
                onTap: onOpenHelplines,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String flaticonAsset;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.flaticonAsset,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  child: Center(
                    child: FlaticonView(
                      assetPath: flaticonAsset,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
