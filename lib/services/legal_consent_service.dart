import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/input_sanitizer.dart';
import '../security/rate_limiter.dart';

/// Versión oficial vigente de los textos legales (Términos, Privacidad,
/// Reembolsos y Cookies) adecuados a la legislación peruana (Ley N° 29733,
/// D.S. N° 016-2024-JUS y Código del Consumidor Ley N° 29571 - INDECOPI).
const String kCurrentLegalPolicyVersion = '2026-11-PE';

class LegalConsentRecord {
  const LegalConsentRecord({
    required this.context,
    required this.customerName,
    required this.customerPhone,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.policyVersion,
    required this.acceptedVia,
    required this.acceptedAtUtc,
  });

  final String context;
  final String customerName;
  final String customerPhone;
  final bool termsAccepted;
  final bool privacyAccepted;
  final String policyVersion;
  final String acceptedVia;
  final DateTime acceptedAtUtc;

  String get formattedSummary {
    final local = acceptedAtUtc.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    return 'Aceptado el $date ($acceptedVia · versión $policyVersion)';
  }

  Map<String, Object?> toJson() => {
    'context': context,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'termsAccepted': termsAccepted,
    'privacyAccepted': privacyAccepted,
    'policyVersion': policyVersion,
    'acceptedVia': acceptedVia,
    'acceptedAtUtc': acceptedAtUtc.toUtc().toIso8601String(),
  };

  factory LegalConsentRecord.fromJson(Map<String, Object?> json) {
    return LegalConsentRecord(
      context: InputSanitizer.sanitizeText(
        '${json['context'] ?? 'checkout_coordination'}',
        maxLength: 60,
      ),
      customerName: InputSanitizer.sanitizeText(
        '${json['customerName'] ?? ''}',
        maxLength: 120,
      ),
      customerPhone: InputSanitizer.sanitizeText(
        '${json['customerPhone'] ?? ''}',
        maxLength: 24,
      ),
      termsAccepted: json['termsAccepted'] == true,
      privacyAccepted: json['privacyAccepted'] == true,
      policyVersion: InputSanitizer.sanitizeText(
        '${json['policyVersion'] ?? kCurrentLegalPolicyVersion}',
        maxLength: 40,
      ),
      acceptedVia: InputSanitizer.sanitizeText(
        '${json['acceptedVia'] ?? 'two_separate_checkboxes'}',
        maxLength: 80,
      ),
      acceptedAtUtc:
          DateTime.tryParse('${json['acceptedAtUtc'] ?? ''}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// Gestiona y audita cuándo y cómo cada usuario aceptó los Términos y
/// Condiciones y la Política de Privacidad por separado, cumpliendo el
/// principio de responsabilidad proactiva del D.S. N° 016-2024-JUS (Perú).
class LegalConsentService {
  const LegalConsentService._();

  static const String _storageKey = 'expresiones.legal_consent_log.v1';
  static const String _cookieNoticeKey =
      'expresiones.technical_cookie_notice_ack.v1';
  static const int _maxLocalRecords = 150;

  static String get defaultChannel => kIsWeb
      ? 'web_dos_casillas_separadas'
      : 'app_dos_casillas_separadas';

  static Future<LegalConsentRecord> recordConsent({
    required String context,
    required bool termsAccepted,
    required bool privacyAccepted,
    String customerName = '',
    String customerPhone = '',
    String? acceptedVia,
    DateTime? timestamp,
    SupabaseClient? supabaseClient,
  }) async {
    if (!termsAccepted || !privacyAccepted) {
      throw const FormatException(
        'Debes aceptar por separado los Términos y Condiciones y la Política de Privacidad.',
      );
    }

    final record = LegalConsentRecord(
      context: InputSanitizer.sanitizeText(context, maxLength: 60),
      customerName: InputSanitizer.sanitizeText(customerName, maxLength: 120),
      customerPhone: InputSanitizer.sanitizeText(customerPhone, maxLength: 24),
      termsAccepted: true,
      privacyAccepted: true,
      policyVersion: kCurrentLegalPolicyVersion,
      acceptedVia: InputSanitizer.sanitizeText(
        acceptedVia ?? defaultChannel,
        maxLength: 80,
      ),
      acceptedAtUtc: (timestamp ?? DateTime.now()).toUtc(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await loadLocalHistory(prefs: prefs);
      final updated = <LegalConsentRecord>[
        record,
        ...existing.take(_maxLocalRecords - 1),
      ];
      await prefs.setString(
        _storageKey,
        jsonEncode([for (final item in updated) item.toJson()]),
      );
    } catch (_) {
      // En entornos de prueba sin almacenamiento persistente, continúa sin fallar.
    }

    final client = supabaseClient ?? _tryGetSupabaseClient();
    if (client != null) {
      final dedupKey =
          'legal_consent:${record.context}:${record.customerPhone}:${record.policyVersion}';
      final isNewInSession = ClientRateLimiter.instance.markOncePerSession(
        dedupKey,
      );
      final withinRateLimit = ClientRateLimiter.instance.tryAcquire(
        'legal_consent_insert',
        maxAttempts: 4,
        window: const Duration(minutes: 1),
      );
      if (isNewInSession && withinRateLimit) {
        try {
          final userId = client.auth.currentUser?.id;
          await client.from('legal_consents').insert({
            'user_id': userId,
            'context': record.context,
            'customer_name': record.customerName,
            'customer_phone': record.customerPhone,
            'terms_accepted': record.termsAccepted,
            'privacy_accepted': record.privacyAccepted,
            'policy_version': record.policyVersion,
            'accepted_via': record.acceptedVia,
            'accepted_at': record.acceptedAtUtc.toIso8601String(),
          });
        } catch (_) {
          // El respaldo queda garantizado en el snapshot de la orden, metadatos Auth y almacenamiento local.
        }
      }
    }

    return record;
  }

  static Future<List<LegalConsentRecord>> loadLocalHistory({
    SharedPreferences? prefs,
  }) async {
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      final raw = store.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List.unmodifiable([
        for (final item in decoded)
          if (item is Map)
            LegalConsentRecord.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v as Object?)),
            ),
      ]);
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> isCookieNoticeAcknowledged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_cookieNoticeKey) == true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> acknowledgeCookieNotice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cookieNoticeKey, true);
    } catch (_) {}
  }

  static SupabaseClient? _tryGetSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
