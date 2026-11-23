import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/disaster_alert.dart';
import '../../../core/models/disaster_type.dart';
import '../../../core/models/shelter_model.dart';
import '../../../core/models/user_location.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/shelter_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/profile_sheet.dart';
import '../../../navigation/app_router.dart';
import '../widgets/alert_card.dart';
import '../widgets/disaster_selector.dart';
import '../widgets/emergency_sos_card.dart';
import '../widgets/location_card.dart';
import '../widgets/preparedness_card.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/shelter_spotlight_card.dart';
import '../widgets/situation_hero_card.dart';

/// Refined Home Screen strictly matching 10_Home.png and 11_Home_Telugu.png.
class HomeScreen extends StatefulWidget {
  final ILocationService? locationService;
  final IAlertService? alertService;
  final IShelterService? shelterService;

  const HomeScreen({
    super.key,
    this.locationService,
    this.alertService,
    this.shelterService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ILocationService _locationService;
  late final IAlertService _alertService;
  late final IShelterService _shelterService;

  UserLocation _location = UserProfileService.currentLocation;
  List<DisasterAlert> _alerts = [];
  ShelterModel? _closestShelter;
  DisasterType _selectedDisaster = DisasterType.flood;

  bool _isLoadingLocation = false;
  bool _isLoadingData = true;

  bool _locationError = false;
  bool _alertsError = false;
  bool _shelterError = false;

  @override
  void initState() {
    super.initState();
    _location = UserProfileService.currentLocation;
    UserProfileService.profileNotifier.addListener(_onProfileUpdated);
    _locationService = widget.locationService ?? MockLocationService();
    _alertService = widget.alertService ?? MockAlertService();
    _shelterService = widget.shelterService ?? MockShelterService();
    _loadDashboardData();
  }

  void _onProfileUpdated() {
    if (mounted) {
      setState(() {
        _location = UserProfileService.currentLocation;
      });
    }
  }

  @override
  void dispose() {
    UserProfileService.profileNotifier.removeListener(_onProfileUpdated);
    super.dispose();
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    setState(() => _isLoadingData = true);

    // Failure isolation: each service is loaded in parallel, but an error
    // in one loader does not abort or prevent other sections from updating.
    final locationFuture = widget.locationService != null
        ? _locationService.getCurrentLocation().then((loc) {
            if (mounted) {
              setState(() {
                _location = loc;
                _locationError = false;
              });
            }
          }).catchError((_) {
            if (mounted) {
              setState(() {
                _locationError = true;
              });
            }
          })
        : Future.value(null);

    await Future.wait([
      // 1. Location Loader (only if injected mock service is passed)
      locationFuture,

      // 2. Alerts Loader
      _alertService.getActiveAlerts(forceRefresh: forceRefresh).then((alerts) {
        if (mounted) {
          setState(() {
            _alerts = alerts;
            _alertsError = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _alertsError = true;
          });
        }
      }),

      // 3. Shelters Loader
      _shelterService.getClosestSafeShelter().then((shelter) {
        if (mounted) {
          setState(() {
            _closestShelter = shelter;
            _shelterError = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _closestShelter = null;
            _shelterError = true;
          });
        }
      }),
    ]);

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final loc = widget.locationService != null
          ? await _locationService.getCurrentLocation()
          : (_location.isLiveFix
              ? await DeviceLocationService().getCurrentLocation()
              : UserProfileService.currentLocation);

      if (mounted) {
        setState(() {
          _location = loc;
          _locationError = false;
          _isLoadingLocation = false;
        });
        final messenger = ScaffoldMessenger.of(context);
        await UserProfileService.updateLocation(loc);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                loc.isLiveFix
                    ? 'Live GPS Fix: ${loc.locationName} (±${loc.accuracyMeters!.toStringAsFixed(1)}m)'
                    : '${loc.provenance.label}: ${loc.locationName}',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _location.isLiveFix
                  ? 'GPS satellite lock failed. Retaining last fix: ${_location.locationName}'
                  : 'Location: ${_location.locationName} (${_location.provenance.label})',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
    }
  }

  Future<void> _onDisasterFilterChanged(DisasterType type) async {
    setState(() {
      _selectedDisaster = type;
    });
    final filtered = await _alertService.getAlertsByDisaster(type);
    if (mounted) {
      setState(() {
        _alerts = filtered;
      });
    }
  }

  void _showOfflinePackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demonstration Mode Notice', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Offline map tiles and live routing caches are simulated in this prototype. For real emergencies, rely on official broadcast channels and direct helpline numbers (112 / 108).',
          style: TextStyle(fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: const AppHeader(),
          body: RefreshIndicator(
            onRefresh: () => _loadDashboardData(forceRefresh: true),
            color: AppColors.primaryBlue,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // 1. Location Bar
                LocationCard(
                  location: _location,
                  isLoading: _isLoadingLocation,
                  isError: _locationError,
                  onRefresh: _refreshLocation,
                  onTap: () => ProfileSheet.show(context),
                ),
                const SizedBox(height: 14),

                // 2. Dark Navy Situation Hero Card (Prakasam Barrage Alert + Start Plan CTA)
                SituationHeroCard(
                  onStartEvacuation: () {
                    Navigator.pushNamed(context, AppRouter.routing);
                  },
                ),
                const SizedBox(height: 14),

                // 3. Tactile Emergency SOS Hold-to-Activate Ring
                EmergencySosCard(
                  onTriggerSos: () {
                    Navigator.pushNamed(context, AppRouter.sos);
                  },
                ),
                const SizedBox(height: 14),

                // 4. Nearest Shelter Spotlight Card
                ShelterSpotlightCard(
                  shelter: _closestShelter,
                  isError: _shelterError,
                  onNavigate: () {
                    if (_closestShelter != null) {
                      Navigator.pushNamed(
                        context,
                        AppRouter.routing,
                        arguments: {
                          'shelterId': _closestShelter!.id,
                          'shelterName': _closestShelter!.name,
                        },
                      );
                    }
                  },
                  onViewAllShelters: () {
                    Navigator.pushNamed(context, AppRouter.shelters);
                  },
                ),
                const SizedBox(height: 14),

                // 5. Preparedness Progress Card (3 of 5 complete)
                const PreparednessCard(),
                const SizedBox(height: 14),

                // 6. Disaster Context Chips (Flood, Cyclone, etc.)
                DisasterSelector(
                  selectedType: _selectedDisaster,
                  onTypeSelected: _onDisasterFilterChanged,
                ),
                const SizedBox(height: 16),

                // 7. Quick Action Navigation Matrix
                QuickActionGrid(
                  onOpenMap: () => Navigator.pushNamed(context, AppRouter.map),
                  onOpenShelters: () => Navigator.pushNamed(context, AppRouter.shelters),
                  onOpenAlerts: () => Navigator.pushNamed(context, AppRouter.alerts),
                  onOpenHelplines: _showOfflinePackDialog,
                ),
                const SizedBox(height: 20),

                // 7. Active Alerts Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.activeAlertsTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${_alerts.length} Active',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoadingData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.space24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_alertsError && _alerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(color: AppColors.critical.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.critical),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unable to load emergency alerts. Pull to retry.',
                            style: TextStyle(
                              color: AppColors.critical,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_alerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      AppStrings.allClear,
                      style: const TextStyle(color: AppColors.slate, fontSize: 13),
                    ),
                  )
                else
                  ..._alerts.take(2).map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AlertCard(alert: alert),
                        ),
                      ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
