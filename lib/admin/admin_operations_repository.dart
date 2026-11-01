import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commerce_telemetry.dart';
import '../models/production_capacity.dart';

class AdminOperationsRepository {
  AdminOperationsRepository({required this.client});

  final SupabaseClient client;

  Stream<ProductionCapacitySnapshot> watchCapacity() {
    return client
        .from('availability')
        .stream(primaryKey: const ['id'])
        .eq('id', 'public')
        .map((rows) {
          if (rows.isEmpty || rows.first['data'] is! Map) {
            return ProductionCapacitySnapshot.twoPersonFallback();
          }
          final data = (rows.first['data'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          );
          return ProductionCapacitySnapshot.fromMap(data);
        });
  }

  Future<void> saveCapacity(ProductionCapacitySnapshot snapshot) async {
    final data = snapshot.toMap()..remove('updatedAt');
    await client.from('availability').upsert({'id': 'public', 'data': data});
  }

  Future<List<AdminAuditLog>> loadAuditLogs({int limit = 100}) async {
    final rows = await client
        .from('admin_audit_logs')
        .select(
          'id, action, resource_type, resource_id, resource_label, '
          'actor_email, changed_sections, created_at',
        )
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100));
    return rows.map(AdminAuditLog.fromMap).toList(growable: false);
  }

  /// Reads at most [limit] anonymous events from the selected recent window.
  /// This keeps both Supabase reads and admin rendering bounded.
  Stream<AdminAnalyticsSummary> watchAnalytics({
    Duration window = const Duration(days: 30),
    int limit = 1000,
  }) {
    final safeLimit = limit.clamp(1, 2000);
    return Stream.value(
      AdminAnalyticsSummary.fromDocuments(
        const [],
        requestedWindow: window,
        sampleLimit: safeLimit,
      ),
    );
  }
}

class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.resourceLabel,
    required this.actorEmail,
    required this.changedSections,
    required this.createdAt,
  });

  factory AdminAuditLog.fromMap(Map<String, dynamic> row) {
    final rawSections = row['changed_sections'];
    return AdminAuditLog(
      id: (row['id'] as num?)?.toInt() ?? 0,
      action: row['action']?.toString() ?? 'update',
      resourceType: row['resource_type']?.toString() ?? '',
      resourceId: row['resource_id']?.toString() ?? '',
      resourceLabel: row['resource_label']?.toString() ?? '',
      actorEmail: row['actor_email']?.toString() ?? '',
      changedSections: rawSections is Iterable
          ? rawSections.map((value) => value.toString()).toList(growable: false)
          : const [],
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int id;
  final String action;
  final String resourceType;
  final String resourceId;
  final String resourceLabel;
  final String actorEmail;
  final List<String> changedSections;
  final DateTime createdAt;
}

class AdminAnalyticsSummary {
  const AdminAnalyticsSummary({
    required this.totalEvents,
    required this.counts,
    required this.topMissingSearches,
    required this.topViewedProducts,
    required this.topAddedProducts,
    required this.requestedWindow,
    required this.sampleLimit,
  });

  final int totalEvents;
  final Map<CommerceEventType, int> counts;
  final List<AnalyticsRank> topMissingSearches;
  final List<AnalyticsRank> topViewedProducts;
  final List<AnalyticsRank> topAddedProducts;
  final Duration requestedWindow;
  final int sampleLimit;

  int count(CommerceEventType type) => counts[type] ?? 0;

  double get quoteCompletionRate {
    final sent = count(CommerceEventType.quoteSent);
    final abandoned = count(CommerceEventType.quoteAbandoned);
    final total = sent + abandoned;
    return total == 0 ? 0 : sent / total;
  }

  factory AdminAnalyticsSummary.fromDocuments(
    Iterable<Map<String, dynamic>> documents, {
    required Duration requestedWindow,
    required int sampleLimit,
  }) {
    final counts = <CommerceEventType, int>{};
    final searches = <String, int>{};
    final views = <String, int>{};
    final added = <String, int>{};
    var total = 0;

    for (final data in documents) {
      final type = CommerceEventType.fromKey(data['eventType']);
      if (type == null) continue;
      total += 1;
      counts[type] = (counts[type] ?? 0) + 1;
      switch (type) {
        case CommerceEventType.zeroResultSearch:
          _increment(searches, data['searchTerm']);
        case CommerceEventType.productView:
          _increment(views, data['productId']);
        case CommerceEventType.productAdded:
          _increment(added, data['productId']);
        case CommerceEventType.quoteAbandoned:
        case CommerceEventType.quoteSent:
          break;
      }
    }

    return AdminAnalyticsSummary(
      totalEvents: total,
      counts: Map.unmodifiable(counts),
      topMissingSearches: _rank(searches),
      topViewedProducts: _rank(views),
      topAddedProducts: _rank(added),
      requestedWindow: requestedWindow,
      sampleLimit: sampleLimit,
    );
  }

  static void _increment(Map<String, int> values, Object? rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) return;
    values[value] = (values[value] ?? 0) + 1;
  }

  static List<AnalyticsRank> _rank(Map<String, int> values) {
    final rows =
        values.entries
            .map((entry) => AnalyticsRank(entry.key, entry.value))
            .toList()
          ..sort((a, b) {
            final count = b.count.compareTo(a.count);
            return count != 0 ? count : a.label.compareTo(b.label);
          });
    return List.unmodifiable(rows.take(10));
  }
}

class AnalyticsRank {
  const AnalyticsRank(this.label, this.count);

  final String label;
  final int count;
}
