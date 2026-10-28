import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ProductPopularityRepository {
  const ProductPopularityRepository();

  Future<List<String>> loadTopProductIds({int limit = 6});

  Future<void> recordView(String productId);

  Future<void> recordAdded(String productId, {required int quantity});

  Future<void> recordCompleted(Map<String, int> quantitiesByProduct);
}

class SupabaseProductPopularityRepository
    implements ProductPopularityRepository {
  const SupabaseProductPopularityRepository({this.client});

  final SupabaseClient? client;

  @override
  Future<List<String>> loadTopProductIds({int limit = 6}) async {
    final activeClient = client;
    if (activeClient == null || limit < 1) return const [];
    final rows = await activeClient
        .from('product_popularity')
        .select('product_slug')
        .order('score', ascending: false)
        .order('units_completed', ascending: false)
        .order('units_added', ascending: false)
        .order('views', ascending: false)
        .limit(limit);
    return List.unmodifiable([
      for (final row in rows)
        if ((row['product_slug']?.toString().trim() ?? '').isNotEmpty)
          row['product_slug'].toString().trim(),
    ]);
  }

  @override
  Future<void> recordView(String productId) =>
      _record(productId, action: 'view', quantity: 1);

  @override
  Future<void> recordAdded(String productId, {required int quantity}) =>
      _record(productId, action: 'add', quantity: quantity);

  @override
  Future<void> recordCompleted(Map<String, int> quantitiesByProduct) async {
    final events = quantitiesByProduct.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .map(
          (entry) =>
              _record(entry.key, action: 'complete', quantity: entry.value),
        );
    await Future.wait(events);
  }

  Future<void> _record(
    String productId, {
    required String action,
    required int quantity,
  }) async {
    final activeClient = client;
    final normalizedId = productId.trim();
    if (activeClient == null || normalizedId.isEmpty || quantity < 1) return;
    await activeClient.rpc<void>(
      'record_product_popularity',
      params: {
        'p_product_slug': normalizedId,
        'p_action': action,
        'p_quantity': quantity.clamp(1, 10000),
      },
    );
  }
}
