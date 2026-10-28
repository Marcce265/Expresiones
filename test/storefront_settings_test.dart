import 'package:expresiones/models/storefront_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorefrontSettings', () {
    test('usa la dirección real de Expresiones Eternas por defecto', () {
      const location = PickupLocationSettings();

      expect(location.name, 'Expresiones Eternas');
      expect(location.address, 'Pje. Porvenir 149, Huancayo 12001');
      expect(location.hasCoordinates, isTrue);
    });

    test('incluye textos seguros para el pago simulado', () {
      const settings = StorefrontSettings();

      expect(
        settings.text(StorefrontText.paymentTitle),
        'Completa tu compra simulada',
      );
      expect(
        settings.text(StorefrontText.paymentDisclaimer),
        contains('no realiza cargos'),
      );
      expect(
        settings.text(StorefrontText.successNoCharge),
        contains('No acredita un pago'),
      );
      expect(
        settings.text(StorefrontText.privacySectionTitle(8)),
        'Pago simulado',
      );
    });

    test('conserva personalizaciones del pago al serializar', () {
      const settings = StorefrontSettings(
        texts: {
          StorefrontText.paymentSubmitButton: 'Confirmar demostración',
          StorefrontText.successTitle: 'Demostración completada',
        },
      );

      final restored = StorefrontSettings.fromMap(settings.toMap());

      expect(
        restored.text(StorefrontText.paymentSubmitButton),
        'Confirmar demostración',
      );
      expect(
        restored.text(StorefrontText.successTitle),
        'Demostración completada',
      );
      expect(
        (restored.toMap()['texts'] as Map)[StorefrontText.paymentCardMethod],
        'Tarjeta de demostración',
      );
    });

    test('conserva ubicación de recojo y campos adicionales', () {
      const settings = StorefrontSettings(
        pickupLocation: PickupLocationSettings(
          name: 'Tienda principal',
          address: 'Jr. Ejemplo 123, Huancayo',
          latitude: -12.0651,
          longitude: -75.2049,
        ),
        checkoutFields: [
          CheckoutCustomField(
            id: 'dni',
            label: 'DNI',
            icon: 'badge',
            hint: 'Documento para recoger',
            required: true,
          ),
          CheckoutCustomField(
            id: 'dedicatoria',
            label: 'Dedicatoria',
            multiline: true,
            enabled: false,
          ),
        ],
      );

      final restored = StorefrontSettings.fromMap(settings.toMap());

      expect(restored.pickupLocation.name, 'Tienda principal');
      expect(restored.pickupLocation.hasCoordinates, isTrue);
      expect(restored.checkoutFields, hasLength(2));
      expect(restored.checkoutFields.first.icon, 'badge');
      expect(restored.checkoutFields.first.required, isTrue);
      expect(restored.checkoutFields.last.enabled, isFalse);
    });

    test('ignora campos incompletos o con identificadores repetidos', () {
      final restored = StorefrontSettings.fromMap({
        'checkoutFields': [
          {'id': 'uno', 'label': 'Primero'},
          {'id': 'uno', 'label': 'Duplicado'},
          {'id': '', 'label': 'Sin id'},
          {'id': 'sin-label', 'label': ''},
        ],
      });

      expect(restored.checkoutFields, hasLength(1));
      expect(restored.checkoutFields.single.label, 'Primero');
    });
  });
}
