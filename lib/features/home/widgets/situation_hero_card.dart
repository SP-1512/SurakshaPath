import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../navigation/app_router.dart';

/// Dark Navy Hero Situation Card strictly matching 10_Home.png & 11_Home_Telugu.png.
class SituationHeroCard extends StatelessWidget {
  final VoidCallback? onStartEvacuation;

  const SituationHeroCard({
    super.key,
    this.onStartEvacuation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep navy dark surface
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Warning pill + Demo chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.high.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.high.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FlaticonView(
                        assetPath: AppIcons.flood,
                        size: 13,
                        color: AppColors.high,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          AppStrings.highRisk.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.high,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: DemoBadge(label: AppStrings.demoScenario, dark: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Headline
          Text(
            AppStrings.heroAlertTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle / Advisory text
          Text(
            AppStrings.heroAlertDesc,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Emerald "Start evacuation plan" CTA button
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: AppDimensions.buttonHeight,
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                elevation: 0,
              ),
              onPressed: onStartEvacuation ??
                  () {
                    Navigator.pushNamed(context, AppRouter.routing);
                  },
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(
                AppStrings.startEvacuationPlan,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
