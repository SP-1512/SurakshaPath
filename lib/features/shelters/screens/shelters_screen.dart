import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/shelter_model.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/shelter_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../navigation/app_router.dart';

/// Module Screen: Shelter Management & Discovery Directory.
/// Apple & Tesla inspired: Clean search bar, interactive filter chips,
/// compact high-hierarchy listings, honest capacity breakdown, and detail bottom sheet.
class SheltersScreen extends StatefulWidget {
  const SheltersScreen({super.key});

  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  final IShelterService _shelterService = MockShelterService();
  List<ShelterModel> _allShelters = [];
  List<ShelterModel> _filteredShelters = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadShelters();
  }

  Future<void> _loadShelters() async {
    setState(() => _isLoading = true);
    final data = await _shelterService.getAvailableShelters();
    if (mounted) {
      setState(() {
        _allShelters = data;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<ShelterModel> result = _allShelters;

    if (_selectedFilter == 'Open Only') {
      result = result.where((s) => s.status == ShelterStatus.open).toList();
    } else if (_selectedFilter == 'With Medical') {
      result = result.where((s) => s.hasMedical).toList();
    } else if (_selectedFilter == 'Pets Allowed') {
      result = result.where((s) => s.hasPetsAllowed).toList();
    } else if (_selectedFilter == 'Accessible') {
      result = result.where((s) => s.isAccessible).toList();
    } else if (_selectedFilter == 'High Ground') {
      result = result.where((s) => (s.notes?.toLowerCase().contains('high ground') ?? false) || s.facilities.any((f) => f.toLowerCase().contains('high ground'))).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((s) =>
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.facilities.any((f) => f.toLowerCase().contains(_searchQuery.toLowerCase()))).toList();
    }

    setState(() {
      _filteredShelters = result;
    });
  }

  void _showShelterDetails(ShelterModel shelter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.space20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreenLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  child: const FlaticonView(
                    assetPath: AppIcons.shelter,
                    size: 20,
                    color: AppColors.emeraldGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shelter.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (!shelter.isVerified) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  border: Border.all(color: AppColors.warningOrange.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.warningOrange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Unverified sample record for demonstration. Capacity and facilities require authoritative on-ground confirmation.',
                        style: TextStyle(fontSize: 11, color: AppColors.ink, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              shelter.address,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Total Capacity:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                      Text(
                        shelter.isVerified ? '${shelter.capacityTotal} spots' : 'Unverified (Demo Record)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Current Occupancy:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                      Text(
                        shelter.isVerified ? '${shelter.capacityOccupied} occupied' : 'Live count not reported',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Available Spots:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                      Text(
                        shelter.isVerified ? '${shelter.availableSpots} remaining' : 'On-ground check required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: shelter.isVerified ? AppColors.emeraldGreen : AppColors.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              shelter.isVerified ? 'Verified Facilities:' : 'Reported Facilities (Unverified Demo):',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: shelter.facilities.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  f,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandBlueDeep),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Notes: ${shelter.notes}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  AppRouter.routing,
                  arguments: {
                    'shelterId': shelter.id,
                    'shelterName': shelter.name,
                  },
                );
              },
              child: const Text('Navigate to this shelter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppHeader(customTitle: AppStrings.navShelters),
          body: Column(
        children: [
          // 1. Search Bar & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                // Apple-style Search Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const FlaticonView(
                        assetPath: AppIcons.search,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            _searchQuery = val;
                            _applyFilters();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search by shelter name or area...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All (${_allShelters.length})', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Open Only', 'Open Only'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pets Allowed', 'Pets Allowed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Accessible', 'Accessible'),
                      const SizedBox(width: 8),
                      _buildFilterChip('With Medical', 'With Medical'),
                      const SizedBox(width: 8),
                      _buildFilterChip('High Ground', 'High Ground'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 2. Honest Sample Data Notice Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Demo data • Shelter occupancy and availability are simulated for demonstration.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 3. Shelters List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredShelters.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.space24),
                          child: Text(
                            'No relief shelters match the selected filter.',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.space16),
                        itemCount: _filteredShelters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space12),
                        itemBuilder: (context, index) {
                          final shelter = _filteredShelters[index];
                          return _ShelterListItem(
                            shelter: shelter,
                            onTapDetails: () => _showShelterDetails(shelter),
                          );
                        },
                      ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = filterKey;
          _applyFilters();
        });
      },
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

class _ShelterListItem extends StatelessWidget {
  final ShelterModel shelter;
  final VoidCallback onTapDetails;

  const _ShelterListItem({
    required this.shelter,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium), // 12px
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDetails,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title & Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shelter.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shelter.address,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: shelter.status.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                      child: Text(
                        shelter.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: shelter.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space12),

                // Capacity & Distance Summary Inset Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: shelter.isVerified
                            ? Row(
                                children: [
                                  Text(
                                    '${shelter.availableSpots}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emeraldGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'spots open (${shelter.capacityOccupied}/${shelter.capacityTotal})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Capacity: Unverified (Demo)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningOrange,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const FlaticonView(
                            assetPath: AppIcons.pin,
                            size: 11,
                            color: AppColors.brandBlueDeep,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${shelter.distanceKm} km',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandBlueDeep,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (shelter.isVerified) ...[
                  const SizedBox(height: 8),
                  // 4px Capacity Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    child: LinearProgressIndicator(
                      value: shelter.occupancyRate,
                      minHeight: 4,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(shelter.status.color),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space12),

                // Verified Amenity Badges (Wrap to prevent overflow on budget displays)
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (shelter.hasWater)
                            const _AmenityBadge(asset: AppIcons.water, label: 'Water'),
                          if (shelter.hasMedical)
                            const _AmenityBadge(asset: AppIcons.medical, label: 'Medical'),
                          if (shelter.hasPower)
                            const _AmenityBadge(asset: AppIcons.power, label: 'Generator'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Demo data',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space12),

                // Navigate CTA Button (Pill shape)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.routing,
                      arguments: {
                        'shelterId': shelter.id,
                        'shelterName': shelter.name,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlueDeep,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FlaticonView(
                        assetPath: AppIcons.evacuate,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Navigate to shelter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmenityBadge extends StatelessWidget {
  final String asset;
  final String label;

  const _AmenityBadge({required this.asset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlaticonView(assetPath: asset, size: 11, color: AppColors.brandBlueDeep),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
