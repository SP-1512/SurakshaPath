import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' hide Position, UserLocation;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/disaster_type.dart';
import '../../../core/models/shelter_model.dart';
import '../../../core/models/user_location.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../navigation/app_router.dart';
import '../../disaster/hazard_service.dart';
import '../location_service.dart';
import '../offline_map_service.dart';

/// Full-screen interactive emergency evacuation map.
/// Merges MapLibre Native vector map rendering with Phase 1.1 UI design,
/// OpenFreeMap legal attribution, hardware GPS tracking, and offline region management.
class MapScreen extends StatefulWidget {
  final bool useNativeMap;
  const MapScreen({super.key, this.useNativeMap = true});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final OfflineMapService _offlineMapService = OfflineMapService();

  MapController? _mapController;

  // ── Network Connectivity ───────────────────────────────────────────────────
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ── Shelters & Filtering ───────────────────────────────────────────────────
  List<ShelterModel> _shelters = [];
  List<HazardModel> _hazards = [];
  String _selectedFilter = 'All'; // All, Pets Allowed, Accessible, High Ground
  ShelterModel? _selectedShelter;

  // ── Location & GPS Tracking ────────────────────────────────────────────────
  bool _isLocating = false;

  // ── Offline Download Manager ───────────────────────────────────────────────
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';
  List<DownloadedRegionRecord> _downloadedRegions = [];

