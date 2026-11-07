import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Aviso recibido mientras la app está abierta (en segundo plano lo muestra el sistema).
class PushNotice {
  const PushNotice(this.title, this.body);
  final String title;
  final String body;
}

abstract class PushService {
  /// Inicializa las notificaciones y devuelve el token de este dispositivo,
  /// o null si no están disponibles (sin configuración de Firebase, permiso denegado, plataforma no soportada).
  Future<String?> start();

  /// Nuevos tokens cuando Firebase renueva el del dispositivo.
  Stream<String> get tokenRefresh;

  /// Notificaciones recibidas con la app en primer plano.
  Stream<PushNotice> get foreground;
}

/// Sin notificaciones: web, iOS (aún sin configurar APNs) y tests.
class NoPushService implements PushService {
  @override
  Future<String?> start() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<PushNotice> get foreground => const Stream.empty();
}

/// Firebase Cloud Messaging en Android. Requiere android/app/google-services.json (ver docs/FCM.md).
class FcmPushService implements PushService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final _foreground = StreamController<PushNotice>.broadcast();
  final _refresh = StreamController<String>.broadcast();
  bool _started = false;

  @override
  Stream<String> get tokenRefresh => _refresh.stream;

  @override
  Stream<PushNotice> get foreground => _foreground.stream;

  @override
  Future<String?> start() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      if (!_started) {
        _started = true;
        FirebaseMessaging.onMessage.listen((m) {
          final n = m.notification;
          if (n != null) {
            _foreground.add(PushNotice(n.title ?? 'MarcaYa', n.body ?? ''));
          }
        });
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen(_refresh.add);
      }
      // Token clásico de FCM: es el que acepta firebase-admin en el backend. La API nueva
      // (register/onRegistered) entrega un Firebase Installation ID, que aún no usamos.
      // ignore: deprecated_member_use
      return await messaging.getToken();
    } catch (e) {
      debugPrint('Notificaciones push no disponibles: $e');
      return null;
    }
  }
}
