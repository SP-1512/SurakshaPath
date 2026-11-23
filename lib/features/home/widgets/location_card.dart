import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_location.dart';

/// Minimalist location header row strictly matching 10_Home.png & 11_Home_Telugu.png.
class LocationCard extends StatelessWidget {
  final UserLocation location;
  final bool isLoading;
  final bool isError;
  final VoidCallback onRefresh;
  final VoidCallback? onTap;

  const LocationCard({
    super.key,
    required this.location,
    required this.isLoading,
    this.isError = false,
    required this.onRefresh,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Center(
                child: FlaticonView(
                  assetPath: AppIcons.pin,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppStrings.sectionLocation,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    isError
                        ? 'Location Unavailable'
                        : (location.locationName.isNotEmpty
                            ? location.locationName
                            : AppStrings.currentCity),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isError ? AppColors.critical : AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isError
                        ? 'GPS fix failed • Tap refresh icon to retry'
                        : '${location.subArea.isNotEmpty ? location.subArea : AppStrings.currentDistrict}${location.accuracyMeters != null ? " • ±${location.accuracyMeters!.toStringAsFixed(1)}m" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isError ? AppColors.critical : AppColors.slate,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: location.provenance == LocationProvenance.liveGps
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : (location.provenance == LocationProvenance.manualSelection
                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                        : AppColors.slate.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(
                  color: location.provenance == LocationProvenance.liveGps
                      ? AppColors.emerald.withValues(alpha: 0.4)
                      : (location.provenance == LocationProvenance.manualSelection
                          ? AppColors.primaryBlue.withValues(alpha: 0.4)
                          : AppColors.border),
                  width: 1.0,
                ),
              ),
              child: Text(
                location.provenance.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: location.provenance == LocationProvenance.liveGps
                      ? AppColors.emerald
                      : (location.provenance == LocationProvenance.manualSelection
                          ? AppColors.primaryBlue
                          : AppColors.slate),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.slate),
              onPressed: isLoading ? null : onRefresh,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
