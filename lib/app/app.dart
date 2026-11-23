import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/services/locale_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../navigation/app_router.dart';

/// Root Application Widget for SurakshaPath.
/// On desktop & web viewports, centers the app within an authentic mobile smartphone canvas.
class SurakshaPathApp extends StatelessWidget {
  const SurakshaPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, localeCode, _) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: Locale(localeCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale != null) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == locale.languageCode) {
                  return supported;
                }
              }
            }
            return const Locale('en');
          },
          initialRoute: AppRouter.root,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isDesktop = screenWidth > 480;

            if (!isDesktop) {
              return child ?? const SizedBox.shrink();
            }

            return Container(
              color: const Color(0xFF0B132B), // Deep navy desktop background
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430, maxHeight: 920),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF334155), width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 40,
                        spreadRadius: 2,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
