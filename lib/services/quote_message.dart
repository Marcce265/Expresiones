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

  static String heading(String id) => 'Resumen de cotización - $id';

  static String build({
    required String id,
    required List<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
  }) {
    final buffer = StringBuffer()
      ..writeln(heading(id))
      ..writeln();

    for (final items in groupQuoteLines(lines)) {
      final first = items.first;
      final quantity = items.fold(0, (sum, item) => sum + item.line.quantity);
      final total = items.fold<double>(0, (sum, item) => sum + item.total);
      final hasVariants = items.any((item) => item.variant != null);
      final showBreakdown = hasVariants || items.length > 1;
      final sharedPrice = items.every(
        (item) => item.unitPrice == first.unitPrice,
      );
      final sharedTier = items.every(
        (item) => item.priceTierLabel == first.priceTierLabel,
      );
      final unitPrice = 'S/ ${first.unitPrice.toStringAsFixed(2)} c/u';
      final tier = sharedTier && first.priceTierLabel.toUpperCase() == 'DOCENA';
      final unit = first.product.unitLabel;
      final count = quantity == 12 && tier && unit == 'PAQUETE'
          ? '1 docena (12 paquetes)'
          : '$quantity × $unit';
      buffer.writeln(
        '• ${first.product.name} · $count · S/ ${total.toStringAsFixed(2)}',
      );
      if (quantity > 1 && sharedPrice) {
        buffer.writeln(
          tier ? '  Precio de docena: $unitPrice' : '  $unitPrice',
        );
      }
      final breakdown = <(String?, String, double), int>{};
      for (final item in items) {
        final key = (
          item.line.variantId,
          item.line.customization.trim(),
          item.unitPrice,
        );
        breakdown.update(
          key,
          (quantity) => quantity + item.line.quantity,
          ifAbsent: () => item.line.quantity,
        );
      }
      for (final entry in breakdown.entries) {
        final (variantId, customization, pricePerUnit) = entry.key;
        if (showBreakdown) {
          final variant = first.product.variantById(variantId);
          final price = sharedPrice
              ? ''
              : ' · S/ ${pricePerUnit.toStringAsFixed(2)} c/u';
          buffer.writeln('  - ${entry.value} × ${variant?.name ?? unit}$price');
        }
        if (customization.isNotEmpty) {
          buffer.writeln('    Detalle: $customization');
        }
      }
      buffer.writeln();
    }

    final amounts = quoteAmounts(lines, details.deliveryMethod);
    final shalom = details.deliveryMethod == DeliveryMethod.shalom;
    buffer.writeln(
      'Subtotal de productos: S/ ${amounts.subtotal.toStringAsFixed(2)}',
    );
    if (shalom) {
      buffer.writeln(
        'Transporte y embalaje: S/ ${amounts.transportAndPacking.toStringAsFixed(2)}',
      );
    } else {
      buffer.writeln('Entrega: ${details.deliveryLabel} (gratis)');
    }
    buffer
      ..writeln('Total: S/ ${amounts.total.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('Nombres y apellidos: ${details.name.trim()}')
      ..writeln('Teléfono: ${details.phone.trim()}');
    if (shalom) buffer.writeln('Entrega: ${details.deliveryLabel}');

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
    } else {
      buffer.writeln('Fecha deseada: no registrada');
    }
    for (final entry in details.customFields.entries) {
      if (entry.value.trim().isNotEmpty &&
          !isLegacyNameCustomField(entry.key)) {
        buffer.writeln('${entry.key}: ${entry.value.trim()}');
      }
    }
    if (details.note.trim().isNotEmpty) {
      buffer.writeln('Nota: ${details.note.trim()}');
    }

    buffer
      ..writeln()
      ..write(
        '¿Me confirman la disponibilidad y la fecha, por favor? ¡Gracias!',
      );
    return buffer.toString();
  }

  static String buildWhatsappIntro({
    required String id,
    required CoordinationDetails details,
  }) {
    final name = details.name.trim();
    final customer = name.isEmpty ? '' : ' Soy $name.';
    return 'Hola, ya preparé mi cotización $id en Expresiones.$customer '
        '¿Me ayudan a confirmar stock y entrega?';
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
      ..writeln('Compra simulada · $safeBrandName')
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
      ..writeln('Nombres y apellidos: ${details.name.trim()}')
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
      if (entry.value.trim().isNotEmpty &&
          !isLegacyNameCustomField(entry.key)) {
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
        'IMPORTANTE: esta fue una simulación. No se realizó ningún cobro real.',
      );
    return buffer.toString();
  }
}
