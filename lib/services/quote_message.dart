import 'package:intl/intl.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';

abstract final class QuoteMessageBuilder {
  static String quoteId(DateTime now) {
    final date = DateFormat('yyMMdd').format(now);
    final code = ((now.millisecondsSinceEpoch ~/ 1000) % 65536)
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return 'COT-$date-$code';
  }

  static String build({
    required String id,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
  }) {
    final buffer = StringBuffer()
      ..writeln('Hola, Expresiones. Quisiera solicitar esta cotización:')
      ..writeln()
      ..writeln(id)
      ..writeln();

    for (final item in lines) {
      final code = item.code == null ? '' : ' · ${item.code}';
      buffer
        ..writeln('• ${item.line.quantity} × ${item.displayName}$code')
        ..writeln(
          '  ${item.priceTierLabel}: S/ ${item.total.toStringAsFixed(2)}',
        );
      if (item.line.customization.trim().isNotEmpty) {
        buffer.writeln('  Detalle: ${item.line.customization.trim()}');
      }
      buffer.writeln();
    }

    final subtotal = lines.fold<double>(0, (sum, item) => sum + item.total);
    buffer
      ..writeln('Subtotal referencial: S/ ${subtotal.toStringAsFixed(2)}')
      ..writeln('Envío: por confirmar')
      ..writeln()
      ..writeln('Nombre: ${details.name.trim()}')
      ..writeln('Teléfono: ${details.phone.trim()}')
      ..writeln('Entrega: ${details.deliveryLabel}');

    if (details.desiredDate != null) {
      buffer.writeln(
        'Fecha deseada: ${DateFormat('dd/MM/yyyy').format(details.desiredDate!)}',
      );
    } else {
      buffer.writeln('Fecha deseada: por coordinar');
    }
    if (details.note.trim().isNotEmpty) {
      buffer.writeln('Nota: ${details.note.trim()}');
    }

    buffer
      ..writeln()
      ..write(
        'Entiendo que stock, precio final y fecha serán confirmados por WhatsApp.',
      );
    return buffer.toString();
  }
}
