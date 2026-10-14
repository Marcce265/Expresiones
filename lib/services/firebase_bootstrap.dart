import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.connected, this.message});

  final bool connected;
  final String? message;
}

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return const FirebaseBootstrapResult(connected: true);
    }

    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

    if ([projectId, apiKey, appId, senderId].any((value) => value.isEmpty)) {
      return const FirebaseBootstrapResult(
        connected: false,
        message: 'Catálogo local listo. Firestore se activa con la configuración del proyecto.',
      );
    }

    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        ),
      );
      return const FirebaseBootstrapResult(connected: true);
    } catch (error) {
      return FirebaseBootstrapResult(
        connected: false,
        message:
            'No se pudo conectar con Firestore. Se usa el catálogo local: $error',
      );
    }
  }
}
