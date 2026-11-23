import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_icons.dart';
import '../core/constants/app_strings.dart';
import '../core/services/locale_service.dart';
import '../core/services/location_service.dart';
import '../features/disaster/screens/disaster_alerts_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/map/screens/map_screen.dart';
import '../features/routing/screens/routing_screen.dart';
import '../features/shelters/screens/shelters_screen.dart';

/// 5-tab persistent bottom navigation bar strictly matching SurakshaPath UI Design (1).pdf (Page 1).
/// "5 tabs, 80 px bar, 24 px icons + 11 px labels. The path line above the active tab is the brand marker. SOS lives in the header, never in the tab bar."
/// Optimized with Lazy Tab Initialization and Lifecycle Management for budget Android devices.
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  late int _currentIndex;
  final Set<int> _activatedTabs = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _activatedTabs.add(_currentIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // Phase 5 battery optimization: pause background GPS & sensor polling
      MockLocationService().pauseTracking();
    } else if (state == AppLifecycleState.resumed) {
      // Phase 5: resume sensors when app returns to foreground
      MockLocationService().resumeTracking();
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _activatedTabs.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _activatedTabs.contains(0) ? const HomeScreen() : const SizedBox.shrink(),
              _activatedTabs.contains(1) ? const MapScreen() : const SizedBox.shrink(),
              _activatedTabs.contains(2) ? const RoutingScreen() : const SizedBox.shrink(),
              _activatedTabs.contains(3) ? const SheltersScreen() : const SizedBox.shrink(),
              _activatedTabs.contains(4) ? const DisasterAlertsScreen() : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1.0),
              ),
            ),
            child: SafeArea(
              top: false,
              maintainBottomViewPadding: true,
              child: SizedBox(
                height: 64.0, // Guaranteed interactive height above system insets
                child: Row(
                  children: [
                    _buildTabItem(0, AppStrings.navHome, AppIcons.home),
                    _buildTabItem(1, AppStrings.navMap, AppIcons.map),
                    _buildTabItem(2, AppStrings.navEvacuate, AppIcons.evacuate),
                    _buildTabItem(3, AppStrings.navShelters, AppIcons.shelter),
                    _buildTabItem(4, AppStrings.navAlerts, AppIcons.warning),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(int index, String label, String iconAsset) {
    final isSelected = index == _currentIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The brand path line above the active tab
            Container(
              height: 3.0,
              width: 32.0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2.0)),
              ),
            ),
            const SizedBox(height: 6.0),
            // 24 px icon as specified
            FlaticonView(
              assetPath: iconAsset,
              size: 24.0,
              color: isSelected ? AppColors.primaryBlue : AppColors.slate,
            ),
            const SizedBox(height: 4.0),
            // 11 px label with responsive truncation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primaryBlue : AppColors.slate,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 4.0),
          ],
        ),
      ),
    );
  }
}
