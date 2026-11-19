import 'package:flutter/material.dart';

import '../models/storefront_settings.dart';
import '../screens/privacy_screen.dart';
import '../theme/app_theme.dart';

/// Bloque obligatorio con dos casillas independientes y desmarcadas por defecto
/// (Términos y Condiciones + Política de Privacidad), conforme a la Ley N° 29733
/// y su Reglamento D.S. N° 016-2024-JUS (Perú).
class LegalConsentCheckboxes extends StatelessWidget {
  const LegalConsentCheckboxes({
    super.key,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    this.showError = false,
    this.settings = const StorefrontSettings(),
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final bool showError;
  final StorefrontSettings settings;

  @override
  Widget build(BuildContext context) {
    final hasError = showError && (!termsAccepted || !privacyAccepted);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? AppColors.error : AppColors.border,
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConsentRow(
            checkboxKey: const ValueKey('consent_terms_checkbox'),
            value: termsAccepted,
            onChanged: onTermsChanged,
            label: 'He leído y acepto los Términos y Condiciones *',
            linkText: 'Leer Términos y Condiciones',
            onOpenDocument: () => showLegalDocumentDialog(
              context,
              initialSection: LegalDocumentSection.terms,
              settings: settings,
            ),
          ),
          const Divider(height: 14, color: AppColors.border),
          _ConsentRow(
            checkboxKey: const ValueKey('consent_privacy_checkbox'),
            value: privacyAccepted,
            onChanged: onPrivacyChanged,
            label:
                'He leído y acepto la Política de Privacidad (Ley N° 29733) *',
            linkText: 'Leer Política de Privacidad',
            onOpenDocument: () => showLegalDocumentDialog(
              context,
              initialSection: LegalDocumentSection.privacy,
              settings: settings,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 8),
            Text(
              'Marca ambas casillas por separado (Términos y Condiciones y Política de Privacidad) para continuar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.checkboxKey,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.linkText,
    required this.onOpenDocument,
  });

  final Key checkboxKey;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String linkText;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            key: checkboxKey,
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => onChanged(!value),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onOpenDocument,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      linkText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.pinkStrong,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
