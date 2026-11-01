import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _assistantAsset = 'assets/images/jashy_assistant.png';

const assistantGuideTitle = 'Hola, soy Jashy';
const assistantGuideMessage =
    'Te acompañaré para preparar tu cotización paso a paso. No necesitas crear una cuenta ni pagar dentro de la aplicación.';
const assistantGuideSteps = <AssistantGuideStep>[
  AssistantGuideStep(
    title: 'Encuentra un producto',
    message: 'Usa el buscador o entra al catálogo de materiales.',
    icon: Icons.search_rounded,
  ),
  AssistantGuideStep(
    title: 'Elige color y cantidad',
    message: 'Abre un producto, selecciona sus opciones y agrégalo al carrito.',
    icon: Icons.touch_app_outlined,
  ),
  AssistantGuideStep(
    title: 'Completa tus datos',
    message: 'Revisa el carrito y elige recojo en Huancayo o envío por Shalom.',
    icon: Icons.assignment_outlined,
  ),
  AssistantGuideStep(
    title: 'Envía tu cotización',
    message: 'Comprueba el resumen y envíalo por WhatsApp. Aquí no se realiza ningún cobro.',
    icon: Icons.chat_outlined,
  ),
];

enum AssistantGuideResult { dismissed, understood, doNotShowAgain }

class AssistantGuideStep {
  const AssistantGuideStep({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}

class AssistantGuideCard extends StatelessWidget {
  const AssistantGuideCard({
    super.key,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.onDismiss,
    this.compact = false,
  }) : assert(
         (primaryLabel == null) == (onPrimary == null),
         'primaryLabel y onPrimary deben usarse juntos.',
       );

  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: compact
            ? const EdgeInsets.fromLTRB(10, 8, 8, 9)
            : const EdgeInsets.fromLTRB(12, 10, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A191816),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AssistantPortrait(size: compact ? 56 : 82),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: compact
                          ? Theme.of(context).textTheme.labelLarge
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                    if (onPrimary != null) ...[
                      SizedBox(height: compact ? 7 : 10),
                      FilledButton.tonal(
                        onPressed: onPrimary,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(primaryLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Cerrar indicación',
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

class AssistantHelpButton extends StatelessWidget {
  const AssistantHelpButton({
    super.key,
    required this.onPressed,
    this.label = '¿Necesitas ayuda?',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return FloatingActionButton.small(
        heroTag: null,
        onPressed: onPressed,
        tooltip: label,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        child: const _AssistantPortrait(size: 32),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const _AssistantPortrait(size: 32),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
      ),
    );
  }
}

Future<AssistantGuideResult?> showAssistantGuideSheet({
  required BuildContext context,
  required String title,
  required String message,
  required List<AssistantGuideStep> steps,
  bool showDoNotShowAgain = false,
}) {
  final content = AssistantGuideSheet(
    title: title,
    message: message,
    steps: steps,
    showDoNotShowAgain: showDoNotShowAgain,
  );
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<AssistantGuideResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => content,
    );
  }
  return showDialog<AssistantGuideResult>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 570),
        child: content,
      ),
    ),
  );
}

class AssistantGuideSheet extends StatelessWidget {
  const AssistantGuideSheet({
    super.key,
    required this.title,
    required this.message,
    required this.steps,
    this.showDoNotShowAgain = false,
  });

  final String title;
  final String message;
  final List<AssistantGuideStep> steps;
  final bool showDoNotShowAgain;

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height * .86;
    final height = availableHeight > 700 ? 700.0 : availableHeight;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _AssistantPortrait(size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(
                          context,
                          AssistantGuideResult.dismissed,
                        ),
                        tooltip: 'Cerrar guía',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < steps.length; index++) ...[
                    _GuideStepTile(number: index + 1, step: steps[index]),
                    if (index != steps.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Row(
              children: [
                if (showDoNotShowAgain) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        AssistantGuideResult.doNotShowAgain,
                      ),
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('No volver a mostrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, AssistantGuideResult.understood),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({required this.number, required this.step});

  final int number;
  final AssistantGuideStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Paso $number: ${step.title}. ${step.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.pinkSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${step.title}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantPortrait extends StatelessWidget {
  const _AssistantPortrait({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Jashy, asistente de Expresiones',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.pinkSoft,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          _assistantAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.45),
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Icon(
            Icons.support_agent_rounded,
            color: AppColors.ink,
            size: size * .48,
          ),
        ),
      ),
    );
  }
}
