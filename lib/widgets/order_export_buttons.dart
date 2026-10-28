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

  Future<void> _export(String format) async {
    if (_exporting != null) return;
    setState(() => _exporting = format);
    try {
      if (format == 'PDF') {
        await QuoteExportService.saveOrderPdf(widget.order);
      } else {
        await QuoteExportService.saveOrderXlsx(widget.order);
      }
      if (mounted) showAppNotice(context, 'Comprobante $format guardado.');
    } catch (_) {
      if (mounted) {
        showAppNotice(
          context,
          'No se pudo exportar $format.',
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
    final pdf = OutlinedButton.icon(
      onPressed: disabled ? null : () => _export('PDF'),
      icon: _exporting == 'PDF'
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: const Text('Guardar PDF'),
    );
    final excel = OutlinedButton.icon(
      onPressed: disabled ? null : () => _export('Excel'),
      icon: _exporting == 'Excel'
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.table_view_outlined),
      label: const Text('Guardar Excel'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 350) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: pdf),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: excel),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: pdf),
            const SizedBox(width: 10),
            Expanded(child: excel),
          ],
        );
      },
    );
  }
}
