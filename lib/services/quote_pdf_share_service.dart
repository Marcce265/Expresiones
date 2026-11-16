import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import 'quote_export_service.dart';

enum QuotePdfShareOutcome { shared, dismissed, downloadedOrUnavailable }

abstract final class QuotePdfShareService {
  static Future<QuotePdfShareOutcome> share({
    required String quoteId,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await QuoteExportService.buildPdf(
      quoteId: quoteId,
      lines: lines,
      details: details,
    );
    final fileName = 'cotizacion_${_safeFilePart(quoteId)}.pdf';
    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Cotización $quoteId',
        subject: 'Cotización $quoteId · Expresiones',
        text: 'Cotización $quoteId preparada en Expresiones.',
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
        downloadFallbackEnabled: true,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => QuotePdfShareOutcome.shared,
      ShareResultStatus.dismissed => QuotePdfShareOutcome.dismissed,
      ShareResultStatus.unavailable =>
        QuotePdfShareOutcome.downloadedOrUnavailable,
    };
  }

  static String _safeFilePart(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}
