import 'package:flutter/material.dart';

import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.onBack,
    required this.onClearLocalData,
    this.onAdminLogin,
    this.settings = const StorefrontSettings(),
  });

  final VoidCallback onBack;
  final Future<void> Function() onClearLocalData;
  final VoidCallback? onAdminLogin;
  final StorefrontSettings settings;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _clearing = false;

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar datos de este dispositivo'),
        content: const Text(
          'Se eliminarán el carrito, los datos de coordinación, el último '
          'comprobante de demostración y los eventos anónimos que todavía no '
          'se hayan enviado. Esta acción no puede deshacerse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    await widget.onClearLocalData();
    if (!mounted) return;
    setState(() => _clearing = false);
    showAppNotice(context, 'Los datos locales fueron eliminados.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.settings.text(StorefrontText.privacyTitle),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.settings.text(StorefrontText.privacySubtitle),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.settings.text(StorefrontText.privacyUpdatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                for (var index = 1; index <= 8; index++)
                  _PrivacySection(
                    title: widget.settings.text(
                      StorefrontText.privacySectionTitle(index),
                    ),
                    body: widget.settings.text(
                      StorefrontText.privacySectionBody(index),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.pinkSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.settings.text(
                          StorefrontText.privacyControlTitle,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.settings.text(StorefrontText.privacyControlBody),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _clearing ? null : _clear,
                        icon: _clearing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        label: Text(
                          widget.settings.text(
                            StorefrontText.privacyClearButton,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (widget.onAdminLogin != null)
                  Center(
                    child: TextButton(
                      onPressed: widget.onAdminLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Iniciar sesión administrativa'),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
