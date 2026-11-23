import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../data/customer_account_repository.dart';
import '../services/legal_consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/legal_consent_checkboxes.dart';
import '../widgets/pickup_order_qr_card.dart';
import 'order_success_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.repository,
    this.checkoutMode = false,
    this.accessGate = false,
    this.initialName = '',
    this.initialPhone = '',
    this.onAuthenticated,
    this.onVerifyPickup,
  });

  final CustomerAccountRepository repository;
  final bool checkoutMode;
  final bool accessGate;
  final String initialName;
  final String initialPhone;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onVerifyPickup;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _avatarChannel = MethodChannel(
    'pe.expresiones.expresiones/avatar',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone,
  );
  final _password = TextEditingController();
  StreamSubscription<dynamic>? _authSubscription;
  CustomerProfile? _profile;
  List<StoredCustomerOrder> _orders = const [];
  bool _registering = false;
  bool _loading = true;
  bool _submitting = false;
  bool _hidePassword = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _consentError = false;
  bool _savingAvatar = false;
  int _refreshRequest = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.repository.authChanges.listen((_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final request = ++_refreshRequest;
    try {
      final profile = await widget.repository.currentProfile();
      final orders = profile == null
          ? const <StoredCustomerOrder>[]
          : await widget.repository.loadMyOrders();
      if (!mounted || request != _refreshRequest) return;
      setState(() {
        _profile = profile;
        _orders = orders;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || request != _refreshRequest) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar tu cuenta. Revisa tu conexión.';
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_registering && (!_termsAccepted || !_privacyAccepted)) {
      setState(() {
        _consentError = true;
        _error = 'Marca ambas casillas por separado (Términos y Condiciones y Política de Privacidad) para crear tu cuenta.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _consentError = false;
      _error = null;
    });
    try {
      final profile = _registering
          ? await widget.repository.register(
              fullName: _name.text,
              phone: _phone.text,
              password: _password.text,
            )
          : await widget.repository.signIn(
              phone: _phone.text,
              password: _password.text,
            );
      if (_registering) {
        unawaited(
          LegalConsentService.recordConsent(
            context: 'account_registration',
            termsAccepted: _termsAccepted,
            privacyAccepted: _privacyAccepted,
            customerName: profile.fullName,
            customerPhone: profile.phone,
            supabaseClient: widget.repository.client,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _profile = profile);
      widget.onAuthenticated?.call();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final text = error is FormatException
          ? error.message.toString()
          : 'No se pudo completar el acceso. Inténtalo nuevamente.';
      setState(() => _error = text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    _refreshRequest++;
    setState(() {
      _profile = null;
      _orders = const [];
      _password.clear();
    });
  }

  Future<void> _changeAvatar() async {
    if (!FeatureFlags.appEndToEnd || _savingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() {
      _savingAvatar = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return;
      final optimized = await _avatarChannel.invokeMethod<Uint8List>(
        'optimize',
        {'path': picked.path},
      );
      if (optimized == null) {
        throw const FormatException('No pudimos leer esa imagen.');
      }
      final profile = await widget.repository.saveAvatar(optimized);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        FormatException(:final message) => message.toString(),
        PlatformException(code: 'invalid_image') =>
          'No pudimos leer esa imagen. Prueba con un JPG o PNG.',
        StorageException() => 'No se pudo subir la foto de perfil. Inténtalo de nuevo en unos minutos.',
        _ => 'No se pudo guardar la foto. Vuelve a intentarlo.',
      };
      setState(() {
        _error = message;
      });
    } finally {
      if (mounted) setState(() => _savingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: ResponsivePage.storefront(
        top: 24,
        bottom: 48,
        child: _profile == null ? _buildAccess() : _buildAccount(),
      ),
    );
  }

  Widget _buildAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('CUENTA DE CLIENTE'),
        const SizedBox(height: 8),
        Text(
          widget.accessGate
              ? 'Ingresa a Expresiones'
              : widget.checkoutMode
              ? 'Guarda tu compra'
              : 'Tu cuenta en Expresiones',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 6),
        Text(
          widget.accessGate
              ? 'Inicia sesión o crea una cuenta para entrar al catálogo.'
              : widget.checkoutMode
              ? 'Inicia sesión o crea una cuenta para continuar al pago simulado.'
              : 'Consulta tus compras simuladas desde cualquier dispositivo.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.login_rounded),
                      label: Text('Iniciar sesión'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.person_add_alt_1_rounded),
                      label: Text('Crear cuenta'),
                    ),
                  ],
                  selected: {_registering},
                  onSelectionChanged: _submitting
                      ? null
                      : (value) => setState(() {
                          _registering = value.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 20),
                if (_registering) ...[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    hintText: '9 dígitos',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hidePassword,
                  autofillHints: _registering
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: _registering ? 'Mínimo 8 caracteres' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (_registering) ...[
                  const SizedBox(height: 16),
                  LegalConsentCheckboxes(
                    termsAccepted: _termsAccepted,
                    privacyAccepted: _privacyAccepted,
                    showError: _consentError,
                    onTermsChanged: (checked) => setState(() {
                      _termsAccepted = checked;
                      if (_termsAccepted && _privacyAccepted) {
                        _consentError = false;
                        _error = null;
                      }
                    }),
                    onPrivacyChanged: (checked) => setState(() {
                      _privacyAccepted = checked;
                      if (_termsAccepted && _privacyAccepted) {
                        _consentError = false;
                        _error = null;
                      }
                    }),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _registering
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                        ),
                  label: Text(
                    _submitting
                        ? 'Un momento…'
                        : _registering
                        ? 'Crear mi cuenta'
                        : 'Ingresar',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No pedimos correo ni códigos. Tu celular identifica la cuenta.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!_registering && widget.onVerifyPickup != null)
                  TextButton.icon(
                    onPressed: widget.onVerifyPickup,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Verificar QR de recojo'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccount() {
    final profile = _profile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (FeatureFlags.appEndToEnd)
              Semantics(
                button: true,
                label: 'Cambiar foto de perfil',
                child: SizedBox.square(
                  dimension: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _savingAvatar ? null : _changeAvatar,
                      customBorder: const CircleBorder(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.pinkSoft,
                            foregroundImage: profile.avatarUrl == null
                                ? null
                                : NetworkImage(profile.avatarUrl!),
                            onForegroundImageError: profile.avatarUrl == null
                                ? null
                                : (_, _) {},
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.ink,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: _savingAvatar
                                  ? const SizedBox.square(
                                      dimension: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_outlined,
                                      size: 14,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    profile.phone,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Salir'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.error),
          ),
        ],
        if (widget.checkoutMode) ...[
          const SizedBox(height: 18),
          InfoBanner(
            icon: Icons.check_circle_outline_rounded,
            title: 'Cuenta lista',
            message: 'Ya puedes continuar al pago simulado.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onAuthenticated,
              child: const Text('Continuar con mi compra'),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Text(
          'Historial de compras',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (_orders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aún no hay compras',
            message: 'Las compras simuladas completadas aparecerán aquí.',
          )
        else
          ..._orders.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(entry: entry),
            ),
          ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.entry});

  final StoredCustomerOrder entry;

  @override
  Widget build(BuildContext context) {
    final order = entry.order;
    final date = order.createdAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Detalle del pedido')),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: ResponsivePage(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(dateLabel),
                        const SizedBox(height: 12),
                        if (FeatureFlags.appEndToEnd)
                          PickupOrderQrCard(order: order),
                        OrderReceiptCard(order: order),
                        const SizedBox(height: 12),
                        OrderDeliveryCard(details: order.details),
                        if (order.payment.reference.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: ListTile(
                              title: Text(order.payment.methodLabel),
                              subtitle: Text(order.payment.reference),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.pinkSoft,
                child: Icon(Icons.receipt_long_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '$dateLabel · ${order.totalQuantity} ${order.totalQuantity == 1 ? 'producto' : 'productos'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                'S/ ${order.simulatedTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