  // ── Native MapLibre Availability Flag ──────────────────────────────────────
  bool _mapLibreFailed = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadData();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ── 1. Connectivity Monitoring ─────────────────────────────────────────────
  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);

      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        _updateConnectionStatus(results);
      });
    } catch (e) {
      debugPrint('[MapScreen] Connectivity init error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasNet = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);

    if (mounted) {
      setState(() {
        _isOnline = hasNet;
      });
    }
  }

  // ── 2. Data Loading (Shelters & Saved Regions) ──────────────────────────────
  Future<void> _loadData() async {
    final bool pets = _selectedFilter == 'Pets Allowed';
    final bool access = _selectedFilter == 'Accessible';

    final shelters = await _offlineMapService.getSavedShelters(
      petsAllowed: pets ? true : null,
      accessible: access ? true : null,
    );
    final regions = await _offlineMapService.getDownloadedRegions();
    final hazards = await HazardService().getHazardsForDisaster(DisasterType.flood);

    if (mounted) {
      setState(() {
        _shelters = shelters;
        _hazards = hazards;
        _downloadedRegions = regions;
        if (_shelters.isNotEmpty && _selectedShelter == null) {
          _selectedShelter = _shelters.first;
        }
      });
    }
  }

  // ── 3. GPS Location Acquisition & Profile Synchronization ──────────────────
  Future<void> _acquireGpsLocation({bool centerOnMap = false}) async {
    final loc = UserProfileService.currentLocation;

    if (!loc.isLiveFix) {
      if (centerOnMap) {
        _centerMapOn(loc.latitude, loc.longitude, zoom: 13.0);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.provenance.label}: ${loc.locationName}'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.brandBlueDeep,
        ),
      );
      return;
    }

    if (_isLocating) return;

    setState(() => _isLocating = true);

    final result = await _locationService.acquireAndSyncWithProfile();

    if (!mounted) return;

    setState(() => _isLocating = false);

    if (result.isSuccess && result.position != null) {
      final p = result.position!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isLastKnownFallback
                ? 'Last Known GPS Position: (±${p.accuracy.toStringAsFixed(1)}m)'
                : 'Live GPS Acquired: (±${p.accuracy.toStringAsFixed(1)}m)',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.brandBlueDeep,
        ),
      );

      if (centerOnMap) {
        _centerMapOn(p.latitude, p.longitude, zoom: 14.0);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to acquire GPS fix.'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _centerMapOn(double lat, double lon, {double zoom = 13.0}) {
    if (_mapController != null) {
      try {
        _mapController!.moveCamera(
          CameraUpdate.position(
            center: Geographic(lon: lon, lat: lat),
            zoom: zoom,
          ),
        );
      } catch (e) {
        debugPrint('[MapScreen] Camera move error: $e');
      }
    }
  }

  // ── 4. Offline Region Download (Honest Native Execution) ────────────────────
  Future<void> _downloadRegion(OfflineRegionDefinitionItem item) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusText = 'Starting download for ${item.name}...';
    });

    try {
      final stream = _offlineMapService.downloadRegion(item);
      await for (final status in stream) {
        if (!mounted) break;

        setState(() {
          _downloadProgress = status.progress;
          _downloadStatusText = status.message;
        });

        if (status.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status.message),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
          break;
        }

        if (status.isCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${item.name} stored for offline use!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          await _loadData();
          break;
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  // ── UI Builder ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileService.profileNotifier,
          builder: (context, profile, _) {
            final userLoc = profile.location ?? UserProfileService.currentLocation;
            return Scaffold(
              appBar: AppHeader(customTitle: AppStrings.navMap),
              body: Stack(
                children: [
                  // 1. Vector Map Canvas (MapLibre Native with Graceful Fallback)
                  Positioned.fill(
                    child: _buildMapCanvas(userLoc),
                  ),

                  // 2. Top Connectivity & Provenance Status Banner
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: _buildTelemetryBar(userLoc),
                  ),

                  // 3. Top Floating Search & Filter Chips Bar
                  Positioned(
                    top: 60,
                    left: 12,
                    right: 12,
                    child: _buildSearchAndFilterRow(),
                  ),

                  // 4. Download Progress Card (Visible when downloading)
                  if (_isDownloading)
                    Positioned(
                      top: 130,
                      left: 16,
                      right: 16,
                      child: _buildDownloadProgressCard(),
                    ),

                  // 5. Map Legend Indicator
                  Positioned(
                    left: 16,
                    bottom: 180,
                    child: _buildLegendCard(),
                  ),

                  // 6. Floating Action Buttons (Recenter & Offline Manager)
                  Positioned(
                    right: 16,
                    bottom: 180,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'map_offline_mgr_fab',
                          tooltip: 'Offline Map Manager',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandBlueDeep,
                          onPressed: () => _showDownloadBottomSheet(context),
                          child: const Icon(Icons.cloud_download_outlined),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton(
                          heroTag: 'recenter_gps_fab',
                          tooltip: 'Center on My GPS Location',
                          backgroundColor: AppColors.brandBlueDeep,
                          foregroundColor: Colors.white,
                          onPressed: () => _acquireGpsLocation(centerOnMap: true),
                          child: _isLocating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),

                  // 7. Bottom Attribution Pill
                  Positioned(
                    bottom: 4,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => _showAttributionDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: const Text(
                          'OpenFreeMap © OpenStreetMap contributors',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                        ),
                      ),
                    ),
                  ),

                  // 8. Bottom Peek Shelter Card (PlayStation & Tesla Inset Panel)
                  if (_selectedShelter != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: _buildShelterCard(_selectedShelter!),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Sub-components ─────────────────────────────────────────────────────────

  Widget _buildMapCanvas(UserLocation userLoc) {
    final bool isTestMode = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (kIsWeb || !widget.useNativeMap || isTestMode || _mapLibreFailed) {
      return CustomPaint(
        painter: _MapCanvasPainter(
          showHazards: true,
          showCorridors: true,
        ),
      );
    }

    try {
      return MapLibreMap(
        options: MapOptions(
          style: const MapStyle.url(OfflineMapService.openFreeMapStyleUrl),
          initCamera: CameraUpdate.position(
            center: Geographic(
              lon: userLoc.longitude,
              lat: userLoc.latitude,
            ),
            zoom: 12.0,
          ),
          minZoom: 4.0,
          maxZoom: 18.0,
        ),
        layers: [
          // User location circle
          CircleLayer(
            points: [
              Feature(
                geometry: Point(
                  Geographic(lon: userLoc.longitude, lat: userLoc.latitude),
                ),
              ),
            ],
            color: Literal(
              userLoc.isLiveFix
                  ? const Color(0xFF10B981) // Emerald for live GPS
                  : const Color(0xFF1E88E5), // Blue for manual/demo
            ),
            radius: const Literal(10.0),
          ),

          // Shelter markers
          CircleLayer(
            points: _shelters
                .map((s) => Feature(
                      geometry: Point(
                        Geographic(lon: s.longitude, lat: s.latitude),
                      ),
                      properties: {'id': s.id, 'name': s.name},
                    ))
                .toList(),
            color: const Literal(Color(0xFFE53935)),
            radius: const Literal(8.0),
          ),

          // Active hazard zone circles
          CircleLayer(
            points: _hazards
                .map((h) => Feature(
                      geometry: Point(
                        Geographic(lon: h.longitude, lat: h.latitude),
                      ),
                      properties: {'id': h.id, 'title': h.title},
                    ))
                .toList(),
            color: const Literal(Color(0x55EF4444)),
            radius: const Literal(16.0),
          ),
        ],
        onMapCreated: (controller) {
          _mapController = controller;
        },
      );
    } catch (e) {
      debugPrint('[MapScreen] MapLibre creation error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _mapLibreFailed = true);
      });
      return CustomPaint(
        painter: _MapCanvasPainter(
          showHazards: true,
          showCorridors: true,
        ),
      );
    }
  }

  Widget _buildTelemetryBar(UserLocation userLoc) {
    final Color provColor = userLoc.isLiveFix
        ? AppColors.emeraldGreen
        : (userLoc.provenance == LocationProvenance.manualSelection
            ? AppColors.brandBlueDeep
            : AppColors.slate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Connectivity Dot & Label
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online (OpenFreeMap)' : 'Offline (Storage)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),

          // Location Provenance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: provColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              border: Border.all(color: provColor, width: 0.8),
            ),
            child: Text(
              userLoc.isLiveFix
                  ? 'LIVE GPS${userLoc.accuracyMeters != null ? " ±${userLoc.accuracyMeters!.toStringAsFixed(0)}m" : ""}'
                  : userLoc.provenance.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: provColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Offline Manager Icon
          InkWell(
            onTap: () => _showDownloadBottomSheet(context),
            child: const Icon(
              Icons.cloud_download_outlined,
              size: 18,
              color: AppColors.brandBlueDeep,
            ),
          ),
          const SizedBox(width: 6),

          // Attribution Info Icon
          InkWell(
            onTap: () => _showAttributionDialog(context),
            child: const Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Row(
            children: [
              FlaticonView(
                assetPath: AppIcons.search,
                size: 16,
                color: AppColors.brandBlueDeep,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search Coastal AP shelters & relief camps...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All'),
              const SizedBox(width: 6),
              _buildFilterChip('Pets Allowed'),
              const SizedBox(width: 6),
              _buildFilterChip('Accessible'),
              const SizedBox(width: 6),
              _buildFilterChip('High Ground'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = label);
        _loadData();
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandBlueDeep : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.brandBlueDeep : AppColors.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgressCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.tealAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _downloadStatusText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: AppColors.emeraldGreen, label: 'Designated Shelter'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.warningOrange, label: 'Hazard Zone'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.brandBlueBright, label: 'Evac Corridor'),
        ],
      ),
    );
  }

  Widget _buildShelterCard(ShelterModel shelter) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                  size: 22,
                  color: AppColors.emeraldGreen,
                ),
              ),
              const SizedBox(width: 12),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shelter.distanceKm} km away • Unverified Capacity (Demo)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
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
                  icon: const FlaticonView(
                    assetPath: AppIcons.evacuate,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'View route',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlueDeep,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheets & Dialogs ────────────────────────────────────────────────

  void _showDownloadBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfflineDownloadSheet(
        predefinedRegions: OfflineMapService.predefinedRegions,
        downloadedRegions: _downloadedRegions,
        isDownloading: _isDownloading,
        onDownload: (region) {
          Navigator.pop(ctx);
          _downloadRegion(region);
        },
        onDelete: (id) async {
          await _offlineMapService.deleteRegion(id);
          _loadData();
        },
      ),
    );
  }

  void _showAttributionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Map & Legal Attribution'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vector Tiles & Styling:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'OpenFreeMap Liberty Style\n© OpenMapTiles | © OpenStreetMap contributors',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Disaster Preparedness Data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Coastal Andhra Pradesh disaster emergency corridors and shelter datasets are simulation demo records.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Offline Download Modal Sheet ─────────────────────────────────────────────

