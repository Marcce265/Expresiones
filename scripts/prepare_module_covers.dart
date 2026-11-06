import 'dart:io';

import 'package:image/image.dart' as image_lib;

/// Prepares one high-quality catalog cover and one lightweight card thumbnail
/// for every `slug sourcePath` pair passed after the output directory.
///
/// Example:
///   dart run scripts/prepare_module_covers.dart assets/images/module_covers \
///     tul-con-perlas C:/generated/tul.png
void main(List<String> arguments) {
  if (arguments.length < 3 || arguments.length.isEven) {
    stderr.writeln(
      'Uso: dart run scripts/prepare_module_covers.dart '
      '<directorio-salida> <slug> <imagen> [<slug> <imagen> ...]',
    );
    exitCode = 64;
    return;
  }

  final outputDirectory = Directory(arguments.first)
    ..createSync(recursive: true);
  for (var index = 1; index < arguments.length; index += 2) {
    final slug = arguments[index];
    final source = File(arguments[index + 1]);
    final decoded = image_lib.decodeImage(source.readAsBytesSync());
    if (decoded == null) {
      throw FormatException('No se pudo leer ${source.path}.');
    }
    final oriented = image_lib.bakeOrientation(decoded);
    final detail = _fitWithin(oriented, 1200);
    final thumbnail = _fitWithin(oriented, 640);
    File('${outputDirectory.path}/$slug.jpg')
        .writeAsBytesSync(image_lib.encodeJpg(detail, quality: 92));
    File('${outputDirectory.path}/${slug}_thumb.jpg')
        .writeAsBytesSync(image_lib.encodeJpg(thumbnail, quality: 86));
    stdout.writeln(
      '$slug: ${detail.width}x${detail.height} + '
      '${thumbnail.width}x${thumbnail.height}',
    );
  }
}

image_lib.Image _fitWithin(image_lib.Image source, int maximumEdge) {
  if (source.width <= maximumEdge && source.height <= maximumEdge) {
    return source;
  }
  return source.width >= source.height
      ? image_lib.copyResize(
          source,
          width: maximumEdge,
          interpolation: image_lib.Interpolation.average,
        )
      : image_lib.copyResize(
          source,
          height: maximumEdge,
          interpolation: image_lib.Interpolation.average,
        );
}
