import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';

/// Preparedness Progress & Go-Bag Checklist Card matching 10_Home.png & 11_Home_Telugu.png.
class PreparednessCard extends StatefulWidget {
  const PreparednessCard({super.key});

  @override
  State<PreparednessCard> createState() => _PreparednessCardState();
}

class _PreparednessCardState extends State<PreparednessCard> {
  final List<bool> _completed = [true, true, true, false, false];

  int get _completedCount => _completed.where((c) => c).length;
  double get _progress => _completedCount / _completed.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppStrings.preparednessTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_completedCount of ${_completed.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: 14),

          // Checklist items
          _buildCheckItem(0, AppStrings.checklistItem1),
          _buildCheckItem(1, AppStrings.checklistItem2),
          _buildCheckItem(2, AppStrings.checklistItem3),
          _buildCheckItem(3, AppStrings.checklistItem4),
          _buildCheckItem(4, AppStrings.checklistItem5),
        ],
      ),
    );
  }

  Widget _buildCheckItem(int index, String label) {
    final done = _completed[index];
    return InkWell(
      onTap: () {
        setState(() {
          _completed[index] = !_completed[index];
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: done ? AppColors.emerald : AppColors.slate,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                  color: done ? AppColors.ink : AppColors.slate,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.slate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
