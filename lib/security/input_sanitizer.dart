import 'dart:convert';
import 'dart:typed_data';

/// Centraliza la validación, saneamiento y detección de inyecciones (XSS, SQLi,
/// fórmulas CSV/Excel y archivos ejecutables camuflados) antes de procesar o
/// enviar cualquier dato fuera del dispositivo.
abstract final class InputSanitizer {
  /// Expresión regular para detectar etiquetas HTML o intentos de inyección XSS.
  static final RegExp _htmlTagPattern = RegExp(
    r'<\s*/?\s*[a-zA-Z!/?][^>]*>',
    multiLine: true,
  );

  /// Patrones peligrosos de ejecución de scripts o vectores XSS/SQLi comunes.
  static final RegExp _dangerousPayloadPattern = RegExp(
    r'(javascript\s*:|vbscript\s*:|data\s*:\s*text/html|on(?:load|error|click|mouseover|focus|blur|submit|change|input)\s*=|<\s*script|<\s*iframe|<\s*object|<\s*embed|<\s*svg|\beval\s*\(|\bdocument\s*\.\s*cookie|\bwindow\s*\.\s*location|\bunion\s+all\s+select\b|\bunion\s+select\b|\bdrop\s+table\b|\bdelete\s+from\b|\binsert\s+into\b|\bupdate\s+\w+\s+set\b|--\s*$|/\*[\s\S]*?\*/)',
    caseSensitive: false,
    multiLine: true,
  );

