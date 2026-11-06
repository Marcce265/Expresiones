import 'package:flutter/material.dart';

import '../data/customer_account_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class AdminCustomerOrdersScreen extends StatefulWidget {
  const AdminCustomerOrdersScreen({super.key, required this.repository});

  final CustomerAccountRepository repository;

  @override
  State<AdminCustomerOrdersScreen> createState() =>
      _AdminCustomerOrdersScreenState();
}

class _AdminCustomerOrdersScreenState extends State<AdminCustomerOrdersScreen> {
  late Future<List<StoredCustomerOrder>> _orders = widget.repository
      .loadAllOrders();

  void _reload() {
    setState(() => _orders = widget.repository.loadAllOrders());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoredCustomerOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        return SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 1280,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('VENTAS DE DEMOSTRACIÓN'),
                          const SizedBox(height: 7),
                          Text(
                            'Compras registradas',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Pagos simulados completados por clientes registrados.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Actualizar compras',
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  _OrdersError(onRetry: _reload)
                else if ((snapshot.data ?? const []).isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Todavía no hay compras',
                    message: 'Cuando un cliente complete el pago simulado aparecerá aquí.',
                  )
                else
                  ...snapshot.data!.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminOrderCard(entry: entry),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.entry});

  final StoredCustomerOrder entry;

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final created = order.createdAt.toLocal();
    final date =
        '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} '
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.pinkSoft,
          child: Icon(Icons.shopping_bag_outlined),
        ),
        title: Text(
          '${entry.customerName} · S/ ${order.simulatedTotal.toStringAsFixed(2)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${order.id} · $date · ${entry.customerPhone}'),
        trailing: const Chip(label: Text('PAGO SIMULADO')),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          const Divider(),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.quantity} × ${item.displayName}'),
                  ),
                  Text('S/ ${item.lineTotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(order.details.deliveryLabel)),
              Text(order.payment.methodLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'No se pudieron cargar las compras',
      message: 'Revisa la conexión y vuelve a intentarlo.',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}
