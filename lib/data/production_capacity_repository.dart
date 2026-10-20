import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/production_capacity.dart';

abstract interface class CapacityRepository {
  Future<ProductionCapacitySnapshot> load();
  Stream<ProductionCapacitySnapshot> watch();
}

/// Reads the public aggregate capacity row from Supabase.
///
/// The row contains no customer or order data. If Supabase has not been
/// configured, or is temporarily unavailable, the conservative local fallback
/// keeps the quote flow usable.
class SupabaseCapacityRepository implements CapacityRepository {
  SupabaseCapacityRepository({
    this.client,
    ProductionCapacitySnapshot? fallback,
  }) : fallback = fallback ?? ProductionCapacitySnapshot.twoPersonFallback();

  final SupabaseClient? client;
  final ProductionCapacitySnapshot fallback;

  @override
  Future<ProductionCapacitySnapshot> load() async {
    final activeClient = client;
    if (activeClient == null) return fallback;

    try {
      final row = await activeClient
          .from('availability')
          .select('data')
          .eq('id', 'public')
          .maybeSingle();
      return _snapshotFromRow(row);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Stream<ProductionCapacitySnapshot> watch() async* {
    final activeClient = client;
    if (activeClient == null) {
      yield fallback;
      return;
    }

    try {
      await for (final rows in activeClient
          .from('availability')
          .stream(primaryKey: const ['id'])
          .eq('id', 'public')) {
        if (rows.isEmpty) {
          yield fallback;
        } else {
          yield _snapshotFromRow(rows.first);
        }
      }
    } catch (_) {
      yield fallback;
    }
  }

  ProductionCapacitySnapshot _snapshotFromRow(Map<String, dynamic>? row) {
    final rawData = row?['data'];
    if (rawData is Map) {
      return ProductionCapacitySnapshot.fromMap(
        rawData.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return fallback;
  }
}
