import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip widget for displaying user specialties
class SpecialtyChip extends StatelessWidget {
  final String specialty;
  final bool selected;
  final VoidCallback? onTap;

  const SpecialtyChip({
    super.key,
    required this.specialty,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: AppColors.primary)
              : Border.all(color: AppColors.surfaceLighter),
        ),
        child: Text(
          specialty,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.chipText,
          ),
        ),
      ),
    );
  }
}

/// List of specialty chips with optional selection
class SpecialtyChipList extends StatelessWidget {
  final List<String> specialties;
  final List<String>? selectedSpecialties;
  final Function(String)? onSpecialtyTap;
  final int maxDisplay;
  final bool wrap;

  const SpecialtyChipList({
    super.key,
    required this.specialties,
    this.selectedSpecialties,
    this.onSpecialtyTap,
    this.maxDisplay = 0,
    this.wrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final displaySpecialties = maxDisplay > 0 && specialties.length > maxDisplay
        ? specialties.take(maxDisplay).toList()
        : specialties;

    final chips = displaySpecialties.map((specialty) {
      return SpecialtyChip(
        specialty: specialty,
        selected: selectedSpecialties?.contains(specialty) ?? false,
        onTap: onSpecialtyTap != null ? () => onSpecialtyTap!(specialty) : null,
      );
    }).toList();

    if (maxDisplay > 0 && specialties.length > maxDisplay) {
      chips.add(
        SpecialtyChip(
          specialty: '+${specialties.length - maxDisplay}',
        ),
      );
    }

    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: chip,
          );
        }).toList(),
      ),
    );
  }
}
