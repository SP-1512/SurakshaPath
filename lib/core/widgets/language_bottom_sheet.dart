import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../services/locale_service.dart';

/// Language selection sheet supporting 11 Indic languages.
/// Designed for emergency clarity and tested for narrow 320dp screens.
class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LanguageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = LocaleService.currentLocale.value;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose Language / భాషను ఎంచుకోండి',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.slate, size: 22),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '11 regional languages supported. Active languages ready for emergency use.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            // Scrollable Language List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: LocaleService.supportedLanguages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final lang = LocaleService.supportedLanguages[index];
                  final isSelected = current == lang.code;
                  return _buildLanguageCard(context, lang, isSelected);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    AppLanguage lang,
    bool isSelected,
  ) {
    final isAvailable = lang.isAvailable;

    return InkWell(
      onTap: isAvailable
          ? () {
              LocaleService.setLocale(lang.code);
              Navigator.pop(context);
            }
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${lang.englishName} translation in progress. Using approved English guidance.',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.65,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.05)
                : (isAvailable ? Colors.white : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBlue
                  : (isAvailable ? AppColors.border : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Language details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lang.nativeName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lang.code != 'en') ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '(${lang.englishName})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.sampleSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(height: 5),
                      _buildStatusBadge(lang.statusLabel),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Selection indicator
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                )
              else if (isAvailable)
                const Icon(
                  Icons.radio_button_unchecked,
                  color: AppColors.border,
                  size: 22,
                )
              else
                const Icon(
                  Icons.pending_outlined,
                  color: AppColors.slate,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber 100
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF59E0B), width: 0.6), // Amber 500
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF92400E), // Amber 800
        ),
      ),
    );
  }
}