class _OfflineDownloadSheet extends StatelessWidget {
  final List<OfflineRegionDefinitionItem> predefinedRegions;
  final List<DownloadedRegionRecord> downloadedRegions;
  final bool isDownloading;
  final ValueChanged<OfflineRegionDefinitionItem> onDownload;
  final ValueChanged<String> onDelete;

  const _OfflineDownloadSheet({
    required this.predefinedRegions,
    required this.downloadedRegions,
    required this.isDownloading,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Offline Map Regions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Text(
            'Download Coastal AP sector packages for offline navigation. OpenFreeMap quota: Max 3,000 tiles per region.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Available Coastal AP Sectors:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...predefinedRegions.map((region) {
            final isAlready = downloadedRegions.any((d) => d.id == region.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                title: Text(
                  region.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  '${region.description} • ~${region.estimatedTiles} tiles (${region.estimatedSizeMb} MB)',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isAlready
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: isDownloading ? null : () => onDownload(region),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBlueDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Download'),
                      ),
              ),
            );
          }),
          if (downloadedRegions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Stored Offline Regions:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...downloadedRegions.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined, color: Colors.teal),
                title: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('Downloaded: ${r.downloadedAt.toLocal().toString().split(".")[0]} • ${r.tileCount} tiles'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => onDelete(r.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Legend Item Helper ───────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Fallback Map Canvas Painter (Resilience & Automated Test Safety) ──────────

class _MapCanvasPainter extends CustomPainter {
  final bool showHazards;
  final bool showCorridors;

  _MapCanvasPainter({required this.showHazards, required this.showCorridors});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) => false;
}
