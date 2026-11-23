import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeSeverity { critical, high, moderate, low, positive, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeSeverity severity;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.severity = BadgeSeverity.neutral,
    this.icon,
  });

  Color get _backgroundColor {
    switch (severity) {
      case BadgeSeverity.critical:
        return AppColors.critical.withValues(alpha: 0.12);
      case BadgeSeverity.high:
        return AppColors.high.withValues(alpha: 0.12);
      case BadgeSeverity.moderate:
        return AppColors.moderate.withValues(alpha: 0.12);
      case BadgeSeverity.low:
      case BadgeSeverity.info:
        return AppColors.secondaryBlue.withValues(alpha: 0.12);
      case BadgeSeverity.positive:
        return AppColors.emerald.withValues(alpha: 0.12);
      case BadgeSeverity.neutral:
        return AppColors.slate.withValues(alpha: 0.12);
    }
  }

  Color get _textColor {
    switch (severity) {
      case BadgeSeverity.critical:
        return AppColors.critical;
      case BadgeSeverity.high:
        return AppColors.high;
      case BadgeSeverity.moderate:
        return AppColors.moderate;
      case BadgeSeverity.low:
      case BadgeSeverity.info:
        return AppColors.secondaryBlue;
      case BadgeSeverity.positive:
        return AppColors.emerald;
      case BadgeSeverity.neutral:
        return AppColors.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _textColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textColor,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
