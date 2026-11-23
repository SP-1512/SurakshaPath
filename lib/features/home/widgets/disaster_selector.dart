import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/disaster_type.dart';

/// Horizontal pill selector for disaster context matching 10_Home.png & 11_Home_Telugu.png.
class DisasterSelector extends StatelessWidget {
  final DisasterType selectedType;
  final ValueChanged<DisasterType> onTypeSelected;

  const DisasterSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  static const List<DisasterType> _types = [
    DisasterType.flood,
    DisasterType.cyclone,
    DisasterType.earthquake,
    DisasterType.fire,
    DisasterType.all,
  ];

  String _getLocalizedName(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return AppStrings.flood;
      case DisasterType.cyclone:
        return AppStrings.cyclone;
      case DisasterType.earthquake:
        return AppStrings.earthquake;
      case DisasterType.fire:
        return AppStrings.fire;
      case DisasterType.all:
      default:
        return 'All Hazards';
    }
  }

  Widget _buildTypeIcon(DisasterType type, bool isSelected) {
    if (type == DisasterType.cyclone) {
      return FlaticonView(
        assetPath: AppIcons.cyclone,
        size: 14,
        color: isSelected ? Colors.white : AppColors.primaryBlue,
      );
    } else if (type == DisasterType.flood) {
      return FlaticonView(
        assetPath: AppIcons.flood,
        size: 14,
        color: isSelected ? Colors.white : AppColors.primaryBlue,
      );
    }
    return Icon(
      type.iconData,
      size: 14,
      color: isSelected ? Colors.white : AppColors.primaryBlue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.sectionDisasterFilter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = _types[index];
              final isSelected = type == selectedType;

              return ChoiceChip(
                avatar: _buildTypeIcon(type, isSelected),
                label: Text(_getLocalizedName(type)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    onTypeSelected(type);
                  }
                },
                selectedColor: AppColors.primaryBlue,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.ink,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryBlue : AppColors.border,
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