  /// Caracteres de control ASCII (excepto salto de línea y tabulación) y
  /// caracteres Unicode bidireccionales usados para suplantación de texto.
  static final RegExp _controlAndBidiChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  );

  /// Prefijos peligrosos que activan fórmulas al exportar a Excel / CSV.
  static final RegExp _formulaPrefixPattern = RegExp(r'^[\s]*[=+\-@|]');

  /// Formato estricto de identificadores (slugs) seguros para URLs y base de datos.
  static final RegExp _safeSlugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  /// Limpia un texto eliminando caracteres de control, etiquetas HTML, vectores
  /// de script y (opcionalmente) prefijos de inyección de fórmulas de Excel.
  static String sanitizeText(
    String input, {
    int maxLength = 250,
    bool allowNewlines = false,
    bool neutralizeFormula = true,
  }) {
    if (input.isEmpty) return '';

    var cleaned = input.replaceAll(_controlAndBidiChars, '');

    // Eliminar etiquetas HTML y esquemas peligrosos
    cleaned = cleaned.replaceAll(_htmlTagPattern, '');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(javascript\s*:|vbscript\s*:|data\s*:\s*text/html)',
        caseSensitive: false,
      ),
      '',
    );

    if (!allowNewlines) {
      cleaned = cleaned.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    } else {
      cleaned = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }

    cleaned = cleaned.trim();

    // Neutralizar inyección de fórmulas en exportaciones XLSX/CSV (=CMD, +SUM, @, -).
    if (neutralizeFormula && _formulaPrefixPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(RegExp(r'^[\s]*[=+\-@|]+'), '').trim();
    }

    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }

    return cleaned;
  }

  /// Devuelve `true` si el texto contiene patrones claros de inyección SQL o XSS.
  static bool containsSqlOrScriptInjection(String input) {
    if (input.isEmpty) return false;
    return _dangerousPayloadPattern.hasMatch(input) ||
        _htmlTagPattern.hasMatch(input);
  }

  /// Valida que un texto no contenga inyecciones y lanza [FormatException] si
  /// se detecta un intento malicioso.
  static String requireSafeText(
    String input, {
    required String fieldName,
    int minLength = 0,
    int maxLength = 250,
    bool allowNewlines = false,
  }) {
    if (containsSqlOrScriptInjection(input)) {
      throw FormatException(
        'El campo $fieldName contiene caracteres o código no permitido.',
      );
    }
    final sanitized = sanitizeText(
      input,
      maxLength: maxLength,
      allowNewlines: allowNewlines,
    );
    if (sanitized.length < minLength) {
      throw FormatException(
        'El campo $fieldName debe tener al menos $minLength caracteres.',
      );
    }
    return sanitized;
  }

  /// Verifica que un slug de producto o variante sea seguro antes de enviarlo a RPCs.
  static String? validateSafeSlug(String? slug, {int maxLength = 100}) {
    final normalized = slug?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized.length > maxLength) return null;
    if (!_safeSlugPattern.hasMatch(normalized)) return null;
    return normalized;
  }

  /// Limpia un mapa de campos adicionales del checkout limitando cantidad y longitud.
  static Map<String, String> sanitizeCustomFields(
    Map<String, String> rawFields, {
    int maxEntries = 20,
    int maxKeyLength = 80,
    int maxValueLength = 300,
  }) {
    final result = <String, String>{};
    for (final entry in rawFields.entries) {
      if (result.length >= maxEntries) break;
      final safeKey = sanitizeText(entry.key, maxLength: maxKeyLength);
      final safeValue = sanitizeText(
        entry.value,
        maxLength: maxValueLength,
        allowNewlines: true,
      );
      if (safeKey.isNotEmpty && safeValue.isNotEmpty) {
        result[safeKey] = safeValue;
      }
    }
    return Map.unmodifiable(result);
  }

  /// Inspecciona los primeros bytes de un archivo para bloquear ejecutables
  /// (.exe, ELF) o scripts HTML/SVG/PHP camuflados como imágenes.
  static void validateNoDisguisedExecutableOrHtml(Uint8List bytes) {
    if (bytes.length < 4) return;

    // 1. Bloquear binarios Windows PE/EXE ('MZ' -> 0x4D 0x5A) si no es imagen válida
    if (bytes[0] == 0x4D && bytes[1] == 0x5A) {
      throw const FormatException(
        'Archivo bloqueado por seguridad: formato ejecutable no permitido.',
      );
    }

    // 2. Bloquear binarios Linux ELF (0x7F 'E' 'L' 'F')
    if (bytes[0] == 0x7F &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4C &&
        bytes[3] == 0x46) {
      throw const FormatException(
        'Archivo bloqueado por seguridad: binario no permitido.',
      );
    }

    // 3. Inspeccionar cabecera de texto en busca de HTML, SVG, XML o scripts XSS
    final previewLength = bytes.length < 256 ? bytes.length : 256;
    final asciiPreview = String.fromCharCodes(
      bytes.sublist(0, previewLength),
    ).trimLeft().toLowerCase();

    if (asciiPreview.startsWith('<!doctype') ||
        asciiPreview.startsWith('<html') ||
        asciiPreview.startsWith('<script') ||
        asciiPreview.startsWith('<svg') ||
        asciiPreview.startsWith('<?xml') ||
        asciiPreview.startsWith('<?php') ||
        asciiPreview.contains('<script') ||
        asciiPreview.contains('javascript:')) {
      throw const FormatException(
        'Archivo rechazado por seguridad: contiene código o etiquetas activas.',
      );
    }
  }

  /// Verifica que una clave de Supabase no sea una clave secreta de servidor
  /// (`service_role` o `sb_secret_`), evitando exponer credenciales privadas en el cliente.
  static bool isServiceRoleOrSecretKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('sb_secret_') ||
        lower.contains('service_role') ||
        lower.startsWith('sbp_')) {
      return true;
    }

    // Si es un JWT (header.payload.signature), decodificar el payload para verificar el rol
    final parts = trimmed.split('.');
    if (parts.length == 3) {
      try {
        final normalized = base64Url.normalize(parts[1]);
        final payloadJson = utf8.decode(base64Url.decode(normalized));
        final decoded = jsonDecode(payloadJson);
        if (decoded is Map) {
          final role = '${decoded['role'] ?? ''}'.toLowerCase().trim();
          if (role == 'service_role' || role == 'supabase_admin') {
            return true;
          }
        }
      } catch (_) {
        // Si no es un JWT estándar decodificable, continuar.
      }
    }
    return false;
  }
}
