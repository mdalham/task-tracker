// lib/widgets/filter_chip_row.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/todo/db/todo_model.dart';
import '../../service/todo/provider/todo_provider.dart';

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: 'All',
                count: provider.totalCount,
                isSelected: provider.currentFilter == TodoFilter.all,
                onTap: () => provider.setFilter(TodoFilter.all),
              ),
              _buildFilterChip(
                context,
                label: 'Active',
                count: provider.activeCount,
                isSelected: provider.currentFilter == TodoFilter.active,
                onTap: () => provider.setFilter(TodoFilter.active),
              ),
              _buildFilterChip(
                context,
                label: 'Completed',
                count: provider.completedCount,
                isSelected: provider.currentFilter == TodoFilter.completed,
                onTap: () => provider.setFilter(TodoFilter.completed),
              ),
              _buildFilterChip(
                context,
                label: 'Today',
                count: provider.dueTodayCount,
                isSelected: provider.currentFilter == TodoFilter.today,
                onTap: () => provider.setFilter(TodoFilter.today),
              ),
              _buildFilterChip(
                context,
                label: 'Overdue',
                count: provider.overdueCount,
                isSelected: provider.currentFilter == TodoFilter.overdue,
                onTap: () => provider.setFilter(TodoFilter.overdue),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      BuildContext context, {
        required String label,
        required int count,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)',style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: isSelected ? colorScheme.primary : colorScheme.onPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        )),

        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),),
        side: BorderSide(color: colorScheme.outline,),
      ),
    );
  }
}