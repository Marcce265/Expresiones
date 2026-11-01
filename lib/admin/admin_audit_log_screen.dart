import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'admin_operations_repository.dart';
import 'admin_ui.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key, required this.repository});

  final AdminOperationsRepository repository;

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  late Future<List<AdminAuditLog>> _logs;

  @override
  void initState() {
    super.initState();
    _logs = widget.repository.loadAuditLogs();
  }

  Future<void> _refresh() async {
    final next = widget.repository.loadAuditLogs();
    setState(() => _logs = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminAuditLog>>(
      future: _logs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AuditMessage(
            icon: Icons.error_outline_rounded,
            title: 'No se pudo leer el historial',
            message: '${snapshot.error}',
            onRefresh: _refresh,
          );
        }
        final logs = snapshot.data ?? const <AdminAuditLog>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ResponsivePage(
                maxWidth: 1180,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const intro = AdminSectionIntro(
                          eyebrow: 'Seguridad y control',
                          title: 'Historial administrativo',
                          description: 'Revisa los últimos cambios realizados en el catálogo y la configuración de la tienda.',
                        );
                        final button = OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Actualizar'),
                        );
                        if (constraints.maxWidth < 620) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              intro,
                              const SizedBox(height: 14),
                              button,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(child: intro),
                            const SizedBox(width: 16),
                            button,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.pinkSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Se muestran como máximo 100 acciones recientes. El historial es de solo lectura.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (logs.isEmpty)
                      const _AuditEmpty()
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < logs.length;
                              index++
                            ) ...[
                              _AuditLogTile(log: logs[index]),
                              if (index != logs.length - 1) const Divider(),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final sections = log.changedSections
        .map((section) => _sectionLabels[section] ?? section)
        .toList(growable: false);
    final label = log.resourceLabel.trim().isEmpty
        ? _resourceLabels[log.resourceType] ?? 'Configuración'
        : log.resourceLabel.trim();
    final actor = log.actorEmail.trim().isEmpty
        ? 'Administrador'
        : log.actorEmail.trim();
    final action = _actionLabels[log.action] ?? 'Actualizó';
    final icon = switch (log.action) {
      'create' => Icons.add_rounded,
      'delete' => Icons.delete_outline_rounded,
      _ => Icons.edit_outlined,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.pinkSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$action $label',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '$actor · ${DateFormat('dd/MM/yyyy · HH:mm').format(log.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (sections.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final section in sections)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(section),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditEmpty extends StatelessWidget {
  const _AuditEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 38),
            const SizedBox(height: 12),
            Text(
              'Aún no hay acciones registradas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Los próximos cambios del administrador aparecerán aquí.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditMessage extends StatelessWidget {
  const _AuditMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

const _actionLabels = {
  'create': 'Creó',
  'update': 'Actualizó',
  'delete': 'Eliminó',
};

const _resourceLabels = {
  'catalog_product': 'Producto del catálogo',
  'site_settings': 'Contenido de la tienda',
  'availability': 'Fechas de entrega',
};

const _sectionLabels = {
  'details': 'Datos del producto',
  'prices': 'Precios',
  'inventory': 'Disponibilidad',
  'image': 'Imagen',
  'visibility': 'Publicación',
  'production': 'Preparación',
  'variants_or_prices': 'Variantes o precios',
  'content': 'Portada y textos',
  'contact': 'Contacto',
  'pickup_location': 'Ubicación',
  'checkout_fields': 'Formulario',
  'delivery_days': 'Días de entrega',
  'capacity': 'Capacidad',
  'booking_window': 'Calendario',
  'exceptions': 'Excepciones',
};
