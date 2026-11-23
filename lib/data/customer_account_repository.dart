import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checkout_order.dart';
import '../models/coordination_details.dart';
import '../models/pickup_order_qr.dart';
import '../security/input_sanitizer.dart';
import '../security/rate_limiter.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final String phone;
  final String? avatarUrl;

  factory CustomerProfile.fromJson(
    Map<String, dynamic> json, {
    String? avatarUrl,
  }) {
    return CustomerProfile(
      userId: '${json['user_id'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      avatarUrl: avatarUrl,
    );
  }
}

class StoredCustomerOrder {
  const StoredCustomerOrder({
    required this.order,
    required this.customerName,
    required this.customerPhone,
    required this.status,
  });

  final CheckoutOrder order;
  final String customerName;
  final String customerPhone;
  final String status;
}

class CustomerAccountRepository {
  CustomerAccountRepository({required this.client});

  final SupabaseClient client;

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('51') && digits.length == 11) {
      digits = digits.substring(2);
    }
    if (digits.length != 9 || !digits.startsWith('9')) {
      throw const FormatException('Escribe un celular peruano de 9 dígitos.');
    }
    return digits;
  }

  static String loginEmail(String phone) =>
      '51${normalizePhone(phone)}@clientes.expresiones.app';

  Future<CustomerProfile?> currentProfile({bool includeAvatar = true}) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('customer_profiles')
        .select('user_id, full_name, phone')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final avatarPath = user.userMetadata?['avatar_path']?.toString().trim();
    String? avatarUrl;
    if (includeAvatar && avatarPath != null && avatarPath.isNotEmpty) {
      try {
        avatarUrl = await client.storage
            .from('customer-avatars')
            .createSignedUrl(avatarPath, 3600);
      } catch (_) {
        // A missing avatar or an unapplied storage migration must not lock out
        // access to the rest of the customer account.
      }
    }
    return CustomerProfile.fromJson(row, avatarUrl: avatarUrl);
  }

  Future<CustomerProfile> saveAvatar(Uint8List bytes) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para guardar tu foto.');
    if (bytes.isEmpty || bytes.length > 512 * 1024) {
      throw const FormatException('No se pudo optimizar la foto de perfil.');
    }
    final profile = await currentProfile(includeAvatar: false);
    if (profile == null) throw StateError('No se encontró tu perfil.');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${user.id}/$timestamp.webp';
    final bucket = client.storage.from('customer-avatars');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        contentType: 'image/webp',
        upsert: false,
      ),
    );
    final oldPath = user.userMetadata?['avatar_path']?.toString();
    final String avatarUrl;
    try {
      avatarUrl = await bucket.createSignedUrl(path, 3600);
      await client.auth.updateUser(UserAttributes(data: {'avatar_path': path}));
    } catch (_) {
      try {
        await bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
    if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
      try {
        await bucket.remove([oldPath]);
      } catch (_) {}
    }
    return CustomerProfile(
      userId: profile.userId,
      fullName: profile.fullName,
      phone: profile.phone,
      avatarUrl: avatarUrl,
    );
  }

  Future<CustomerProfile> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    ClientRateLimiter.instance.enforce(
      'auth_register',
      maxAttempts: 5,
      window: const Duration(minutes: 1),
    );
    if (InputSanitizer.containsSqlOrScriptInjection(fullName)) {
      throw const FormatException(
        'El nombre contiene caracteres o código no permitido.',
      );
    }
    final cleanName = InputSanitizer.sanitizeText(fullName, maxLength: 100);
    final cleanPhone = normalizePhone(phone);
    _validateCredentials(name: cleanName, password: password);
    try {
      if (client.auth.currentUser != null) await client.auth.signOut();
      final response = await client.auth.signUp(
        email: loginEmail(cleanPhone),
        password: password,
        data: {
          'account_type': 'customer',
          'full_name': cleanName,
          'phone': cleanPhone,
        },
      );
      if (response.session == null) {
        await client.auth.signInWithPassword(
          email: loginEmail(cleanPhone),
          password: password,
        );
      }
      return await currentProfile() ??
          (throw StateError('No se pudo preparar la cuenta.'));
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthError(error));
    }
  }

  Future<CustomerProfile> signIn({
    required String phone,
    required String password,
  }) async {
    ClientRateLimiter.instance.enforce(
      'auth_login',
      maxAttempts: 6,
      window: const Duration(minutes: 1),
    );
    final cleanPhone = normalizePhone(phone);
    if (password.isEmpty) {
      throw const FormatException('Escribe tu contraseña.');
    }
    try {
      if (client.auth.currentUser != null) await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: loginEmail(cleanPhone),
        password: password,
      );
      return await currentProfile() ??
          (throw const FormatException(
            'Esta cuenta no pertenece a un cliente de la tienda.',
          ));
    } on AuthException catch (error) {
      throw FormatException(_friendlyAuthError(error));
    }
  }

  Future<void> signOut() => client.auth.signOut();

  Future<List<StoredCustomerOrder>> loadMyOrders() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    ClientRateLimiter.instance.enforce(
      'account_orders_read',
      maxAttempts: 12,
      window: const Duration(minutes: 1),
    );
    final rows = await client
        .from('customer_orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map<StoredCustomerOrder>(_storedOrderFromRow).toList();
  }

  Future<List<StoredCustomerOrder>> loadAllOrders() async {
    final rows = await client
        .from('customer_orders')
        .select()
        .order('created_at', ascending: false)
        .limit(250);
    return rows.map<StoredCustomerOrder>(_storedOrderFromRow).toList();
  }

  Future<StoredCustomerOrder?> verifyPickupQr(String payload) async {
    final id = PickupOrderQr.decode(payload);
    if (id == null) {
      throw const FormatException(
        'Este QR no es un código de recojo de Expresiones.',
      );
    }
    ClientRateLimiter.instance.enforce(
      'pickup_qr_lookup',
      maxAttempts: 20,
      window: const Duration(minutes: 1),
    );
    if (client.auth.currentSession == null ||
        await client.rpc('can_admin_write') != true) {
      throw const FormatException(
        'Inicia sesión con el acceso administrativo para verificar el QR.',
      );
    }
    final row = await client
        .from('customer_orders')
        .select('snapshot, customer_name, customer_phone, status')
        .eq('id', id)
        .eq('delivery_method', 'pickup')
        .eq('status', 'paid_simulated')
        .maybeSingle();
    if (row == null) return null;
    final entry = _storedOrderFromRow(row);
    final order = entry.order;
    return order.id == id &&
            order.details.deliveryMethod == DeliveryMethod.pickup &&
            order.payment.isApproved
        ? entry
        : null;
  }

  Future<void> saveOrder(CheckoutOrder order) async {
    ClientRateLimiter.instance.enforce(
      'order_submit',
      maxAttempts: 4,
      window: const Duration(minutes: 1),
    );
    final profile = await currentProfile(includeAvatar: false);
    if (profile == null) {
      throw StateError('Inicia sesión para guardar la compra.');
    }
    try {
      await client.from('customer_orders').insert({
        'id': InputSanitizer.sanitizeText(order.id, maxLength: 80),
        'user_id': profile.userId,
        'status': 'paid_simulated',
        'total': order.simulatedTotal,
        'total_quantity': order.totalQuantity,
        'customer_name': InputSanitizer.sanitizeText(
          profile.fullName,
          maxLength: 100,
        ),
        'customer_phone': profile.phone,
        'delivery_method': order.details.deliveryMethod.name,
        'payment_reference': InputSanitizer.sanitizeText(
          order.payment.reference,
          maxLength: 80,
        ),
        'payment_method': order.payment.method.name,
        'snapshot': order.toJson(),
        'created_at': order.createdAt.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final saved = await client
          .from('customer_orders')
          .select('id')
          .eq('id', order.id)
          .eq('user_id', profile.userId)
          .eq('payment_reference', order.payment.reference)
          .maybeSingle();
      if (saved == null) rethrow;
    }
  }

  static void _validateCredentials({
    required String name,
    required String password,
  }) {
    if (name.length < 2) {
      throw const FormatException('Escribe tu nombre completo.');
    }
    if (password.length < 8) {
      throw const FormatException('La contraseña debe tener 8 caracteres.');
    }
  }

  static String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'El celular o la contraseña no coinciden.';
    }
    if (message.contains('already') || message.contains('database error')) {
      return 'Ese celular ya está registrado. Prueba iniciar sesión.';
    }
    return 'No se pudo completar el acceso. Inténtalo nuevamente.';
  }

  static StoredCustomerOrder _storedOrderFromRow(Map<String, dynamic> row) {
    final raw = row['snapshot'];
    if (raw is! Map) throw const FormatException('Compra sin comprobante.');
    return StoredCustomerOrder(
      order: CheckoutOrder.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value as Object?)),
      ),
      customerName: '${row['customer_name'] ?? ''}',
      customerPhone: '${row['customer_phone'] ?? ''}',
      status: '${row['status'] ?? ''}',
    );
  }
}
