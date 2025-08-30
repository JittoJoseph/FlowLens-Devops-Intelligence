import 'package:flutter/material.dart';
import '../config/premium_theme.dart';
import '../models/pull_request.dart';

class StatusFilterChips extends StatelessWidget {
  final PRStatus? selectedStatus;
  final Function(PRStatus?) onStatusChanged;
  final Map<PRStatus, int> statusCounts;

  const StatusFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.statusCounts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            isSelected: selectedStatus == null,
            count: statusCounts.values.fold(0, (sum, count) => sum + count),
            color: AppTheme.primaryColor,
            onTap: () => onStatusChanged(null),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Pending',
            isSelected: selectedStatus == PRStatus.pending,
            count: statusCounts[PRStatus.pending] ?? 0,
            color: AppTheme.warningColor,
            onTap: () => onStatusChanged(PRStatus.pending),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Building',
            isSelected: selectedStatus == PRStatus.building,
            count: statusCounts[PRStatus.building] ?? 0,
            color: AppTheme.primaryColor,
            onTap: () => onStatusChanged(PRStatus.building),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Build Passed',
            isSelected: selectedStatus == PRStatus.buildPassed,
            count: statusCounts[PRStatus.buildPassed] ?? 0,
            color: AppTheme.successColor,
            onTap: () => onStatusChanged(PRStatus.buildPassed),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Build Failed',
            isSelected: selectedStatus == PRStatus.buildFailed,
            count: statusCounts[PRStatus.buildFailed] ?? 0,
            color: AppTheme.errorColor,
            onTap: () => onStatusChanged(PRStatus.buildFailed),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Approved',
            isSelected: selectedStatus == PRStatus.approved,
            count: statusCounts[PRStatus.approved] ?? 0,
            color: AppTheme.successColor,
            onTap: () => onStatusChanged(PRStatus.approved),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Merged',
            isSelected: selectedStatus == PRStatus.merged,
            count: statusCounts[PRStatus.merged] ?? 0,
            color: AppTheme.successColor.withValues(alpha: 0.8),
            onTap: () => onStatusChanged(PRStatus.merged),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Closed',
            isSelected: selectedStatus == PRStatus.closed,
            count: statusCounts[PRStatus.closed] ?? 0,
            color: AppTheme.textSecondaryColor,
            onTap: () => onStatusChanged(PRStatus.closed),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.3)
                : AppTheme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.premiumBodyStyle.copyWith(
                color: isSelected ? color : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : AppTheme.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count.toString(),
                  style: AppTheme.premiumBodyStyle.copyWith(
                    color: isSelected ? color : AppTheme.textSecondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
