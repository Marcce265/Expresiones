import 'package:flutter/material.dart';

Future<bool> confirmCancelAction(
  BuildContext context, {
  String title = '¿Cancelar los cambios?',
  String message =
      'Si sales ahora, se descartarán los cambios que no guardaste.',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Seguir aquí'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sí, cancelar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
