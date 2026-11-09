import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminSectionIntro extends StatelessWidget {
  const AdminSectionIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description = '',
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.15, color: AppColors.muted),
        ),
        SizedBox(height: compact ? 4 : 7),
        Text(
          title,
          style: compact
              ? theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.headlineMedium,
        ),
        if (description.trim().isNotEmpty) ...[
          SizedBox(height: compact ? 4 : 7),
          Text(
            description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted, height: 1.45),
          ),
        ],
      ],
    );
  }
}
