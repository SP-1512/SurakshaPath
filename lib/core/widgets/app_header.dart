import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../services/locale_service.dart';
import 'language_bottom_sheet.dart';
import 'profile_sheet.dart';

/// Unified persistent App Header matching SurakshaPath UI Design (1).pdf (Page 1 & 2).
/// "Logo on left, Red SOS pill + Language button on right. SOS lives in the header, never in the tab bar."
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final String? customTitle;

  const AppHeader({
    super.key,
    this.showBackButton = false,
    this.customTitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.currentLocale,
      builder: (context, locale, _) {
        return Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 8,
            left: 12,
            right: 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.ink),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 8),
              ],
              // Logo & Title
              Expanded(
                child: customTitle != null
                    ? Text(
                        customTitle!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo_color.png',
                              width: 30,
                              height: 30,
                              cacheWidth: 90,
                              cacheHeight: 90,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => const FlaticonView(
                                assetPath: AppIcons.shield,
                                size: 26,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryBlue,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 6),

              // Language Switcher Pill
              InkWell(
                onTap: () => LanguageBottomSheet.show(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34, maxHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, size: 15, color: AppColors.slate),
                      const SizedBox(width: 3),
                      Text(
                        locale == 'te' ? 'తె' : 'EN',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Red SOS Pill Button
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/sos'),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34, maxHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.critical,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.critical.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FlaticonView(
                        assetPath: AppIcons.sos,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.navSos,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Circular Profile Avatar Button (matches Page 2 of approved design)
              InkWell(
                onTap: () => ProfileSheet.show(context),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
