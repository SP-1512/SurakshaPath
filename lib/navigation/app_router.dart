import 'package:flutter/material.dart';
import '../core/services/user_profile_service.dart';
import '../features/disaster/screens/disaster_alerts_screen.dart';
import '../features/emergency/screens/emergency_sos_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/map/screens/map_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/routing/screens/routing_screen.dart';
import '../features/shelters/screens/shelters_screen.dart';
import 'main_navigation_shell.dart';

/// Centralized route definitions for SurakshaPath.
class AppRouter {
  AppRouter._();

  static const String root = '/';
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String map = '/map';
  static const String shelters = '/shelters';
  static const String alerts = '/alerts';
  static const String sos = '/sos';
  static const String routing = '/routing';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
      case root:
        return MaterialPageRoute(
          builder: (_) => UserProfileService.isOnboardingCompleted
              ? const MainNavigationShell()
              : const SplashScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case map:
        return MaterialPageRoute(
          builder: (_) => const MapScreen(),
          settings: settings,
        );
      case shelters:
        return MaterialPageRoute(
          builder: (_) => const SheltersScreen(),
          settings: settings,
        );
      case alerts:
        return MaterialPageRoute(
          builder: (_) => const DisasterAlertsScreen(),
          settings: settings,
        );
      case sos:
        return MaterialPageRoute(
          builder: (_) => const EmergencySosScreen(),
          settings: settings,
        );
      case routing:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => RoutingScreen(
            shelterId: args?['shelterId'] as String?,
            shelterName: args?['shelterName'] as String?,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings: settings,
        );
    }
  }
}
