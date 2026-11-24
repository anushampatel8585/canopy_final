import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Grid of the curated CANOPY habit palette. Selected swatch gets a ring
/// and checkmark; everything else stays understated.
class ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  const ColorPicker({super.key, required this.selectedColor, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: AppColors.habitPalette.map((option) {
        final selected = option.color.value == selectedColor.value;
        return GestureDetector(
          onTap: () => onSelected(option.color),
          child: Tooltip(
            message: option.name,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: option.color.withOpacity(0.45), blurRadius: 10)]
                    : [],
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 18)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}