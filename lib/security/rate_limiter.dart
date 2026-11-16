/// Limitador de tasa de peticiones (Sliding Window Rate Limiter) y filtro de
/// deduplicación en cliente para prevenir ataques de fuerza bruta, spam de
/// pedidos y sobrecarga de llamadas RPC hacia Supabase y Cloudflare.
class ClientRateLimiter {
  ClientRateLimiter({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Instancia compartida por defecto en la sesión de la aplicación.
  static final ClientRateLimiter instance = ClientRateLimiter();

  final DateTime Function() _clock;
  final Map<String, List<DateTime>> _buckets = <String, List<DateTime>>{};
  final Set<String> _deduplicatedSessionKeys = <String>{};

  /// Verifica si la acción identificada por [bucket] puede ejecutarse dentro
  /// de la ventana [window] con un máximo de [maxAttempts].
  ///
  /// Devuelve `true` y registra el intento si está dentro del límite, o
  /// `false` si se superó el límite de peticiones.
  bool tryAcquire(
    String bucket, {
    required int maxAttempts,
    required Duration window,
  }) {
    final now = _clock();
    final cutoff = now.subtract(window);
    final timestamps = _buckets.putIfAbsent(bucket, () => <DateTime>[]);

    timestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));

    if (timestamps.length >= maxAttempts) {
      return false;
    }

    timestamps.add(now);
    return true;
  }

  /// Verifica el límite de tasa y lanza un [FormatException] amigable si se
  /// detectan demasiados intentos seguidos.
  void enforce(
    String bucket, {
    required int maxAttempts,
    required Duration window,
    String message =
        'Demasiados intentos seguidos. Por seguridad, espera unos segundos antes de volver a intentarlo.',
  }) {
    if (!tryAcquire(bucket, maxAttempts: maxAttempts, window: window)) {
      throw FormatException(message);
    }
  }

  /// Registra una clave única por sesión (por ejemplo, vista de un producto)
  /// para evitar que recargas o clics repetidos inflen contadores o disparen
  /// llamadas innecesarias a la base de datos.
  bool markOncePerSession(String key) {
    if (_deduplicatedSessionKeys.length >= 2000) {
      _deduplicatedSessionKeys.clear();
    }
    return _deduplicatedSessionKeys.add(key);
  }

  /// Limpia todos los contadores (útil en pruebas unitarias).
  void reset() {
    _buckets.clear();
    _deduplicatedSessionKeys.clear();
  }
}
