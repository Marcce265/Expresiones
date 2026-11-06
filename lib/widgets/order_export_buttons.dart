import 'package:flutter/material.dart';

import '../models/checkout_order.dart';
import '../services/quote_export_service.dart';
import 'app_notice.dart';

class OrderExportButtons extends StatefulWidget {
  const OrderExportButtons({super.key, required this.order});

  final CheckoutOrder order;

  @override
  State<OrderExportButtons> createState() => _OrderExportButtonsState();
}

class _OrderExportButtonsState extends State<OrderExportButtons> {
  String? _exporting;

  Future<void> _exportPdf() async {
    if (_exporting != null) return;
    setState(() => _exporting = 'PDF');
    try {
      await QuoteExportService.saveOrderPdf(widget.order);
      if (mounted) showAppNotice(context, 'Comprobante PDF guardado.');
    } catch (_) {
      if (mounted) {
        showAppNotice(
          context,
          'No se pudo exportar PDF.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _exporting != null || widget.order.items.isEmpty;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: disabled ? null : _exportPdf,
        icon: _exporting == 'PDF'
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Guardar PDF'),
      ),
    );
  }
}
