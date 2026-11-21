import '../models/catalog_models.dart';
import '../security/input_sanitizer.dart';

/// Motor de búsqueda 100% en memoria (cero consultas adicionales a Supabase)
/// con normalización de tildes, lematización de plurales/género en español,
/// búsqueda multitoken y agrupación inteligente de familias vs. variantes.
abstract final class CatalogSearchEngine {
  static const int maxQueryLength = 80;
  static const int defaultPageSize = 24;

  /// Tiempo de espera para registrar búsquedas sin resultados en telemetría
  /// (3 segundos) para evitar registros incompletos mientras el usuario escribe.
  static const Duration zeroResultTelemetryDebounce = Duration(seconds: 3);

  /// Tiempo de espera para filtrar resultados al escribir (evita reconstrucciones
  /// y descargas innecesarias de imágenes por cada tecla).
  static const Duration inputFilterDebounce = Duration(milliseconds: 450);

  static const Set<String> _stopwords = {
    'de',
    'del',
    'la',
    'el',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'para',
    'por',
    'con',
    'en',
    'y',
    'o',
    'a',
  };

  /// Normaliza una cadena eliminando tildes, diéresis, signos y espacios extra.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final sanitized = InputSanitizer.sanitizeText(
      input,
      maxLength: 240,
      neutralizeFormula: false,
    ).toLowerCase();

    final buffer = StringBuffer();
    for (final codeUnit in sanitized.codeUnits) {
      switch (codeUnit) {
        case 0x00E1: // á
        case 0x00E0: // à
        case 0x00E4: // ä
        case 0x00E2: // â
          buffer.write('a');
        case 0x00E9: // é
        case 0x00E8: // è
        case 0x00EB: // ë
        case 0x00EA: // ê
          buffer.write('e');
        case 0x00ED: // í
        case 0x00EC: // ì
        case 0x00EF: // ï
        case 0x00EE: // î
          buffer.write('i');
        case 0x00F3: // ó
        case 0x00F2: // ò
        case 0x00F6: // ö
        case 0x00F4: // ô
          buffer.write('o');
        case 0x00FA: // ú
        case 0x00F9: // ù
        case 0x00FC: // ü
        case 0x00FB: // û
          buffer.write('u');
        case 0x00F1: // ñ
          buffer.write('n');
        default:
          final isAlphaNum =
              (codeUnit >= 0x30 && codeUnit <= 0x39) ||
              (codeUnit >= 0x61 && codeUnit <= 0x7A);
          buffer.write(isAlphaNum ? String.fromCharCode(codeUnit) : ' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Reduce plurales y variaciones frecuentes de género en español para que
  /// "cintas" encuentre "CINTA SATINADA", "papeles" encuentre "PAPEL COREANO",
  /// "luces" encuentre "LUZ HADA", "rojas" encuentre "ROJO", etc.
  static String stemToken(String token) {
    var word = token.trim();
    if (word.length <= 2) return word;

    // Plurales irregulares terminados en -ces (luces -> luz)
    if (word.endsWith('ces') && word.length >= 5) {
      return '${word.substring(0, word.length - 3)}z';
    }

    // Plurales terminados en -es (papeles -> papel, colores -> color, flores -> flor)
    if (word.endsWith('es') && word.length >= 5) {
      final base = word.substring(0, word.length - 2);
      if (base.endsWith('l') ||
          base.endsWith('r') ||
          base.endsWith('n') ||
          base.endsWith('d') ||
          base.endsWith('z') ||
          base.endsWith('j')) {
        word = base;
      } else {
        word = word.substring(0, word.length - 1);
      }
    } else if (word.endsWith('s') && word.length >= 4 && !word.endsWith('ss')) {
      // Caso especial: limpiapipas siempre termina en s
      if (word != 'limpiapipas') {
        word = word.substring(0, word.length - 1);
      }
    }

    // Variaciones de género en adjetivos/colores comunes (rojo/roja, dorado/dorada, satinado/satinada)
    if (word.length >= 4 &&
        (word.endsWith('o') || word.endsWith('a')) &&
        !word.endsWith('cinta') &&
        !word.endsWith('corona') &&
        !word.endsWith('rosa') &&
        !word.endsWith('perla') &&
        !word.endsWith('brocheta') &&
        !word.endsWith('mariposa') &&
        !word.endsWith('silicona') &&
        !word.endsWith('pistola') &&
        !word.endsWith('abejita') &&
        !word.endsWith('margarita')) {
      return word.substring(0, word.length - 1);
    }

    return word;
  }

  /// Extrae tokens de búsqueda normalizados y lematizados.
  static List<String> tokenizeQuery(String rawQuery) {
    final normalized = normalize(rawQuery);
    if (normalized.isEmpty) return const [];
    final rawTokens = normalized.split(' ');
    final filtered = rawTokens.length > 1
        ? rawTokens.where((t) => !_stopwords.contains(t)).toList()
        : rawTokens;
    final effective = filtered.isEmpty ? rawTokens : filtered;
    return [
      for (final token in effective)
        if (token.isNotEmpty) stemToken(token),
    ];
  }

  static bool _textMatchesTokens(String normalizedText, List<String> tokens) {
    if (tokens.isEmpty) return true;
    final words = normalizedText.split(' ');
    for (final token in tokens) {
      if (normalizedText.contains(token)) continue;
      final matchedByStem = words.any(
        (w) => w.startsWith(token) || stemToken(w).startsWith(token),
      );
      if (!matchedByStem) return false;
    }
    return true;
  }

  static String _productHaystack(CatalogProduct product) {
    return normalize(
      [
        product.name,
        familyDisplayName(product),
        product.description,
        product.sku ?? '',
        product.category.label,
        ...product.tags,
        ...product.attributes.values,
      ].join(' '),
    );
  }

  static String _variantHaystack(ProductVariant variant) {
    return normalize(
      [
        variant.name,
        variantDisplayName(variant),
        variant.sku ?? '',
        ...variant.attributes.values,
      ].join(' '),
    );
  }

  /// Búsqueda inteligente sobre un conjunto de productos (Home o raíz de Catálogo).
  ///
  /// - Si la consulta coincide con la familia (ej. "cintas", "limpiapipas",
  ///   "papel coreano", "coronas") sin apuntar a un color/código específico,
  ///   devuelve la tarjeta de familia agrupada (sin saturar con 80 tarjetas
  ///   del mismo rollo).
  /// - Si la consulta coincide con un color, modelo o SKU de variante (ej.
  ///   "vino", "cinta roja", "limpiapipas amarillo", "SAT-01"), devuelve esas
  ///   variantes exactas ordenadas por relevancia.
  static List<CatalogTile> searchProducts(
    Iterable<CatalogProduct> products,
    String rawQuery, {
    bool expandFamilyMatches = false,
  }) {
    final tokens = tokenizeQuery(rawQuery);
    final normalizedFullQuery = normalize(rawQuery);
    if (tokens.isEmpty) return const [];

    final scored = <({CatalogTile tile, int score})>[];

    for (final product in products) {
      if (!product.isActive) continue;
      final activeVariants = product.variants
          .where((v) => v.isActive)
          .toList(growable: false);
      final pText = _productHaystack(product);
      final pName = normalize(product.name);
      final pSku = normalize(product.sku ?? '');
      final productMatchesAll = _textMatchesTokens(pText, tokens);

      if (activeVariants.isEmpty) {
        if (productMatchesAll) {
          scored.add((
            tile: (product: product, variant: null),
            score: _scoreMatch(
              name: pName,
              sku: pSku,
              fullQuery: normalizedFullQuery,
              tokens: tokens,
              isFamilyCard: true,
            ),
          ));
        }
        continue;
      }

      // Buscar si algún token apunta específicamente a una variante (color o SKU)
      final matchingVariants = <({ProductVariant variant, int score})>[];
      var anyVariantSpecificToken = false;

      for (final variant in activeVariants) {
        final vText = _variantHaystack(variant);
        final combined = '$pText $vText';
        if (_textMatchesTokens(combined, tokens)) {
          final variantHasDirectHit = tokens.any(
            (token) =>
                vText.contains(token) ||
                vText
                    .split(' ')
                    .any((w) => stemToken(w).startsWith(token)),
          );
          if (variantHasDirectHit) {
            anyVariantSpecificToken = true;
          }
          matchingVariants.add((
            variant: variant,
            score: _scoreMatch(
              name: normalize('${product.name} ${variant.name}'),
              sku: normalize(variant.sku ?? ''),
              fullQuery: normalizedFullQuery,
              tokens: tokens,
              isFamilyCard: false,
            ),
          ));
        }
      }

      if (productMatchesAll && !expandFamilyMatches) {
        // Caso "cintas", "cinta satinada", "limpiapipas": devolver la familia
        // agrupada con máxima prioridad para evitar 80 tarjetas repetidas.
        if (anyVariantSpecificToken) {
          for (final entry in matchingVariants) {
            scored.add((
              tile: (product: product, variant: entry.variant),
              score: entry.score,
            ));
          }
        } else {
          scored.add((
            tile: (product: product, variant: null),
            score:
                _scoreMatch(
                  name: pName,
                  sku: pSku,
                  fullQuery: normalizedFullQuery,
                  tokens: tokens,
                  isFamilyCard: true,
                ) +
                25,
          ));
        }
      } else {
        for (final entry in matchingVariants) {
          scored.add((
            tile: (product: product, variant: entry.variant),
            score: entry.score,
          ));
        }
      }
    }

    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.tile.product.sortOrder.compareTo(b.tile.product.sortOrder);
    });

    return [for (final item in scored) item.tile];
  }

  /// Filtra tarjetas dentro de una familia específica (ej. colores dentro de
  /// Limpiapipas o Cinta Satinada) usando normalización y lematización.
  static List<CatalogTile> filterFamilyTiles(
    Iterable<CatalogTile> tiles,
    String rawQuery,
  ) {
    final tokens = tokenizeQuery(rawQuery);
    if (tokens.isEmpty) return tiles.toList(growable: false);
    return tiles
        .where((tile) {
          final pText = _productHaystack(tile.product);
          final vText = tile.variant == null
              ? ''
              : _variantHaystack(tile.variant!);
          return _textMatchesTokens('$pText $vText', tokens);
        })
        .toList(growable: false);
  }

  static int _scoreMatch({
    required String name,
    required String sku,
    required String fullQuery,
    required List<String> tokens,
    required bool isFamilyCard,
  }) {
    var score = isFamilyCard ? 40 : 20;
    if (sku.isNotEmpty && sku == fullQuery) score += 200;
    if (name == fullQuery) score += 160;
    if (name.startsWith(fullQuery)) score += 90;
    for (final token in tokens) {
      if (name.contains(token)) score += 30;
      if (sku.contains(token)) score += 25;
    }
    return score;
  }
}
