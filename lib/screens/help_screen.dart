import 'package:flutter/material.dart';

import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    required this.onContact,
    required this.onPrivacy,
    required this.onAdminLogin,
    this.settings = const StorefrontSettings(),
  });

  final VoidCallback onContact;
  final VoidCallback onPrivacy;
  final VoidCallback onAdminLogin;
  final StorefrontSettings settings;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String body})>[
      (
        icon: Icons.receipt_long_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(1)),
        body: settings.text(StorefrontText.helpFaqBody(1)),
      ),
      (
        icon: Icons.inventory_2_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(2)),
        body: settings.text(StorefrontText.helpFaqBody(2)),
      ),
      (
        icon: Icons.storefront_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(3)),
        body: settings.text(StorefrontText.helpFaqBody(3)),
      ),
      (
        icon: Icons.local_shipping_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(4)),
        body: settings.text(StorefrontText.helpFaqBody(4)),
      ),
      (
        icon: Icons.event_available_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(5)),
        body: settings.text(StorefrontText.helpFaqBody(5)),
      ),
      (
        icon: Icons.payments_outlined,
        title: settings.text(StorefrontText.helpFaqTitle(6)),
        body: settings.text(StorefrontText.helpFaqBody(6)),
      ),
    ];

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1040,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(settings.text(StorefrontText.helpEyebrow)),
            const SizedBox(height: 8),
            Text(
              settings.text(StorefrontText.helpTitle),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              settings.text(StorefrontText.helpBody),
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            InfoBanner(
              title: settings.text(StorefrontText.helpBannerTitle),
              message: settings.text(StorefrontText.helpBannerBody),
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [for (final item in items) _FaqCard(item: item)],
                  );
                }
                final left = <({IconData icon, String title, String body})>[];
                final right = <({IconData icon, String title, String body})>[];
                for (var index = 0; index < items.length; index++) {
                  (index.isEven ? left : right).add(items[index]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in left) _FaqCard(item: item),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in right) _FaqCard(item: item),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => _HelpActions(
                horizontal: constraints.maxWidth >= 620,
                onPrivacy: onPrivacy,
                onContact: onContact,
                onAdminLogin: onAdminLogin,
                privacyLabel: settings.text(StorefrontText.helpPrivacyButton),
                contactLabel: settings.text(StorefrontText.helpContactButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final ({IconData icon, String title, String body}) item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pinkSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 21),
          ),
          title: Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(item.body)),
          ],
        ),
      ),
    );
  }
}

class _HelpActions extends StatelessWidget {
  const _HelpActions({
    required this.horizontal,
    required this.onPrivacy,
    required this.onContact,
    required this.onAdminLogin,
    required this.privacyLabel,
    required this.contactLabel,
  });

  final bool horizontal;
  final VoidCallback onPrivacy;
  final VoidCallback onContact;
  final VoidCallback onAdminLogin;
  final String privacyLabel;
  final String contactLabel;

  @override
  Widget build(BuildContext context) {
    final privacy = OutlinedButton.icon(
      onPressed: onPrivacy,
      icon: const Icon(Icons.privacy_tip_outlined),
      label: Text(privacyLabel),
    );
    final contact = FilledButton.icon(
      onPressed: onContact,
      style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
      icon: const Icon(Icons.chat_outlined),
      label: Text(contactLabel),
    );
    final primaryActions = horizontal
        ? Row(
            children: [
              Expanded(child: privacy),
              const SizedBox(width: 12),
              Expanded(child: contact),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [privacy, const SizedBox(height: 10), contact],
          );

    return Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        primaryActions,
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Acceso exclusivo para la administración de Expresiones',
          child: TextButton.icon(
            key: const ValueKey('admin-login-button'),
            onPressed: onAdminLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Iniciar sesión administrativa'),
          ),
        ),
      ],
    );
  }
}
