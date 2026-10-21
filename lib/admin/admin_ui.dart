import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminSectionIntro extends StatelessWidget {
  const AdminSectionIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.15, color: AppColors.muted),
        ),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted, height: 1.45),
        ),
      ],
    );
  }
}
