import 'package:flutter/material.dart';

import '../models/commerce_telemetry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'admin_operations_repository.dart';
import 'admin_ui.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key, required this.repository});

  final AdminOperationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad del catálogo'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: .8),
        ),
      ),
      body: StreamBuilder<AdminAnalyticsSummary>(
        stream: repository.watchAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AnalyticsMessage(
              title: 'No se pudieron leer las métricas',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _AnalyticsBody(summary: snapshot.data!);
        },
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.summary});

  final AdminAnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final days = summary.requestedWindow.inDays;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          maxWidth: 1280,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminSectionIntro(
                eyebrow: 'Comportamiento de clientes',
                title: 'Actividad del catálogo',
                description: 'Descubre qué materiales interesan más, qué buscan los clientes y cuántas cotizaciones llegan a WhatsApp.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.pinkSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Resumen anónimo de los últimos $days días. Se muestran hasta '
                  '${summary.sampleLimit} eventos recientes; no se guardan nombres, '
                  'teléfonos, direcciones ni textos de personalización.',
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 620
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  final metrics = [
                    _AnalyticsMetric(
                      label: 'Vistas de productos',
                      value: '${summary.count(CommerceEventType.productView)}',
                      icon: Icons.visibility_outlined,
                    ),
                    _AnalyticsMetric(
                      label: 'Productos agregados',
                      value: '${summary.count(CommerceEventType.productAdded)}',
                      icon: Icons.add_shopping_cart_outlined,
                    ),
                    _AnalyticsMetric(
                      label: 'Aperturas de WhatsApp',
                      value: '${summary.count(CommerceEventType.quoteSent)}',
                      icon: Icons.send_outlined,
                    ),
                    _AnalyticsMetric(
                      label: 'Cotizaciones abandonadas',
                      value:
                          '${summary.count(CommerceEventType.quoteAbandoned)}',
                      icon: Icons.remove_shopping_cart_outlined,
                    ),
                    _AnalyticsMetric(
                      label: 'Búsquedas sin resultado',
                      value:
                          '${summary.count(CommerceEventType.zeroResultSearch)}',
                      icon: Icons.search_off_rounded,
                    ),
                    _AnalyticsMetric(
                      label: 'Paso a WhatsApp estimado',
                      value:
                          '${(summary.quoteCompletionRate * 100).toStringAsFixed(1)}%',
                      icon: Icons.insights_outlined,
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: width, child: metric),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980
                      ? 3
                      : constraints.maxWidth >= 640
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 16) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: width,
                        child: _RankingCard(
                          title: 'Productos más vistos',
                          emptyMessage: 'Todavía no hay vistas registradas.',
                          rows: summary.topViewedProducts,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _RankingCard(
                          title: 'Productos más agregados',
                          emptyMessage: 'Todavía no hay agregados registrados.',
                          rows: summary.topAddedProducts,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _RankingCard(
                          title: 'Productos que buscan y faltan',
                          emptyMessage: 'No hay búsquedas sin resultado.',
                          rows: summary.topMissingSearches,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                '${summary.totalEvents} eventos válidos incluidos en este resumen.',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.emptyMessage,
    required this.rows,
  });

  final String title;
  final String emptyMessage;
  final List<AnalyticsRank> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(emptyMessage),
              )
            else
              for (var index = 0; index < rows.length; index++) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${index + 1}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: SelectableText(rows[index].label, maxLines: 2),
                    ),
                    const SizedBox(width: 8),
                    Chip(label: Text('${rows[index].count}')),
                  ],
                ),
                if (index != rows.length - 1) const Divider(),
              ],
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.query_stats_outlined, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
