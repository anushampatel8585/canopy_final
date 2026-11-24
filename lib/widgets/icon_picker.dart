import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/icon_registry.dart';

/// Searchable, categorized icon grid. Selection state and data both come
/// from the parent so this stays a simple, reusable picker.
class IconPicker extends StatefulWidget {
  final String? selectedKey;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  const IconPicker({
    super.key,
    required this.selectedKey,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = <String, List<IconOption>>{};
    IconRegistry.categories.forEach((category, options) {
      final matches = _query.isEmpty
          ? options
          : options
              .where((o) => o.label.toLowerCase().contains(_query.toLowerCase()))
              .toList();
      if (matches.isNotEmpty) filtered[category] = matches;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search icons...',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No icons found', style: TextStyle(color: AppColors.textTertiary)),
            ),
          )
        else
          ...filtered.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: entry.value.map((option) {
                      final selected = option.key == widget.selectedKey;
                      return GestureDetector(
                        onTap: () => widget.onSelected(option.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? widget.accentColor.withOpacity(0.18)
                                : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? widget.accentColor : AppColors.border,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Icon(
                            option.icon,
                            color: selected ? widget.accentColor : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}