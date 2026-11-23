import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Explicit, honest label indicating demonstration, simulated, or sample data.
class DemoBadge extends StatelessWidget {
  final String label;
  final bool dark;

  const DemoBadge({
    super.key,
    this.label = 'DEMO SCENARIO',
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.3) : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: dark ? Colors.white : AppColors.slate,
        ),
      ),
    );
  }
}
