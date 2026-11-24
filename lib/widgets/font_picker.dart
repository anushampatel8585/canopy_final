import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Premium font selector for CANOPY.
///
/// Each font is displayed using its actual typeface with a large live preview,
/// making the differences between font families immediately visible.
class FontPicker extends StatelessWidget {
  final AppFontFamily selectedFamily;
  final Color accentColor;
  final ValueChanged<AppFontFamily> onSelected;

  const FontPicker({
    super.key,
    required this.selectedFamily,
    required this.accentColor,
    required this.onSelected,
  });

  String _description(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.modernSans:
        return 'Geometric • polished • versatile';

      case AppFontFamily.cleanSans:
        return 'Geometric • contemporary • expressive';

      case AppFontFamily.rounded:
        return 'Tall • compact • high-impact';

      case AppFontFamily.elegant:
        return 'Elegant • expressive • artistic';

      case AppFontFamily.serif:
        return 'Classic • timeless • editorial';

      case AppFontFamily.mono:
        return 'Technical • structured • focused';

      case AppFontFamily.bold:
        return 'Strong • confident • energetic';

      case AppFontFamily.handwritten:
        return 'Personal • playful • creative';
    }
  }

  String _previewText(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.modernSans:
        return 'Build your rhythm';

      case AppFontFamily.cleanSans:
        return 'Space for progress';

      case AppFontFamily.rounded:
        return 'MAKE IT COUNT';

      case AppFontFamily.elegant:
        return 'A beautiful routine';

      case AppFontFamily.serif:
        return 'Progress takes time';

      case AppFontFamily.mono:
        return 'habit.execute()';

      case AppFontFamily.bold:
        return 'SHOW UP. EVERY DAY.';

      case AppFontFamily.handwritten:
        return 'one day at a time';
    }
  }

  IconData _icon(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.modernSans:
        return Icons.auto_awesome_outlined;

      case AppFontFamily.cleanSans:
        return Icons.blur_on_rounded;

      case AppFontFamily.rounded:
        return Icons.view_agenda_outlined;

      case AppFontFamily.elegant:
        return Icons.auto_awesome;

      case AppFontFamily.serif:
        return Icons.menu_book_outlined;

      case AppFontFamily.mono:
        return Icons.code_rounded;

      case AppFontFamily.bold:
        return Icons.flash_on_rounded;

      case AppFontFamily.handwritten:
        return Icons.edit_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AppFontFamily.values.map((family) {
        final selected = family == selectedFamily;
        final option = AppFonts.registry[family]!;

        final previewStyle = AppFonts.style(
          family,
          fontSize: _previewFontSize(family),
          color: selected
              ? accentColor
              : AppColors.textPrimary,
          fontWeight: _previewWeight(family),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => onSelected(family),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(
                16,
                15,
                14,
                16,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.10)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? accentColor
                      : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected
                              ? accentColor.withValues(
                                  alpha: 0.16,
                                )
                              : AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _icon(family),
                          size: 17,
                          color: selected
                              ? accentColor
                              : AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(width: 11),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: const TextStyle(
                                color:
                                    AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _description(family),
                              style: const TextStyle(
                                color:
                                    AppColors.textTertiary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      AnimatedSwitcher(
                        duration:
                            const Duration(milliseconds: 180),
                        child: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                key: const ValueKey(
                                  'selected',
                                ),
                                color: accentColor,
                                size: 21,
                              )
                            : const SizedBox(
                                key: ValueKey(
                                  'unselected',
                                ),
                                width: 21,
                                height: 21,
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withValues(
                              alpha: 0.045,
                            )
                          : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      _previewText(family),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  double _previewFontSize(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.elegant:
        return 25;

      case AppFontFamily.handwritten:
        return 27;

      case AppFontFamily.mono:
        return 18;

      case AppFontFamily.bold:
        return 19;

      case AppFontFamily.serif:
        return 22;

      case AppFontFamily.rounded:
        return 21;

      case AppFontFamily.cleanSans:
        return 20;

      case AppFontFamily.modernSans:
        return 20;
    }
  }

  FontWeight _previewWeight(AppFontFamily family) {
    switch (family) {
      case AppFontFamily.modernSans:
        return FontWeight.w500;

      case AppFontFamily.cleanSans:
        return FontWeight.w500;

      case AppFontFamily.rounded:
        return FontWeight.w500;

      case AppFontFamily.elegant:
        return FontWeight.w500;

      case AppFontFamily.serif:
        return FontWeight.w500;

      case AppFontFamily.mono:
        return FontWeight.w500;

      case AppFontFamily.bold:
        return FontWeight.w700;

      case AppFontFamily.handwritten:
        return FontWeight.w500;
    }
  }
}