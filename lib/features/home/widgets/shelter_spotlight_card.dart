import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/shelter_model.dart';

/// Minimalist, high-hierarchy closest shelter card.
/// Bold remaining capacity count, verified amenity tags, honest Demo Data tag.
class ShelterSpotlightCard extends StatelessWidget {
  final ShelterModel? shelter;
  final bool isError;
  final VoidCallback onNavigate;
  final VoidCallback onViewAllShelters;

  const ShelterSpotlightCard({
    super.key,
    required this.shelter,
    this.isError = false,
    required this.onNavigate,
    required this.onViewAllShelters,
  });

  @override
  Widget build(BuildContext context) {
    if (shelter == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: isError ? AppColors.critical.withValues(alpha: 0.3) : AppColors.border,
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isError
                        ? AppColors.critical.withValues(alpha: 0.1)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FlaticonView(
                    assetPath: AppIcons.shelter,
                    size: 16,
                    color: isError ? AppColors.critical : AppColors.emeraldGreen,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  AppStrings.sectionShelterSpotlight,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isError)
              const Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: AppColors.critical),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shelter directory currently unavailable. Pull to retry.',
                      style: TextStyle(
                        color: AppColors.critical,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Locating closest safe shelter...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
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

    final s = shelter!;
    final occupancy = s.occupancyRate;
    final openSpots = s.availableSpots;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row with Status & Demo Badge
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const FlaticonView(
                  assetPath: AppIcons.shelter,
                  size: 16,
                  color: AppColors.emeraldGreen,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppStrings.sectionShelterSpotlight,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: const Text(
                  'DEMO DATA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Shelter Name & Address
          Text(
            s.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            s.address,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Inset Capacity & Distance Summary (Tesla Telemetry)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Distance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distance',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                s.distanceKm.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandBlueDeep,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'km',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandBlueDeep,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30, color: AppColors.border),
                    const SizedBox(width: 12),

                    // Available Capacity / Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Capacity Status',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          s.isVerified
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$openSpots',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.emeraldGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '/ ${s.totalCapacity}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Unverified',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warningOrange,
                                  ),
                                ),
                          if (!s.isVerified)
                            const Text(
                              'Live occupancy unknown (Demo)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (s.isVerified) ...[
                  const SizedBox(height: 8),
                  // Capacity Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    child: LinearProgressIndicator(
                      value: occupancy,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        occupancy > 0.85
                            ? AppColors.emergencyRed
                            : (occupancy > 0.60
                                ? AppColors.warningOrange
                                : AppColors.emeraldGreen),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Amenity Badges Row
          Row(
            children: [
              _AmenityPill(
                asset: AppIcons.water,
                label: 'Water',
                hasAmenity: s.hasWater,
              ),
              const SizedBox(width: 6),
              _AmenityPill(
                asset: AppIcons.medical,
                label: 'Medical',
                hasAmenity: s.hasMedical,
              ),
              const SizedBox(width: 6),
              _AmenityPill(
                asset: AppIcons.power,
                label: 'Power',
                hasAmenity: s.hasPower,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onNavigate,
                  child: const Text('View route'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewAllShelters,
                  child: const Text('All shelters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmenityPill extends StatelessWidget {
  final String asset;
  final String label;
  final bool hasAmenity;

  const _AmenityPill({
    required this.asset,
    required this.label,
    required this.hasAmenity,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: hasAmenity ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasAmenity ? AppColors.border : AppColors.border.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlaticonView(
              assetPath: asset,
              size: 12,
              color: hasAmenity ? AppColors.brandBlueDeep : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasAmenity ? AppColors.textPrimary : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
