import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/security/input_sanitizer.dart';
import 'package:expresiones/security/rate_limiter.dart';

void main() {
  group('InputSanitizer - Anti-XSS, Anti-SQLi y Anti-Formula Injection', () {
    test('elimina etiquetas HTML, scripts y caracteres de control', () {
      const malicious =
          'Juan <script>alert("xss")</script>\x00\u202E Pérez <b>Admin</b>';
      final cleaned = InputSanitizer.sanitizeText(malicious);
      expect(cleaned, isNot(contains('<script>')));
      expect(cleaned, isNot(contains('<b>')));
      expect(cleaned, isNot(contains('\x00')));
      expect(cleaned, isNot(contains('\u202E')));
      expect(cleaned, contains('Juan'));
      expect(cleaned, contains('Pérez'));
    });

    test('detecta intentos de inyección SQL y XSS', () {
      expect(
        InputSanitizer.containsSqlOrScriptInjection(
          "admin' UNION SELECT * FROM auth.users --",
        ),
        isTrue,
      );
      expect(
        InputSanitizer.containsSqlOrScriptInjection(
          'DROP TABLE customer_orders;',
        ),
        isTrue,
      );
      expect(
        InputSanitizer.containsSqlOrScriptInjection(
          '<img src=x onerror=alert(1)>',
        ),
        isTrue,
      );
      expect(
        InputSanitizer.containsSqlOrScriptInjection(
          'javascript:window.location="https://evil.com"',
        ),
        isTrue,
      );
      expect(
        InputSanitizer.containsSqlOrScriptInjection(
          'María Elena Quispe - Huancayo',
        ),
        isFalse,
      );
    });

    test('neutraliza inyección de fórmulas para Excel/CSV', () {
      expect(
        InputSanitizer.sanitizeText("=CMD|' /C calc'!A0"),
        "CMD|' /C calc'!A0",
      );
      expect(
        InputSanitizer.sanitizeText('@SUM(1+1)*cmd'),
        'SUM(1+1)*cmd',
      );
      expect(
        InputSanitizer.sanitizeText('+HYPERLINK("http://evil.com")'),
        'HYPERLINK("http://evil.com")',
      );
    });

    test('valida slugs seguros y rechaza rutas o inyecciones', () {
      expect(
        InputSanitizer.validateSafeSlug('limpiapipas-premium-01'),
        'limpiapipas-premium-01',
      );
      expect(InputSanitizer.validateSafeSlug('../etc/passwd'), isNull);
      expect(InputSanitizer.validateSafeSlug('slug; drop table'), isNull);
    });

    test('detecta claves secretas service_role o sb_secret_', () {
      expect(
        InputSanitizer.isServiceRoleOrSecretKey('sb_secret_123456789'),
        isTrue,
      );
      expect(
        InputSanitizer.isServiceRoleOrSecretKey(
          'sb_publishable_abc123456789',
        ),
        isFalse,
      );

      // Simular un JWT con role: service_role
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final servicePayload = base64Url.encode(
        utf8.encode('{"role":"service_role","iss":"supabase"}'),
      );
      final anonPayload = base64Url.encode(
        utf8.encode('{"role":"anon","iss":"supabase"}'),
      );
      expect(
        InputSanitizer.isServiceRoleOrSecretKey(
          '$header.$servicePayload.signature',
        ),
        isTrue,
      );
      expect(
        InputSanitizer.isServiceRoleOrSecretKey(
          '$header.$anonPayload.signature',
        ),
        isFalse,
      );
    });

    test('bloquea ejecutables o HTML camuflados como imágenes', () {
      final exeBytes = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00, 0x03]);
      expect(
        () => AdminCatalogRepository.validateCatalogImageUpload(
          bytes: exeBytes,
          contentType: 'image/png',
        ),
        throwsFormatException,
      );

      final htmlBytes = Uint8List.fromList(
        utf8.encode('<!DOCTYPE html><script>alert(1)</script>'),
      );
      expect(
        () => AdminCatalogRepository.validateCatalogImageUpload(
          bytes: htmlBytes,
          contentType: 'image/webp',
        ),
        throwsFormatException,
      );
    });
  });

  group('CoordinationDetails - Saneamiento automático en JSON', () {
    test('limpia campos de cliente y customFields al serializar', () {
      final details = CoordinationDetails(
        name: '  =Ana <script>evil()</script> ',
        phone: '987654321',
        destination: 'Lima <iframe src="x"></iframe>',
        note: 'Entregar por la tarde <img onerror=alert(1)>',
        customFields: const {
          '<b>Dedicatoria</b>': '=Feliz cumpleaños <script>x</script>',
        },
      );

      final json = details.toJson();
      expect(json['name'], 'Ana evil()');
      expect(json['destination'], 'Lima');
      expect(json['note'], 'Entregar por la tarde');
      final fields = json['customFields'] as Map<String, String>;
      expect(fields['Dedicatoria'], 'Feliz cumpleaños x');
    });
  });

  group('ClientRateLimiter - Protección contra fuerza bruta y spam', () {
    test('bloquea cuando se supera el máximo de intentos en la ventana', () {
      var now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final limiter = ClientRateLimiter(clock: () => now);

      for (var i = 0; i < 3; i++) {
        expect(
          limiter.tryAcquire(
            'test_action',
            maxAttempts: 3,
            window: const Duration(minutes: 1),
          ),
          isTrue,
        );
      }

      // El cuarto intento dentro del mismo minuto debe bloquearse
      expect(
        () => limiter.enforce(
          'test_action',
          maxAttempts: 3,
          window: const Duration(minutes: 1),
        ),
        throwsFormatException,
      );

      // Al avanzar el reloj más allá de la ventana de 1 minuto, vuelve a permitir
      now = now.add(const Duration(seconds: 61));
      expect(
        limiter.tryAcquire(
          'test_action',
          maxAttempts: 3,
          window: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });
  });
}
