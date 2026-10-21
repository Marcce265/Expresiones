import 'package:flutter/material.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../services/quote_export_service.dart';

/// Reusable export actions for the review screen and future admin views.
class QuoteExportButtons extends StatefulWidget {
  const QuoteExportButtons({
    super.key,
    required this.quoteId,
    required this.lines,
    required this.details,
  });

  final String quoteId;
  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;

  @override
  State<QuoteExportButtons> createState() => _QuoteExportButtonsState();
}

class _QuoteExportButtonsState extends State<QuoteExportButtons> {
  String? _exporting;

  Future<void> _export(String format) async {
    if (_exporting != null) return;
    setState(() => _exporting = format);
    try {
      if (format == 'PDF') {
        await QuoteExportService.savePdf(
          quoteId: widget.quoteId,
          lines: widget.lines,
          details: widget.details,
        );
      } else {
        await QuoteExportService.saveXlsx(
          quoteId: widget.quoteId,
          lines: widget.lines,
          details: widget.details,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cotización $format guardada.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar $format: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _exporting != null || widget.lines.isEmpty;
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
