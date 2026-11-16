import 'package:expresiones/data/shalom_agency_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'el directorio oficial conserva destinos con coordenadas precisas',
    () async {
      final catalog = await ShalomAgencyRepository.load();
      final destinations = catalog.agencies
          .where((agency) => agency.isPublic && agency.canReceive)
          .toList(growable: false);

      expect(catalog.source, 'https://shalom.com.pe/agencias');
      expect(catalog.updatedAt, isNotNull);
      expect(catalog.updatedAt!.isBefore(DateTime(2026, 11, 16)), isFalse);
      expect(destinations.length, greaterThanOrEqualTo(490));
      expect(
        destinations.map((agency) => agency.id).toSet(),
        hasLength(destinations.length),
      );

      for (final agency in destinations) {
        expect(agency.latitude, isNotNull, reason: agency.displayName);
        expect(agency.longitude, isNotNull, reason: agency.displayName);
        expect(
          agency.latitude,
          inInclusiveRange(-20, 1),
          reason: agency.displayName,
        );
        expect(
          agency.longitude,
          inInclusiveRange(-83, -68),
          reason: agency.displayName,
        );
      }

      final huancayo = destinations.singleWhere((agency) => agency.id == '181');
      expect(huancayo.displayName, 'HUANCAYO JR. ICA');
      expect(huancayo.latitude, closeTo(-12.0739582, 0.0000001));
      expect(huancayo.longitude, closeTo(-75.2141862, 0.0000001));
    },
  );
}
