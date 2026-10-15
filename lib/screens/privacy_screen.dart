import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.onBack,
    required this.onClearLocalData,
  });

  final VoidCallback onBack;
  final Future<void> Function() onClearLocalData;

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
          'Se eliminarán la cotización, los datos de coordinación y los eventos '
          'anónimos que todavía no se hayan enviado. Esta acción no puede deshacerse.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Los datos locales fueron eliminados.')),
    );
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
                        'Privacidad',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Política de privacidad de Expresiones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Última actualización: 15 de octubre de 2026',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const _PrivacySection(
                  title: 'Datos guardados en tu dispositivo',
                  body:
                      'La cotización, el nombre, el teléfono, la forma de entrega, '
                      'la agencia elegida, la fecha y la nota se guardan localmente '
                      'para que puedas continuar después. Expresiones no recibe esos '
                      'datos mientras permanecen guardados localmente.',
                ),
                const _PrivacySection(
                  title: 'Envío por WhatsApp',
                  body:
                      'Cuando eliges enviar la cotización, la aplicación prepara el '
                      'mensaje y abre WhatsApp. Tú decides si finalmente lo envías. '
                      'Desde ese momento, el tratamiento del mensaje también se rige '
                      'por las condiciones y la política de WhatsApp.',
                ),
                const _PrivacySection(
                  title: 'Catálogo y capacidad',
                  body:
                      'Cloud Firestore se utiliza para descargar productos, precios, '
                      'stock y disponibilidad agregada. Los nombres, teléfonos, notas '
                      'y cotizaciones no se guardan en el catálogo de Firestore.',
                ),
                const _PrivacySection(
                  title: 'Medición anónima',
                  body:
                      'Cuando la medición comercial está habilitada, se registran '
                      'búsquedas sin resultado, identificadores técnicos de productos '
                      'vistos o agregados y rangos de importe. También se registra si '
                      'se abrió WhatsApp para enviarla o si quedó '
                      'inactiva. Estos eventos no '
                      'incluyen nombre, teléfono, dirección, nota, personalización ni '
                      'un identificador del cliente.',
                ),
                const _PrivacySection(
                  title: 'Archivos exportados',
                  body:
                      'Los archivos PDF y Excel se generan en el dispositivo. Quedan '
                      'bajo tu control en la carpeta de descargas y no se suben a un '
                      'servidor de Expresiones.',
                ),
                const _PrivacySection(
                  title: 'Directorio de Shalom',
                  body:
                      'La lista de agencias es una copia local del directorio público '
                      'de Shalom. Seleccionar una agencia no realiza una reserva ni '
                      'comparte automáticamente tus datos con Shalom.',
                ),
                const _PrivacySection(
                  title: 'Conservación y contacto',
                  body:
                      'Los datos locales permanecen hasta que se borren desde esta '
                      'pantalla, se limpien los datos de la aplicación o se desinstale. '
                      'Para consultas sobre privacidad puedes comunicarte con '
                      'Expresiones al WhatsApp +51 956 744 914.',
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
                        'Control de tus datos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Puedes borrar ahora la información almacenada por Expresiones '
                        'en este dispositivo.',
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
                        label: const Text('Borrar mis datos locales'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
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
