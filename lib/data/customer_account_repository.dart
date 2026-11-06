import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checkout_order.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.fullName,
    required this.phone,
  });

  final String userId;
  final String fullName;
  final String phone;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      userId: '${json['user_id'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
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

  Future<CustomerProfile?> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('customer_profiles')
        .select('user_id, full_name, phone')
        .eq('user_id', user.id)
        .maybeSingle();
    return row == null ? null : CustomerProfile.fromJson(row);
  }

  Future<CustomerProfile> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final cleanName = fullName.trim();
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
    final rows = await client
        .from('customer_orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
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

  Future<void> saveOrder(CheckoutOrder order) async {
    final profile = await currentProfile();
    if (profile == null) {
      throw StateError('Inicia sesión para guardar la compra.');
    }
    try {
      await client.from('customer_orders').insert({
        'id': order.id,
        'user_id': profile.userId,
        'status': 'paid_simulated',
        'total': order.simulatedTotal,
        'total_quantity': order.totalQuantity,
        'customer_name': profile.fullName,
        'customer_phone': profile.phone,
        'delivery_method': order.details.deliveryMethod.name,
        'payment_reference': order.payment.reference,
        'payment_method': order.payment.method.name,
        'snapshot': order.toJson(),
        'created_at': order.createdAt.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      // Retrying the success callback must not duplicate a completed purchase.
      if (error.code != '23505') rethrow;
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
