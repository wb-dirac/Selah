import 'package:flutter/material.dart';

/// Compact left/right arrow widget for switching between regeneration branches.
///
/// Displays "‹ 2/3 ›" style indicator. Hidden when [totalBranches] ≤ 1.
class BranchSwitcher extends StatelessWidget {
  const BranchSwitcher({
    super.key,
    required this.currentIndex,
    required this.totalBranches,
    required this.onPrevious,
    required this.onNext,
  });

  /// Zero-based index of the currently displayed branch.
  final int currentIndex;

  /// Total number of branches (siblings) for this parent message.
  final int totalBranches;

  /// Called when user taps the left arrow.
  final VoidCallback? onPrevious;

  /// Called when user taps the right arrow.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (totalBranches <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final labelColor = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left,
          onPressed: currentIndex > 0 ? onPrevious : null,
        ),
        Text(
          '${currentIndex + 1}/$totalBranches',
          style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
        ),
        _ArrowButton(
          icon: Icons.chevron_right,
          onPressed: currentIndex < totalBranches - 1 ? onNext : null,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(
          icon,
          color: onPressed != null
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
