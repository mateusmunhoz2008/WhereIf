import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'package:autth_injustice_app/events/presentation/l10n/event_category_l10n.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';

class EventCategorySelector extends StatelessWidget {
  final EventCategory? selectedCategory;
  final ValueChanged<EventCategory> onSelected;

  const EventCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: responsive.scaled(10, min: 2, max: 12),
        runSpacing: responsive.scaled(10, min: 2, max: 13),
        children: [
          for (final category in context.institution.events.categories)
            _CategoryPill(
              category: category,
              selected: category == selectedCategory,
              onTap: () => onSelected(category),
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final EventCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final foreground = selected
        ? context.onSecondary
        : context.onTertiary.withValues(alpha: 0.76);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          splashColor: context.secondary.withValues(alpha: 0.16),
          highlightColor: context.secondary.withValues(alpha: 0.07),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scaled(14, min: 11, max: 15),
              vertical: responsive.scaled(9.5, min: 8, max: 10),
            ),
            decoration: BoxDecoration(
              color: selected
                  ? context.secondary
                  : context.onTertiary.withValues(
                      alpha: context.isDarkMode ? 0.075 : 0.045,
                    ),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected
                    ? context.secondary
                    : context.onTertiary.withValues(alpha: 0.13),
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.secondary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    selected ? Icons.check_rounded : _iconForCategory(category),
                    key: ValueKey(selected),
                    size: responsive.scaled(14.5, min: 13, max: 15),
                    color: foreground,
                  ),
                ),
                SizedBox(width: responsive.scaled(7, min: 5, max: 8)),
                Flexible(
                  child: Text(
                    category.localizedLabel(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: foreground,
                      fontSize:
                          (context.text.labelLarge?.fontSize ?? 14) * 0.85,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(EventCategory category) {
    return switch (category.iconKey) {
      'academic' => Icons.school_outlined,
      'arts' => Icons.palette_outlined,
      'science' => Icons.science_outlined,
      'technology' => Icons.memory_outlined,
      'sports' => Icons.sports_basketball_outlined,
      'health' => Icons.favorite_border_rounded,
      'environment' => Icons.eco_outlined,
      'extension' => Icons.hub_outlined,
      'community' => Icons.groups_outlined,
      'institutional' => Icons.account_balance_outlined,
      'careers' => Icons.work_outline_rounded,
      _ => Icons.more_horiz_rounded,
    };
  }
}
