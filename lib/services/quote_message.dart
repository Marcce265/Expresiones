import 'package:intl/intl.dart';

import '../models/checkout_order.dart';
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
    String brandName = 'Expresiones',
  }) {
    final safeBrandName = brandName.trim().isEmpty
        ? 'Expresiones'
        : brandName.trim();
    final buffer = StringBuffer()
      ..writeln('Hola, $safeBrandName. Quisiera solicitar esta cotización:')
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
      ..writeln('Subtotal de productos: S/ ${subtotal.toStringAsFixed(2)}')
      ..writeln('Envío: por confirmar')
      ..writeln()
      ..writeln('Nombre: ${details.name.trim()}')
      ..writeln('Teléfono: ${details.phone.trim()}')
      ..writeln('Entrega: ${details.deliveryLabel}');

    if (details.deliveryMethod == DeliveryMethod.shalom &&
        details.shalomAgencyId.isNotEmpty) {
      buffer
        ..writeln('Agencia Shalom: ${details.shalomAgencyName}')
        ..writeln('Ubicación: ${details.shalomAgencyLocality}')
        ..writeln('Dirección: ${details.shalomAgencyAddress}');
      if (details.shalomAgencyLatitude != null &&
          details.shalomAgencyLongitude != null) {
        buffer.writeln(
          'Mapa: https://www.google.com/maps/search/?api=1&query=${details.shalomAgencyLatitude},${details.shalomAgencyLongitude}',
        );
      }
    }

    if (details.desiredDate != null) {
      buffer.writeln(
        'Fecha deseada: ${DateFormat('dd/MM/yyyy').format(details.desiredDate!)}',
      );
    } else {
      buffer.writeln('Fecha deseada: por coordinar');
    }
    for (final entry in details.customFields.entries) {
      if (entry.value.trim().isNotEmpty) {
        buffer.writeln('${entry.key}: ${entry.value.trim()}');
      }
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

  static String buildOrder({
    required CheckoutOrder order,
    String brandName = 'Expresiones',
  }) {
    final details = order.details;
    final safeBrandName = brandName.trim().isEmpty
        ? 'Expresiones'
        : brandName.trim();
    final buffer = StringBuffer()
      ..writeln('Hola, $safeBrandName. Quisiera coordinar este pedido:')
      ..writeln()
      ..writeln(order.id)
      ..writeln();

    for (final item in order.items) {
      final code = item.sku == null ? '' : ' · ${item.sku}';
      buffer
        ..writeln('• ${item.quantity} × ${item.displayName}$code')
        ..writeln('  S/ ${item.lineTotal.toStringAsFixed(2)}');
      if (item.customization.isNotEmpty) {
        buffer.writeln('  Detalle: ${item.customization}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln(
        'Subtotal de productos: S/ ${order.productsSubtotal.toStringAsFixed(2)}',
      )
      ..writeln(
        'Envío: ${order.shippingPending ? 'por confirmar' : 'sin costo adicional'}',
      )
      ..writeln()
      ..writeln('Nombre: ${details.name.trim()}')
      ..writeln('Teléfono: ${details.phone.trim()}')
      ..writeln('Entrega: ${details.deliveryLabel}');

    if (details.deliveryMethod == DeliveryMethod.shalom &&
        details.shalomAgencyId.isNotEmpty) {
      buffer
        ..writeln('Agencia Shalom: ${details.shalomAgencyName}')
        ..writeln('Ubicación: ${details.shalomAgencyLocality}')
        ..writeln('Dirección: ${details.shalomAgencyAddress}');
    }
    if (details.desiredDate != null) {
      buffer.writeln(
        'Fecha deseada: ${DateFormat('dd/MM/yyyy').format(details.desiredDate!)}',
      );
    }
    for (final entry in details.customFields.entries) {
      if (entry.value.trim().isNotEmpty) {
        buffer.writeln('${entry.key}: ${entry.value.trim()}');
      }
    }
    if (details.note.trim().isNotEmpty) {
      buffer.writeln('Nota: ${details.note.trim()}');
    }

    buffer
      ..writeln()
      ..writeln('Pago: ${order.payment.methodLabel} (simulado)')
      ..writeln('Referencia: ${order.payment.reference}')
      ..writeln()
      ..write(
        'IMPORTANTE: esta fue una simulación. No se realizó ningún cobro real. Stock, envío y fecha final se confirmarán por WhatsApp.',
      );
    return buffer.toString();
  }
}
