import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/push_service.dart';

final pushServiceProvider = Provider<PushService>(
  (ref) => FcmPushService.supported ? FcmPushService() : NoPushService(),
);

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(
    ref.watch(pushServiceProvider),
    ref.watch(apiClientProvider),
    () => ref.read(authControllerProvider).valueOrNull?.token,
  );
  ref.onDispose(registrar.dispose);
  return registrar;
});

/// Registra el token de FCM de este dispositivo en el backend para poder enviarle notificaciones.
class PushRegistrar {
  PushRegistrar(this._push, this._api, this._token);

  final PushService _push;
  final ApiClient _api;
  final String? Function() _token;
  String? _current;
  StreamSubscription<String>? _refreshSub;

  Future<void> register() async {
    try {
      final token = await _push.start();
      if (token == null) return;
      _current = token;
      await _send(token);
      _refreshSub ??= _push.tokenRefresh.listen((t) {
        _current = t;
        unawaited(_send(t));
      });
    } catch (e) {
      debugPrint('No se pudo registrar el dispositivo para notificaciones: $e');
    }
  }

  /// Quita este dispositivo del empleado actual (al cerrar sesión), para no recibir sus avisos.
  Future<void> unregister() async {
    final token = _current;
    if (token == null) return;
    try {
      await _api.delete(
        '/devices/${Uri.encodeComponent(token)}',
        token: _token(),
      );
    } catch (e) {
      debugPrint('No se pudo quitar el dispositivo: $e');
    }
    _current = null;
  }

  Future<void> _send(String fcmToken) => _api.post('/devices', {
    'token': fcmToken,
    'platform': 'android',
  }, token: _token());

  void dispose() => _refreshSub?.cancel();
}
